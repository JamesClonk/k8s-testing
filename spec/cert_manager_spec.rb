# frozen_string_literal: true

require 'spec_helper'

if Config.lets_encrypt_enabled
  describe 'cert-manager', :cert_manager => true do
    let(:kubectl) { Kubectl.new }

    it "is running" do
      wait_until(60,10) {
        deployments = kubectl.get_deployments('cert-manager')
        expect(deployments).to_not be_nil

        deployments.map! { |deployment| deployment['metadata']['name'] }
        expect(deployments).to include('cert-manager', 'cert-manager-webhook', 'cert-manager-cainjector')
      }
    end

    it "has running pods for cert-manager" do
      kubectl.wait_for_deployment('cert-manager', '120s', 'cert-manager')

      wait_until(120,15) {
        pods = kubectl.get_pods_by_label("app.kubernetes.io/name=cert-manager", 'cert-manager')
        expect(pods).to_not be_nil
        expect(pods.count).to be >= 1

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/cert-manager-[-a-z0-9]+/)
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

    it "has running pods for cert-manager-webhook" do
      kubectl.wait_for_deployment('cert-manager-webhook', '120s', 'cert-manager')

      wait_until(120,15) {
        pods = kubectl.get_pods_by_label("app.kubernetes.io/name=webhook", 'cert-manager')
        expect(pods).to_not be_nil
        expect(pods.count).to be >= 1

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/cert-manager-webhook-[-a-z0-9]+/)
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

    it "has running pods for cert-manager-cainjector" do
      kubectl.wait_for_deployment('cert-manager-cainjector', '120s', 'cert-manager')

      wait_until(120,15) {
        pods = kubectl.get_pods_by_label("app.kubernetes.io/name=cainjector", 'cert-manager')
        expect(pods).to_not be_nil
        expect(pods.count).to be >= 1

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/cert-manager-cainjector-[-a-z0-9]+/)
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

    it "has cluster issuers configured" do
      wait_until(60,10) {
        issuers = kubectl.get_objects("clusterissuer", 'cert-manager')
        expect(issuers).to_not be_nil
        expect(issuers['items']).to_not be_nil
        expect(issuers['items'].count).to be >= 1

        issuer_names = issuers['items'].map { |i| i['metadata']['name'] }
        expect(issuer_names).to include(Config.lets_encrypt_issuer)

        issuer = issuers['items'].select { |i| i['metadata']['name'] == Config.lets_encrypt_issuer }.first
        expect(issuer['spec']['acme']['server']).to eq(Config.lets_encrypt_server)
        expect(issuer['status']['conditions']).to_not be_nil
        expect(issuer['status']['conditions'].any? { |c| c['type'] == 'Ready' && c['status'] == 'True' }).to eq(true)
      }
    end
  end
end
