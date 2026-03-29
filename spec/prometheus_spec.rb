# frozen_string_literal: true

require 'date'
require 'json'
require 'spec_helper'

if Config.prometheus_enabled
  describe 'prometheus', :prometheus => true do
    let(:kubectl) { Kubectl.new }

    it "is running" do
      wait_until(60,10) {
        deployments = kubectl.get_deployments('prometheus')
        expect(deployments).to_not be_nil

        deployments.map! { |deployment| deployment['metadata']['name'] }
        expect(deployments).to include('prometheus-server')
      }

      kubectl.wait_for_deployment('prometheus-server', "240s", 'prometheus')
      wait_until(240,15) {
        pods = kubectl.get_pods_by_label("app.kubernetes.io/name=prometheus,app.kubernetes.io/component=server", 'prometheus')
        expect(pods).to_not be_nil
        expect(pods.count).to be >= 1

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/prometheus-server-[-a-z0-9]+/)
          expect(pod["metadata"]["deletionTimestamp"]).to be_nil
          expect(pod['status']['phase']).to eq('Running')
          expect(pod['status']['containerStatuses'].count).to be >= 1
          pod['status']['containerStatuses'].each{ |container|
            expect(container["ready"]).to eq(true)
            expect(container["started"]).to eq(true)
            expect(container["state"]).to include("running")
          }
        }
      }
    end

    it "has running alertmanager" do
      kubectl.wait_for_statefulset('prometheus-alertmanager', "240s", 'prometheus')
      wait_until(120,15) {
        pods = kubectl.get_pods_by_label('app.kubernetes.io/name=alertmanager', 'prometheus')
        expect(pods).to_not be_nil
        expect(pods.count).to be >= 1

        nodes = kubectl.get_nodes
        expect(nodes).to_not be_nil
        expect(nodes.count).to be >= 1
        expect(pods.count).to eq nodes.count

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/prometheus-alertmanager-[-a-z0-9]+/)
          expect(pod['status']['phase']).to eq('Running')
          expect(pod['status']['containerStatuses'].count).to be >= 1
          pod['status']['containerStatuses'].each{ |container|
            expect(container['started']).to eq(true)
          }
        }
      }
    end

    it "has running kube-state-metrics" do
      kubectl.wait_for_deployment('prometheus-kube-state-metrics', "240s", 'prometheus')
      wait_until(120,15) {
        pods = kubectl.get_pods_by_label('app.kubernetes.io/name=kube-state-metrics,app.kubernetes.io/component=metrics', 'prometheus')
        expect(pods).to_not be_nil
        expect(pods.count).to be >= 1

        nodes = kubectl.get_nodes
        expect(nodes).to_not be_nil
        expect(nodes.count).to be >= 1
        expect(pods.count).to eq nodes.count

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/prometheus-kube-state-metrics-[-a-z0-9]+/)
          expect(pod['status']['phase']).to eq('Running')
          expect(pod['status']['containerStatuses'].count).to be >= 1
          pod['status']['containerStatuses'].each{ |container|
            expect(container['started']).to eq(true)
          }
        }
      }
    end

    it "has running node-exporters" do
      kubectl.wait_for_daemonset('prometheus-prometheus-node-exporter', "240s", 'prometheus')
      wait_until(120,15) {
        pods = kubectl.get_pods_by_label('app.kubernetes.io/name=prometheus-node-exporter,app.kubernetes.io/component=metrics', 'prometheus')
        expect(pods).to_not be_nil
        expect(pods.count).to be >= 1

        nodes = kubectl.get_nodes
        expect(nodes).to_not be_nil
        expect(nodes.count).to be >= 1
        expect(pods.count).to eq nodes.count

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/prometheus-node-exporter-[-a-z0-9]+/)
          expect(pod['status']['phase']).to eq('Running')
          expect(pod['status']['containerStatuses'].count).to be >= 1
          pod['status']['containerStatuses'].each{ |container|
            expect(container['started']).to eq(true)
          }
        }
      }
    end

    it "has metrics available" do
      # 1.0 = one day
      # 1.0/24 = 1 hour
      # 1.0/(24*60) = 1 minute
      # 1.0/(24*60*60) = 1 second
      d = DateTime.now.new_offset(0) # UTC
      start_timestamp = (d.new_offset(0) - (15.0/(24*60))).strftime("%Y-%m-%dT%H:%M:00.000Z") # minus 15min
      end_timestamp = (d.new_offset(0) + (15.0/(24*60))).strftime("%Y-%m-%dT%H:%M:00.000Z") # plus 15min

      response = kubectl.raw_service("/api/v1/series?match[]=up{job=\"prometheus\"}&start=#{start_timestamp}", "prometheus-server", 80, "prometheus").chomp
      expect(response).to_not be_nil
      expect(response).to eq('{"status":"success","data":[{"__name__":"up","instance":"localhost:9090","job":"prometheus"}]}')

      response = kubectl.raw_service("/api/v1/query_range?query=up{app_kubernetes_io_name=\"kube-state-metrics\"}&start=#{start_timestamp}&end=#{end_timestamp}&step=15s", "prometheus-server", 80, "prometheus").chomp
      expect(response).to_not be_nil
      expect(response).to include('{"status":"success","data":{"resultType":"matrix","result":[{"metric":{"__name__":')
      data = JSON.parse(response)
      expect(data).to_not be_nil
      expect(data['status']).to eq("success")
      expect(data['data']['result']).to_not be_nil
      expect(data['data']['result'].count).to be >= 1
      expect(data['data']['result'][0]['metric']).to_not be_nil
      expect(data['data']['result'][0]['metric']['job']).to_not be_nil
      expect(data['data']['result'][0]['metric']['job']).to eq('kubernetes-service-endpoints')
      expect(data['data']['result'][0]['values']).to_not be_nil
      expect(data['data']['result'][0]['values'].count).to be >= 10

      if Config.lets_encrypt_enabled
        response = kubectl.raw_service("/api/v1/query_range?query=up{app=\"cert-manager\"}&start=#{start_timestamp}&end=#{end_timestamp}&step=15s", "prometheus-server", 80, "prometheus").chomp
        expect(response).to_not be_nil
        expect(response).to include('{"status":"success","data":{"resultType":"matrix","result":[{"metric":{"__name__":')
        data = JSON.parse(response)
        expect(data).to_not be_nil
        expect(data['status']).to eq("success")
        expect(data['data']['result']).to_not be_nil
        expect(data['data']['result'].count).to be >= 1
        expect(data['data']['result'][0]['metric']).to_not be_nil
        expect(data['data']['result'][0]['metric']['job']).to_not be_nil
        expect(data['data']['result'][0]['metric']['job']).to eq('kubernetes-pods')
        expect(data['data']['result'][0]['values']).to_not be_nil
        expect(data['data']['result'][0]['values'].count).to be >= 5
      end
    end
  end
end
