# frozen_string_literal: true

require 'spec_helper'

if Config.postgres_enabled
  describe 'postgres', :postgres => true do
    let(:kubectl) { Kubectl.new }

    context 'when enabled' do
      it "exists" do
        wait_until(60,10) {
          statefulsets = kubectl.get_statefulsets('postgres')
          expect(statefulsets).to_not be_nil

          statefulsets.map! { |statefulset| statefulset['metadata']['name'] }
          expect(statefulsets).to include('postgres')
        }
      end

      it "is has running pods" do
        kubectl.wait_for_statefulset('postgres', '120s', 'postgres')

        wait_until(120,15) {
          pods = kubectl.get_pods_by_label("app=postgres,app.kubernetes.io/component=database", 'postgres')
          expect(pods).to_not be_nil
          expect(pods.count).to be >= 1

          pods.each{ |pod|
            expect(pod['metadata']['name']).to match(/postgres-[-a-z0-9]+/)
            expect(pod["metadata"]["deletionTimestamp"]).to be_nil
            expect(pod['status']['phase']).to eq('Running')
            expect(pod['status']['containerStatuses'].count).to be >= 2
            pod['status']['containerStatuses'].each{ |container|
              expect(container["ready"]).to eq(true)
              expect(container["started"]).to eq(true)
              expect(container["state"]).to include("running")
            }
          }
        }
      end

      it "has services" do
        wait_until(60,10) {
          services = kubectl.get_services('postgres')
          expect(services).to_not be_nil
          expect(services.count).to be >= 2

          service_names = services.map { |s| s['metadata']['name'] }
          expect(service_names).to include('postgres')
        }
      end

      it "has secrets for database and backup" do
        wait_until(60,10) {
          secrets = kubectl.get_secrets('postgres')
          expect(secrets).to_not be_nil
          expect(secrets.count).to be >= 2
        }
      end
    end
  end
end
