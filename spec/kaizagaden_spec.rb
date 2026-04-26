# frozen_string_literal: true

require 'spec_helper'

if Config.kaizagaden_enabled
  describe 'kaizagaden app', :kaizagaden => true do
    let(:kubectl) { Kubectl.new }

    context 'when enabled' do
      it "exists" do
        wait_until(60,10) {
          deployments = kubectl.get_deployments('kaizagaden')
          expect(deployments).to_not be_nil

          deployments.map! { |deployment| deployment['metadata']['name'] }
          expect(deployments).to include('kaizagaden')
        }
      end

      it "has running pods" do
        kubectl.wait_for_deployment('kaizagaden', '120s', 'kaizagaden')

        wait_until(120,15) {
          pods = kubectl.get_pods_by_label("app=kaizagaden", 'kaizagaden')
          expect(pods).to_not be_nil
          expect(pods.count).to be == 1 # the deployment has 1 replicas defined

          pods.each{ |pod|
            expect(pod['metadata']['name']).to match(/kaizagaden-[-a-z0-9]+/)
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
        it 'has an httproute' do
          httproutes = kubectl.get_httproutes('kaizagaden')
          expect(httproutes).to_not be_nil

          httproutes.map! { |httproute| httproute['metadata']['name'] }
          expect(httproutes).to include('kaizagaden')
        end

        if Config.lets_encrypt_enabled
          it 'has a valid certificate' do
            wait_until(120,15) {
              # since the migration to envoy gateway all certificates are now in the same global namespace
              # gateway-api was designed by idiots ...
              certificates = kubectl.get_certificates('envoy-gateway-system')
              expect(certificates).to_not be_nil
              expect(certificates.count).to be >= 1

              expect(certificates.any?{ |c| c['metadata']['name'] == "kaizagaden-certificate" }).to eq(true)
              certificate = certificates.select{ |c| c['metadata']['name'] == "kaizagaden-certificate" }.first

              expect(certificate['spec']).to_not be_nil
              expect(certificate['spec']['dnsNames']).to_not be_nil
              expect(certificate['spec']['dnsNames'].count).to eq(1)
              expect(certificate['spec']['dnsNames'][0]).to eq("xn--kaizgden-k7ab.#{Config.domain}")

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

          it "can be https queried via hostname [kaizāgāden.#{Config.domain}]" do
            wait_until(60,15) {
              response = https_get("https://xn--kaizgden-k7ab.#{Config.domain}")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to include('Kaisergarten','Japanisch-Bayerische Kaiserliche Fusionsküche','Zwei Reiche, ein Tisch','Willkommen im Kaisergarten').or include('Kaisergarten','Japanese–Bavarian Imperial Fusion Cuisine','Zwei Reiche, ein Tisch','Welcome to Kaisergarten')
              expect(response.body).to include('Tonkatsu','Takoyaki','Weisswurst')
              expect(response.body).to include('Unsere Philosophie','Öffnungszeiten','Kontakt').or include('Our Philosophy','Opening Hours','Contact')
            }
          end
        end
      end
    end
  end
end
