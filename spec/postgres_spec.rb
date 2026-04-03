# frozen_string_literal: true

require 'date'
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

      it "accepts database connections" do
        wait_until(120,15) {
          secrets = kubectl.get_secrets_by_label('app.kubernetes.io/component=secret', 'postgres')
          expect(secrets).to_not be_nil
          expect(secrets.count).to be >= 2

          secret = secrets.select { |i| i['metadata']['name'].include?('postgres') }.first
          db_host = Base64.decode64(secret['data']['DB_HOST'])
          db_port = Base64.decode64(secret['data']['DB_PORT'])
          db_user = Base64.decode64(secret['data']['DB_USER'])

          pods = kubectl.get_pods_by_label("app=postgres,app.kubernetes.io/component=database", 'postgres')
          expect(pods).to_not be_nil
          expect(pods.count).to be >= 1

          pod_name = pods.first['metadata']['name']
          result = kubectl.exec_command(pod_name, "pg_isready -h #{db_host} -p #{db_port} -U #{db_user}", 'postgres')
          expect(result).to include('accepting connections')
        }
      end

      it "has recent files in the s3 backup bucket" do
        wait_until(120,15) {
          secrets = kubectl.get_secrets_by_label('app.kubernetes.io/component=secret', 'postgres')
          expect(secrets).to_not be_nil
          expect(secrets.count).to be >= 2

          secret = secrets.select { |i| i['metadata']['name'].include?('pgbackup') }.first
          s3_endpoint = Base64.decode64(secret['data']['S3_ENDPOINT']).strip
          s3_bucket = Base64.decode64(secret['data']['S3_BUCKET']).strip
          s3_access_key = Base64.decode64(secret['data']['S3_ACCESS_KEY']).strip
          s3_secret_key = Base64.decode64(secret['data']['S3_SECRET_KEY']).strip

          runner = CommandRunner::Runner.new
          runner.run("mc alias set pgbackup #{s3_endpoint} #{s3_access_key} #{s3_secret_key} --api S3v4")
          result = runner.run("mc ls --json pgbackup/#{s3_bucket}/pgbackup/")
          expect(result).to_not be_nil

          entries = result.strip.split("\n").map { |line| JSON.parse(line) }
          expect(entries.count).to be >= 3

          # check that the latest file is not older than 2 days
          latest_date = entries.map { |e| Date.parse(e['lastModified']) }.max
          expect(latest_date).to be >= (Date.today - 2)

          # check that the latest file is bigger than 100MB
          latest_entry = entries.max_by { |e| Time.parse(e['lastModified']) }
          expect(latest_entry['size']).to be > 100 * 1024 * 1024
        }
      end
    end
  end
end
