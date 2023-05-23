# frozen_string_literal: true

require 'spec_helper'
require 'date'

if Config.home_info_enabled
  describe 'home-info app', :home_info => true do
    before(:all) do
      @kubectl = KUBECTL.new()
    end

    context 'when enabled' do
      it "exists" do
        wait_until(60,10) {
          deployments = @kubectl.get_deployments('home-info')
          expect(deployments).to_not be_nil

          deployments.map! { |deployment| deployment['metadata']['name'] }
          expect(deployments).to include('home-info')
        }
      end

      it "has running pods" do
        @kubectl.wait_for_deployment('home-info', '120s', 'home-info')

        wait_until(120,15) {
          pods = @kubectl.get_pods_by_label("app=home-info,app.kubernetes.io/component=dashboard", 'home-info')
          expect(pods).to_not be_nil
          expect(pods.count).to be == 1 # the deployment has 1 replicas defined

          pods.each{ |pod|
            expect(pod['metadata']['name']).to match(/home-info-[-a-z0-9]+/)
            expect(pod['status']['phase']).to eq('Running')
            expect(pod['status']['containerStatuses'].count).to be >= 1
            pod['status']['containerStatuses'].each{ |container|
              expect(container['started']).to eq(true)
            }
          }
        }
      end

      if Config.ingress_enabled
        it 'has an ingress' do
          ingresses = @kubectl.get_ingresses('home-info')
          expect(ingresses).to_not be_nil

          ingresses.map! { |ingress| ingress['metadata']['name'] }
          expect(ingresses).to include('home-info')
        end

        if Config.lets_encrypt_enabled
          it 'has a valid certificate' do
            wait_until(120,15) {
              certificates = @kubectl.get_certificates('home-info')
              expect(certificates).to_not be_nil
              expect(certificates.count).to be >= 1

              expect(certificates.any?{ |c| c['metadata']['name'] == "home-info-tls" }).to eq(true)
              certificate = certificates.select{ |c| c['metadata']['name'] == "home-info-tls" }.first

              expect(certificate['spec']).to_not be_nil
              expect(certificate['spec']['dnsNames']).to_not be_nil
              expect(certificate['spec']['dnsNames'].count).to eq(1)
              expect(certificate['spec']['dnsNames'][0]).to eq("home-info.#{Config.domain}")

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

          it "can be https queried via hostname [home-info.#{Config.domain}]" do
            wait_until(60,15) {
              response = https_get("https://home-info.#{Config.domain}")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.headers[:strict_transport_security]).to include('max-age','includeSubDomains')
              expect(response.body).to include('<title>Home Automation</title>', '<h1 class="title">Home Automation</h1>')
              expect(response.body).to include('<h2 class="subtitle">The management website for all my <strong>Raspberry Pi / Arduino / ESP8266</strong> stuff!</h2>')
            }
          end

          it "shows main dashboard data" do
            wait_until(60,10) {
              response = https_get("https://home-info.#{Config.domain}/dashboard")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to match(/plant room: <span class=\"has-text-danger\">[0-9]+°C/)
              expect(response.body).to match(/living room: <span class=\"has-text-danger\">[0-9]+°C/)
              expect(response.body).to match(/bedroom: <span class=\"has-text-danger\">[0-9]+°C/)
              expect(response.body).to match(/plant room: <span class=\"has-text-info\">[0-9]+%/)
              expect(response.body).to match(/living room: <span class=\"has-text-info\">[0-9]+%/)
              expect(response.body).to match(/bedroom: <span class=\"has-text-info\">[0-9]+%/)
              expect(response.body).to include("<small class=\"has-text-danger\">temperature</small><small> - Last Update: #{DateTime.now.strftime('%Y-%m-%d')}")
              expect(response.body).to include("<small class=\"has-text-info\">humidity</small><small> - Last Update: #{DateTime.now.strftime('%Y-%m-%d')}")
            }
          end

          it "shows sensor data" do
            wait_until(60,10) {
              response = https_get("https://home-info.#{Config.domain}/sensor_data")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to include('<td>🏋️ bathroom scale</td>')
              expect(response.body).to include('<td>🛏️ bedroom</td>')
              expect(response.body).to include('<td>💡 bedroom lamp</td>')
              expect(response.body).to include("<td>#{DateTime.now.strftime('%Y-%m-%d')}")
              expect(response.body).to include('Shows air humidity')
              expect(response.body).to include('Shows soil moisture (capacitive)')
            }
          end

          it "shows alert data" do
            wait_until(60,10) {
              response = https_get("https://home-info.#{Config.domain}/alert_data")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to include('air quality lamp too hot', 'temperature (°C - celsius)', '5;&lt;;30', '*/5 * * * *')
            }
          end

          it "shows forecasts" do
            wait_until(60,10) {
              response = https_get("https://home-info.#{Config.domain}/forecasts")
              expect(response).to_not be_nil
              expect(response.code).to eq(200)
              expect(response.headers[:content_type]).to include('text/html')
              expect(response.body).to include('<h1 class="title">46.9481° / 7.4474°</h1>', '<h2 class="subtitle">549m</h2>')
              expect(response.body).to include("Today<small>, #{DateTime.now.strftime('%A %d.%m.%Y')}</small>")
              expect(response.body).to include("Tomorrow<small>, #{(DateTime.now.next_day(1)).strftime('%A %d.%m.%Y')}</small>")
            }
          end
        end
      end
    end
  end
end
