# frozen_string_literal: true

require 'spec_helper'

if Config.resume_enabled
  describe 'resume app', :resume => true do
    before(:all) do
      @kubectl = KUBECTL.new()
    end

    context 'when enabled' do
      it "exists" do
        wait_until(60,10) {
          deployments = @kubectl.get_deployments('resume')
          expect(deployments).to_not be_nil

          deployments.map! { |deployment| deployment['metadata']['name'] }
          expect(deployments).to include('resume')
        }
      end

      it "has running pods" do
        @kubectl.wait_for_deployment('resume', '120s', 'resume')

        wait_until(240,15) {
          pods = @kubectl.get_pods_by_label("app=resume", 'resume')
          expect(pods).to_not be_nil
          expect(pods.count).to be == 1 # the deployment has 1 replicas defined

          pods.each{ |pod|
            expect(pod['metadata']['name']).to match(/resume-[-a-z0-9]+/)
            expect(pod['status']['phase']).to eq('Running')
            expect(pod['status']['containerStatuses'].count).to be >= 1
            pod['status']['containerStatuses'].each{ |container|
              expect(container['started']).to eq(true)
            }
          }
        }
      end

      if Config.ingress_enabled
        it 'has an Ingress' do
          ingresses = @kubectl.get_ingresses('resume')
          expect(ingresses).to_not be_nil

          ingresses.map! { |ingress| ingress['metadata']['name'] }
          expect(ingresses).to include('resume')
        end

        if Config.lets_encrypt_enabled
          it 'has a valid certificate' do
            wait_until(1,1) {
              certificates = @kubectl.get_certificates('resume')
              expect(certificates).to_not be_nil
              expect(certificates.count).to be >= 1

              expect(certificates.any?{ |c| c['metadata']['name'] == "resume-tls" }).to eq(true)
              certificate = certificates.select{ |c| c['metadata']['name'] == "resume-tls" }.first

              expect(certificate['spec']).to_not be_nil
              expect(certificate['spec']['dnsNames']).to_not be_nil
              expect(certificate['spec']['dnsNames'].count).to eq(1)
              expect(certificate['spec']['dnsNames'][0]).to eq("resume.#{Config.domain}")

              expect(certificate['status']).to_not be_nil
              expect(certificate['status']['conditions']).to_not be_nil
              expect(certificate['status']['conditions'].count).to eq(1)
              expect(certificate['status']['conditions'][0]['type']).to eq('Ready')
              expect(certificate['status']['conditions'][0]['status']).to eq('True')

              expect(Time.parse(certificate['status']['notAfter']) > (Time.now + 60*60*24*5)).to eq(true)
              expect(Time.parse(certificate['status']['notAfter']) < (Time.now + 60*60*24*180)).to eq(true)
              expect(Time.parse(certificate['status']['notBefore']) < Time.now).to eq(true)
            }
          end

          it "can be https queried via domain [#{Config.domain}]" do
            wait_until(120,15) {
              response = https_get("https://resume.#{Config.domain}")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to include('Senior DevOps Engineer','fabio.berchtold@swisscom.com','Platform-as-a-Service')
              expect(response.body).to include('Swisscom (Schweiz) AG','WISS - Wirtschaftsinformatikschule Schweiz')
            }
          end
        end
      end
    end
  end
end
