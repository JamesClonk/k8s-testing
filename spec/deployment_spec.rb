# frozen_string_literal: true

require 'spec_helper'

if Config.deployment_enabled
  describe 'a kubernetes deployment', :deployment => true do
    let(:kubectl) { Kubectl.new }

    before(:all) do
      @name = Config.random_names ? random_name('deployment') : 'test-deployment'
    end

    context 'when deployed' do
      before(:all) do
        deploy = kubectl.deploy(name: @name, filename: 'spec/assets/deployment.yml')
      end
      after(:all) do
        delete = kubectl.delete(name: @name, filename: 'spec/assets/deployment.yml')

        deployments = kubectl.get_deployments
        expect(deployments).to_not include(@name)
      end

      it "exists" do
        wait_until(60,10) {
          deployments = kubectl.get_deployments
          expect(deployments).to_not be_nil

          deployments.map! { |deployment| deployment['metadata']['name'] }
          expect(deployments).to include(@name)
        }
      end

      it "has running pods" do
        kubectl.wait_for_deployment(@name)

        wait_until(240,15) {
          pods = kubectl.get_pods_by_label("app=#{@name}")
          expect(pods).to_not be_nil
          expect(pods.count).to be >= 2 # the deployment has 2 replicas defined

          pods.each{ |pod|
            expect(pod['metadata']['name']).to match(/#{@name}-[-a-z0-9]+/)
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

      if Config.httproute_enabled
        context 'with an httproute' do
          before(:all) do
            @httproute_filename = 'spec/assets/httproute.yml'
            deploy = kubectl.deploy(name: @name, filename: @httproute_filename)
          end
          after(:all) do
            delete = kubectl.delete(name: @name, filename: @httproute_filename)

            httproutes = kubectl.get_httproutes
            expect(httproutes).to_not include(@name)
          end

          if Config.lets_encrypt_enabled
            context 'with a valid certificate' do
              before(:all) do
                wait_until(240,15) {
                  # since the migration to envoy gateway all certificates are now in the same global namespace
                  # gateway-api was designed by idiots ...
                  certificates = kubectl.get_certificates('envoy-gateway-system')
                  expect(certificates).to_not be_nil
                  expect(certificates.count).to be >= 1

                  expect(certificates.any?{ |c| c['metadata']['name'] == "#{@name}-certificate" }).to eq(true)
                  certificate = certificates.select{ |c| c['metadata']['name'] == "#{@name}-certificate" }.first

                  expect(certificate['spec']).to_not be_nil
                  expect(certificate['spec']['dnsNames']).to_not be_nil
                  expect(certificate['spec']['dnsNames'].count).to eq(1)
                  expect(certificate['spec']['dnsNames'][0]).to eq("#{@name}.#{Config.domain}")

                  expect(certificate['status']).to_not be_nil
                  expect(certificate['status']['conditions']).to_not be_nil
                  expect(certificate['status']['conditions'].count).to eq(1)
                  expect(certificate['status']['conditions'][0]['type']).to eq('Ready')
                  expect(certificate['status']['conditions'][0]['status']).to eq('True')

                  expect(Time.parse(certificate['status']['notAfter']) > (Time.now + 60*60*24*5)).to eq(true)
                  expect(Time.parse(certificate['status']['notAfter']) < (Time.now + 60*60*24*180)).to eq(true)
                  expect(Time.parse(certificate['status']['notBefore']) > (Time.now - 60*60*24*1)).to eq(true)
                }
              end

              it "can be https queried via domain [#{Config.domain}]" do
                wait_until(120,15) {
                  response = https_testing_get("https://#{@name}.#{Config.domain}/httproute")
                  expect(response).to_not be_nil
                  expect(response.code).to eq(200)
                  expect(response.headers[:content_type]).to include('text/html')
                  expect(response.body).to eq('Howdy, httproute!')
                }
              end
            end
          end
        end
      end
    end
  end
end
