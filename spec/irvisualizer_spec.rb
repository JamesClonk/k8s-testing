# frozen_string_literal: true

require 'spec_helper'

if Config.irvisualizer_enabled
  describe 'irvisualizer app', :irvisualizer => true do
    let(:kubectl) { Kubectl.new }

    context 'when enabled' do
      it "exists" do
        wait_until(60,10) {
          deployments = kubectl.get_deployments('irvisualizer')
          expect(deployments).to_not be_nil

          deployments.map! { |deployment| deployment['metadata']['name'] }
          expect(deployments).to include('irvisualizer', 'ircollector', 'irdiscordbot')
        }
      end

      it "has running pods for irvisualizer" do
        kubectl.wait_for_deployment('irvisualizer', '120s', 'irvisualizer')

        wait_until(120,15) {
          pods = kubectl.get_pods_by_label("app=irvisualizer,app.kubernetes.io/component=frontend", 'irvisualizer')
          expect(pods).to_not be_nil
          expect(pods.count).to be == 1 # the deployment has 1 replicas defined

          pods.each{ |pod|
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
          httproutes = kubectl.get_httproutes('irvisualizer')
          expect(httproutes).to_not be_nil

          httproutes.map! { |httproute| httproute['metadata']['name'] }
          expect(httproutes).to include('irvisualizer')
        end

        if Config.lets_encrypt_enabled
          it 'has a valid certificate' do
            wait_until(120,15) {
              # since the migration to envoy gateway all certificates are now in the same global namespace
              # gateway-api was designed by idiots ...
              certificates = kubectl.get_certificates('envoy-gateway-system')
              expect(certificates).to_not be_nil
              expect(certificates.count).to be >= 2

              expect(certificates.any?{ |c| c['metadata']['name'] == "irvisualizer-certificate" }).to eq(true)
              certificate = certificates.select{ |c| c['metadata']['name'] == "irvisualizer-certificate" }.first

              expect(certificate['spec']).to_not be_nil
              expect(certificate['spec']['dnsNames']).to_not be_nil
              expect(certificate['spec']['dnsNames'].count).to eq(1)
              expect(certificate['spec']['dnsNames']).to include("irvisualizer.#{Config.domain}")

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

          it "shows json series data" do
            wait_until(60,15) {
              response = https_get("https://irvisualizer.#{Config.domain}/series_json")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('application/json')
              expect(response.headers[:strict_transport_security]).to include('max-age','includeSubDomains')
              expect(response.body).to include('"series_id": 2,', '"name": "Indy Pro 2000 Championship",')
              expect(response.body).to include('"name": "USF 2000 Championship",')
              expect(response.body).to include('"series_id": 3,')
            }
          end

          it "shows heatmaps" do
            wait_until(60,15) {
              response = https_get("https://irvisualizer.#{Config.domain}/season/5942/heatmap.png")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('image/png')
              expect(response.headers[:content_length].to_i).to be >= 77777
            }
          end

          it "shows top laps" do
            wait_until(60,15) {
              response = https_get("https://irvisualizer.#{Config.domain}/season/5941/week/03/top/laps.png")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('image/png')
              expect(response.headers[:content_length].to_i).to be >= 77777
            }
          end

          it "shows top scores" do
            wait_until(60,15) {
              response = https_get("https://irvisualizer.#{Config.domain}/season/5776/week/07/top/scores.png")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('image/png')
              expect(response.headers[:content_length].to_i).to be >= 77777
            }
          end
        end
      end
    end
  end

  describe 'ircollector app', :irvisualizer => true do
    let(:kubectl) { Kubectl.new }

    context 'when enabled' do
      it "exists" do
        wait_until(60,10) {
          deployments = kubectl.get_deployments('irvisualizer')
          expect(deployments).to_not be_nil

          deployments.map! { |deployment| deployment['metadata']['name'] }
          expect(deployments).to include('irvisualizer', 'ircollector', 'irdiscordbot')
        }
      end

      it "has running pods for ircollector" do
        kubectl.wait_for_deployment('ircollector', '120s', 'irvisualizer')

        wait_until(120,15) {
          pods = kubectl.get_pods_by_label("app=irvisualizer,app.kubernetes.io/component=backend", 'irvisualizer')
          expect(pods).to_not be_nil
          expect(pods.count).to be == 1 # the deployment has 1 replicas defined

          pods.each{ |pod|
            expect(pod['metadata']['name']).to match(/ircollector-[-a-z0-9]+/)
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
          httproutes = kubectl.get_httproutes('irvisualizer')
          expect(httproutes).to_not be_nil

          httproutes.map! { |httproute| httproute['metadata']['name'] }
          expect(httproutes).to include('ircollector')
        end

        if Config.lets_encrypt_enabled
          it 'has a valid certificate' do
            wait_until(120,15) {
              # since the migration to envoy gateway all certificates are now in the same global namespace
              # gateway-api was designed by idiots ...
              certificates = kubectl.get_certificates('envoy-gateway-system')
              expect(certificates).to_not be_nil
              expect(certificates.count).to be >= 2

              expect(certificates.any?{ |c| c['metadata']['name'] == 'ircollector-certificate' }).to eq(true)
              certificate = certificates.select{ |c| c['metadata']['name'] == 'ircollector-certificate' }.first

              expect(certificate['spec']).to_not be_nil
              expect(certificate['spec']['dnsNames']).to_not be_nil
              expect(certificate['spec']['dnsNames'].count).to eq(1)
              expect(certificate['spec']['dnsNames']).to include("ircollector.#{Config.domain}")

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

          it "shows series data" do
            wait_until(60,15) {
              response = https_get("https://ircollector.#{Config.domain}/series")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('application/json')
              expect(response.headers[:strict_transport_security]).to include('max-age','includeSubDomains')
              expect(response.body).to include('{ "pk_series_id": 2, "name": "Indy Pro 2000 Championship", "short_name": "Indy Pro 2000 Championship", "regex": "Indy Pro 2000" },')
              expect(response.body).to include('{ "pk_series_id": 4, "name": "USF 2000 Cooper Tires Championship", "short_name": "USF 2000 Championship", "regex": "USF 2000" },')
            }
          end
        end
      end
    end
  end

  describe 'irdiscordbot app', :irvisualizer => true do
    let(:kubectl) { Kubectl.new }

    context 'when enabled' do
      it "exists" do
        wait_until(60,10) {
          deployments = kubectl.get_deployments('irvisualizer')
          expect(deployments).to_not be_nil

          deployments.map! { |deployment| deployment['metadata']['name'] }
          expect(deployments).to include('irdiscordbot')
        }
      end

      it "has running pods for irdiscordbot" do
        kubectl.wait_for_deployment('irdiscordbot', '120s', 'irvisualizer')

        wait_until(120,15) {
          pods = kubectl.get_pods_by_label("app=irvisualizer,app.kubernetes.io/component=discord", 'irvisualizer')
          expect(pods).to_not be_nil
          expect(pods.count).to be == 1 # the deployment has 1 replicas defined

          pods.each{ |pod|
            expect(pod['metadata']['name']).to match(/irdiscordbot-[-a-z0-9]+/)
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
    end
  end
end
