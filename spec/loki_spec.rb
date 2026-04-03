# frozen_string_literal: true

require 'date'
require 'json'
require 'spec_helper'

if Config.loki_enabled
  describe 'loki', :loki => true do
    let(:kubectl) { Kubectl.new }

    it "is running" do
      wait_until(60,10) {
        pods = kubectl.get_pods('loki')
        expect(pods).to_not be_nil

        pods.map! { |pod| pod['metadata']['name'] }
        expect(pods).to include('loki-0')
      }

      kubectl.wait_for_statefulset('loki', "240s", 'loki')
      wait_until(120,15) {
        pods = kubectl.get_pods_by_label("app.kubernetes.io/name=loki", 'loki')
        expect(pods).to_not be_nil
        expect(pods.count).to be >= 1

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/loki-[-a-z0-9]+/)
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

    it "is ready" do
      wait_until(60,5) {
        response = kubectl.raw_service("/ready", "loki", 3100, "loki").chomp
        expect(response).to_not be_nil
        expect(response).to eq('ready')
      }
    end

    it "has logs available for loki app" do
      wait_until(60,5) {
        response = kubectl.raw_service('/loki/api/v1/query_range?query={app="loki"}&since=30m&limit=10', "loki", 3100, "loki").chomp
        expect(response).to_not be_nil
        expect(response).to include('{"status":"success"')
      }
    end

    it "has logs available for backman app" do
      wait_until(60,5) {
        response = kubectl.raw_service('/loki/api/v1/query_range?query={app="backman"}&since=24h&limit=50', "loki", 3100, "loki").chomp
        expect(response).to_not be_nil
        expect(response).to include('\"pod_name\":\"backman-')
        expect(response).to include('\"app.kubernetes.io/instance\":\"backman\"')
        expect(response).to include('msg=')
      }
    end

    it "has logs available for home-info app" do
      wait_until(60,5) {
        response = kubectl.raw_service('/loki/api/v1/query_range?query={app="home-info"}&since=2h&limit=50', "loki", 3100, "loki").chomp
        expect(response).to_not be_nil
        expect(response).to include('GET /')
        expect(response).to include('POST /sensor')
      }
    end
  end
end
