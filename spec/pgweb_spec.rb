# frozen_string_literal: true
require 'spec_helper'

RSpec.describe "pgweb app", type: :feature, js: true, if: Config.cf_env_enabled do
  let(:kubectl) { Kubectl.new }

  context 'when enabled' do
    it "exists" do
      wait_until(60,10) {
        deployments = kubectl.get_deployments('pgweb')
        expect(deployments).to_not be_nil

        deployments.map! { |deployment| deployment['metadata']['name'] }
        expect(deployments).to include('pgweb')
      }
    end

    it "has running pods" do
      kubectl.wait_for_deployment('pgweb', '120s', 'pgweb')

      wait_until(120,15) {
        pods = kubectl.get_pods_by_label("app=pgweb", 'pgweb')
        expect(pods).to_not be_nil
        expect(pods.count).to be == 1 # the deployment has 1 replicas defined

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/pgweb-[-a-z0-9]+/)
          expect(pod['status']['phase']).to eq('Running')
          expect(pod['status']['containerStatuses'].count).to be >= 1
          pod['status']['containerStatuses'].each{ |container|
            expect(container['started']).to eq(true)
          }
        }
      }
    end

    if Config.httproute_enabled
      it 'has an httproute' do
        httproutes = kubectl.get_httproutes('pgweb')
        expect(httproutes).to_not be_nil

        httproutes.map! { |httproute| httproute['metadata']['name'] }
        expect(httproutes).to include('pgweb')
      end

      if Config.lets_encrypt_enabled
        it 'has a valid certificate' do
          wait_until(120,15) {
            # since the migration to envoy gateway all certificates are now in the same global namespace
            # gateway-api was designed by idiots ...
            certificates = kubectl.get_certificates('envoy-gateway-system')
            expect(certificates).to_not be_nil
            expect(certificates.count).to be >= 1

            expect(certificates.any?{ |c| c['metadata']['name'] == "pgweb-certificate" }).to eq(true)
            certificate = certificates.select{ |c| c['metadata']['name'] == "pgweb-certificate" }.first

            expect(certificate['spec']).to_not be_nil
            expect(certificate['spec']['dnsNames']).to_not be_nil
            expect(certificate['spec']['dnsNames'].count).to eq(1)
            expect(certificate['spec']['dnsNames'][0]).to eq("pgweb.#{Config.domain}")

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

        it "can be https queried at [pgweb.#{Config.domain}] and displays the dex login page" do
          response = https_get("https://pgweb.#{Config.domain}")
          expect(response.code).to eq(200)
          expect(response.headers[:content_type]).to include('text/html')
          expect(response.headers[:strict_transport_security]).to include('max-age','includeSubDomains')
          expect(response.body).to include('<title>JamesClonk.io</title>', '<div class="dex-container">')
          expect(response.body).to include('<h2 class="theme-heading">Log in to Your Account</h2>', '<label for="userid">Email Address</label>')
        end

        context "when doing the login process" do
          it "is logged-in" do
            visit_and_login "https://pgweb.#{Config.domain}/"
            wait_until(15,3) {
              expect(page.html).to include('<title>pgweb</title>')
              expect(page).to have_content 'Bookmark'
              expect(page).to have_content 'Host'
              expect(page).to have_content 'Connect'
              expect(page).to have_content 'home_info'
              expect(page).to have_content 'irvisualizer'
              expect(page).to have_content 'jcio'
            }
          end
        end
      end
    end
  end
end
