# frozen_string_literal: true

require_relative 'config'

module HttpHelpers

  def http_head(url, args={})
    try_catch {
      RestClient::Request.execute({ url: url, method: :head, verify_ssl: false }.merge(args))
    }
  end

  def http_get(url, args={})
    try_catch {
      RestClient::Request.execute({ url: url, method: :get, verify_ssl: false }.merge(args))
    } 
  end

  def https_testing_get(url, args={})
    try_catch {
      if Config.lets_encrypt_staging
        args.merge!(ssl_ca_file: 'spec/support/letsencrypt-staging/static/certs/staging/letsencrypt-stg-root-x1.pem')
      end
      RestClient::Request.execute({ url: url, method: :get, verify_ssl: true }.merge(args))
    }
  end

  def https_testing_patch(url, body, args={})
    try_catch {
      if Config.lets_encrypt_staging
        args.merge!(ssl_ca_file: 'spec/support/letsencrypt-staging/static/certs/staging/letsencrypt-stg-root-x1.pem')
      end
      RestClient::Request.execute({ url: url, method: :patch, verify_ssl: true, payload: body }.merge(args))
    }
  end

  def https_get(url, args={})
    try_catch {
      RestClient::Request.execute({ url: url, method: :get, verify_ssl: true }.merge(args))
    }
  end

  def https_patch(url, body, args={})
    try_catch {
      RestClient::Request.execute({ url: url, method: :patch, verify_ssl: true, payload: body }.merge(args))
    }
  end

  def http_delete(url)
    try_catch {
      RestClient::Request.execute({ url: url, method: :delete, verify_ssl: false })
    }
  end

  def http_post(url, body)
    try_catch {
      RestClient::Request.execute({ url: url, method: :post, verify_ssl: false, payload: body })
    }
  end

  def http_put(url, body)
    try_catch {
      RestClient::Request.execute({ url: url, method: :put, verify_ssl: false, payload: body })
    }
  end

  def http_patch(url, body)
    try_catch {
      RestClient::Request.execute({ url: url, method: :patch, verify_ssl: false, payload: body })
    }
  end

  private

  def try_catch
    yield
  rescue RestClient::Exception => e
    # $stderr.puts e.response
    e.response
  end
end
