# frozen_string_literal: true
require 'spec_helper'

RSpec.describe "backman app", type: :feature, js: true, if: Config.backman_enabled do
  let(:kubectl) { Kubectl.new }

  context 'when enabled' do
    it "exists" do
      wait_until(60,10) {
        deployments = kubectl.get_deployments('backman')
        expect(deployments).to_not be_nil

        deployments.map! { |deployment| deployment['metadata']['name'] }
        expect(deployments).to include('backman')
      }
    end

    it "has running pods" do
      kubectl.wait_for_deployment('backman', '120s', 'backman')

      wait_until(120,15) {
        pods = kubectl.get_pods_by_label("app.kubernetes.io/name=backman", 'backman')
        expect(pods).to_not be_nil
        expect(pods.count).to be == 1 # the deployment has 1 replicas defined

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/backman-[-a-z0-9]+/)
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
        httproutes = kubectl.get_httproutes('backman')
        expect(httproutes).to_not be_nil

        httproutes.map! { |httproute| httproute['metadata']['name'] }
        expect(httproutes).to include('backman')
      end

      if Config.lets_encrypt_enabled
        it 'has a valid certificate' do
          wait_until(120,15) {
            # since the migration to envoy gateway all certificates are now in the same global namespace
            # gateway-api was designed by idiots ...
            certificates = kubectl.get_certificates('envoy-gateway-system')
            expect(certificates).to_not be_nil
            expect(certificates.count).to be >= 1

            expect(certificates.any?{ |c| c['metadata']['name'] == "backman-certificate" }).to eq(true)
            certificate = certificates.select{ |c| c['metadata']['name'] == "backman-certificate" }.first

            expect(certificate['spec']).to_not be_nil
            expect(certificate['spec']['dnsNames']).to_not be_nil
            expect(certificate['spec']['dnsNames'].count).to eq(1)
            expect(certificate['spec']['dnsNames'][0]).to eq("backman.#{Config.domain}")

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

        it "can be https queried at [backman.#{Config.domain}] and displays the dex login page" do
          response = https_get("https://backman.#{Config.domain}")
          expect(response.code).to eq(200)
          expect(response.headers[:content_type]).to include('text/html')
          expect(response.headers[:strict_transport_security]).to include('max-age','includeSubDomains')
          expect(response.body).to include('<title>JamesClonk.io</title>', '<div class="dex-container">')
          expect(response.body).to include('<h2 class="theme-heading">Log in to Your Account</h2>', '<label for="userid">Email Address</label>')
        end

        context "when doing the login process" do
          it "is logged-in" do
            visit_and_login "https://backman.#{Config.domain}/"
            page.driver.browser.navigate.to "https://#{Config.backman_username}:#{Config.backman_password}@backman.#{Config.domain}/"
            wait_until(15,3) {
              expect(page.html).to include('<title>💽 backman - Services</title>')
              expect(page.html).to include('Open Source! 😍')
              expect(page).to have_content 'movie_db'
              expect(page).to have_content 'irvisualizer_db'
              expect(page).to have_content 'home_info_db'
              expect(page).to have_content 'Provider / Plan'
              expect(page).to have_content 'Backup Schedule'
              expect(page).to have_content 'cluster.local'
            }
          end

          it "displays the database overview" do
            visit_and_login "https://backman.#{Config.domain}/service/postgres/movie_db"
            page.driver.browser.navigate.to "https://#{Config.backman_username}:#{Config.backman_password}@backman.#{Config.domain}/service/postgres/movie_db"
            wait_until(15,3) {
              expect(page).to have_content 'movie_db'
              expect(page).to have_content 'Backups'
              expect(page).to have_content 'Filename'
              expect(page).to have_content 'Last Modified'
              expect(page).to have_content 'Create Backup'
            }
          end

          it "queries movie_db backups via API call" do
            visit_and_login "https://backman.#{Config.domain}/api/v1/backup/postgres/movie_db"
            page.driver.browser.navigate.to "https://#{Config.backman_username}:#{Config.backman_password}@backman.#{Config.domain}/api/v1/backup/postgres/movie_db"
            wait_until(15,3) {
              expect(page).to have_content 'movie_db'
              expect(page).to have_content(/movie_db_#{(Date.today - 1).strftime('%Y%m%d')}\d{6}.gz/)
              expect(page).to have_content(/movie_db_#{(Date.today - 2).strftime('%Y%m%d')}\d{6}.gz/)
              expect(page).to have_content(/movie_db_#{(Date.today - 3).strftime('%Y%m%d')}\d{6}.gz/)
            }
          end

          it "queries irvisualizer_db backups via API call" do
            visit_and_login "https://backman.#{Config.domain}/api/v1/backup/postgres/irvisualizer_db"
            page.driver.browser.navigate.to "https://#{Config.backman_username}:#{Config.backman_password}@backman.#{Config.domain}/api/v1/backup/postgres/irvisualizer_db"
            wait_until(15,3) {
              expect(page).to have_content 'irvisualizer_db'
              expect(page).to have_content(/irvisualizer_db_#{(Date.today - 1).strftime('%Y%m%d')}\d{6}.gz/)
              expect(page).to have_content(/irvisualizer_db_#{(Date.today - 2).strftime('%Y%m%d')}\d{6}.gz/)
              expect(page).to have_content(/irvisualizer_db_#{(Date.today - 3).strftime('%Y%m%d')}\d{6}.gz/)
            }
          end

          it "queries home_info_db backups via API call" do
            visit_and_login "https://backman.#{Config.domain}/api/v1/backup/postgres/home_info_db"
            page.driver.browser.navigate.to "https://#{Config.backman_username}:#{Config.backman_password}@backman.#{Config.domain}/api/v1/backup/postgres/home_info_db"
            wait_until(15,3) {
              expect(page).to have_content 'home_info_db'
              expect(page).to have_content(/home_info_db_#{(Date.today - 1).strftime('%Y%m%d')}\d{6}.gz/)
              expect(page).to have_content(/home_info_db_#{(Date.today - 2).strftime('%Y%m%d')}\d{6}.gz/)
              expect(page).to have_content(/home_info_db_#{(Date.today - 3).strftime('%Y%m%d')}\d{6}.gz/)
            }
          end
        end
      end
    end
  end
end
