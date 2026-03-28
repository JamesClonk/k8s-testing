# frozen_string_literal: true
require 'spec_helper'

RSpec.describe "dashboard app", type: :feature, js: true, if: Config.dashboard_enabled do
  let(:kubectl) { Kubectl.new }

  context 'when enabled' do
    it "exists" do
      wait_until(60,10) {
        deployments = kubectl.get_deployments('headlamp')
        expect(deployments).to_not be_nil

        deployments.map! { |deployment| deployment['metadata']['name'] }
        expect(deployments).to include('headlamp')
      }
    end

    it "has running pods" do
      kubectl.wait_for_deployment('headlamp', '120s', 'headlamp')

      wait_until(120,15) {
        pods = kubectl.get_pods_by_label("app.kubernetes.io/name=headlamp", 'headlamp')
        expect(pods).to_not be_nil
        expect(pods.count).to be == 1 # the deployment has 1 replicas defined

        pods.each{ |pod|
          expect(pod['metadata']['name']).to match(/headlamp-[-a-z0-9]+/)
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
        httproutes = kubectl.get_httproutes('headlamp')
        expect(httproutes).to_not be_nil

        httproutes.map! { |httproute| httproute['metadata']['name'] }
        expect(httproutes).to include('headlamp')
      end

      if Config.lets_encrypt_enabled
        it 'has a valid certificate' do
          wait_until(120,15) {
            # since the migration to envoy gateway all certificates are now in the same global namespace
            # gateway-api was designed by idiots ...
            certificates = kubectl.get_certificates('envoy-gateway-system')
            expect(certificates).to_not be_nil
            expect(certificates.count).to be >= 1

            expect(certificates.any?{ |c| c['metadata']['name'] == "headlamp-certificate" }).to eq(true)
            certificate = certificates.select{ |c| c['metadata']['name'] == "headlamp-certificate" }.first

            expect(certificate['spec']).to_not be_nil
            expect(certificate['spec']['dnsNames']).to_not be_nil
            expect(certificate['spec']['dnsNames'].count).to eq(1)
            expect(certificate['spec']['dnsNames'][0]).to eq("dashboard.#{Config.domain}")

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

        it "can be https queried at [dashboard.#{Config.domain}] and displays the dex login page" do
          response = https_get("https://dashboard.#{Config.domain}")
          expect(response.code).to eq(200)
          expect(response.headers[:content_type]).to include('text/html')
          expect(response.headers[:strict_transport_security]).to include('max-age','includeSubDomains')
          expect(response.body).to include('<title>JamesClonk.io</title>', '<div class="dex-container">')
          expect(response.body).to include('<h2 class="theme-heading">Log in to Your Account</h2>', '<label for="userid">Email Address</label>')
        end

        context "when doing the login process" do
          before(:each) do
            Capybara.reset_sessions!
            visit "https://dashboard.#{Config.domain}/"
            sleep 2
            expect(find_field(name: "login").value).to eq("")
            expect(find_field(name: "password").value).to eq("")
            fill_in "login", with: Config.static_username
            fill_in "password", with: Config.static_password
            find('button[type="submit"]').click
            sleep 3 # unfortunately we have to wait here to make sure the login/javascript did their work
          end

          it "is logged-in" do
            visit "https://dashboard.#{Config.domain}/"
            wait_until(15,3) {
              expect(page.html).to include('<meta name="description" content="Headlamp: Kubernetes Web UI">')
              expect(page.html).to include('<title>default - Cluster</title>')
              expect(page).to have_content 'Overview'
              expect(page).to have_content 'Memory Usage'
              expect(page).to have_content 'CPU Usage'
              expect(page).to have_content 'Nodes'
              expect(page).to have_content 'Events'
            }
          end

          it "displays nodes" do
            visit "https://dashboard.#{Config.domain}/c/default/nodes"
            wait_until(15,3) {
              expect(page).to have_content 'kubernetes'
              expect(page).to have_content 'control-plane'
              expect(page).to have_content 'Taints'
            }
          end

          it "displays deployments" do
            visit "https://dashboard.#{Config.domain}/c/default/deployments"
            wait_until(15,3) {
              expect(page).to have_content 'home-info'
              expect(page).to have_content 'moviedb-frontend'
              expect(page).to have_content 'backman'
              expect(page).to have_content 'ircollector'
            }
          end

          it "displays deployment details" do
            visit "https://dashboard.#{Config.domain}/c/default/deployments/jcio/jcio-frontend"
            wait_until(15,3) {
              expect(page).to have_content 'jcio-frontend'
              expect(page).to have_content 'app.kubernetes.io/component: jcio-frontend'
              expect(page).to have_content 'index.docker.io/jamesclonk/jcio-frontend'
              expect(page).to have_content 'TCP:3000'
            }
          end

          if Config.grafana_enabled
            it "displays replica sets" do
              visit "https://dashboard.#{Config.domain}/c/default/replicasets?namespace=grafana"
              wait_until(15,3) {
                expect(page).to have_content 'Replica Sets'
                expect(page).to have_content 'index.docker.io/grafana/grafana'
                expect(page).to have_content 'app.kubernetes.io/instance: grafana'
                expect(page).to have_content 'app.kubernetes.io/name: grafana'
              }
            end
          end

          if Config.loki_enabled
            it "displays stateful sets" do
              visit "https://dashboard.#{Config.domain}/c/default/statefulsets?namespace=loki"
              wait_until(15,3) {
                expect(page).to have_content 'Stateful Sets'
                expect(page).to have_content 'loki'
                expect(page).to have_content 'index.docker.io/grafana/loki'
              }
            end
          end

          if Config.prometheus_enabled
            it "displays services" do
              visit "https://dashboard.#{Config.domain}/c/default/services?namespace=prometheus"
              wait_until(15,3) {
                expect(page).to have_content 'Services'
                expect(page).to have_content 'prometheus-server'
                expect(page).to have_content 'prometheus-alertmanager'
                expect(page).to have_content 'prometheus-node-exporter'
                expect(page).to have_content 'prometheus-kube-state-metrics'
                expect(page).to have_content 'app.kubernetes.io/name: alertmanager'
                expect(page).to have_content 'app.kubernetes.io/name: prometheus-node-exporter'
                expect(page).to have_content 'ClusterIP'
              }
            end
          end

          if Config.lets_encrypt_enabled
            it "displays service accounts" do
              visit "https://dashboard.#{Config.domain}/c/default/serviceaccounts?namespace=cert-manager"
              wait_until(15,3) {
                expect(page).to have_content 'Service Accounts'
                expect(page).to have_content 'cert-manager'
                expect(page).to have_content 'cert-manager-webhook'
                expect(page).to have_content 'cert-manager-cainjector'
              }
            end

            it "displays custom resources" do
              visit "https://dashboard.#{Config.domain}/c/default/customresources/clusterissuers.cert-manager.io"
              wait_until(15,3) {
                expect(page).to have_content 'clusterissuers.cert-manager.io'
                expect(page).to have_content 'letsencrypt-prod'
                expect(page).to have_content 'letsencrypt-staging'
                expect(page).to have_content 'The ACME account was registered with the ACME server'
              }
            end
          end
        end
      end
    end
  end
end
