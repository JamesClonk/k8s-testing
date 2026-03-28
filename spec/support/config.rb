# frozen_string_literal: true
require 'base64'
require 'yaml'
require 'json'
require_relative 'kubectl'

module Config
  @@config = YAML.load_file('config.yml')
  @@static_user = nil
  @@backman_config_json = nil

  def self.static_user
    @@static_user ||= begin
      kubectl = ::Kubectl.new
      kubectl.get_secret('static-user', 'dex')
    end
  end

  def self.backman_config_json
    @@backman_config_json ||= begin
      kubectl = ::Kubectl.new
      secret = kubectl.get_secrets_by_label('app.kubernetes.io/component=secret', 'backman')[0]
      JSON.parse(Base64.decode64(secret['data']['config.json']))
    end
  end

  def self.tmp_path
    return '/tmp' if @@config['tmp_path'] == nil
    return '/tmp' if @@config['tmp_path'].to_s.empty?
    "#{@@config['tmp_path']}"
  end

  def self.namespace
    return 'k8s-testing' if @@config['namespace'] == nil
    return 'k8s-testing' if @@config['namespace'].to_s.empty?
    @@config['namespace']
  end

  def self.domain
    @@config['domain']
  end

  def self.random_names
    return false if @@config['random_names'] == nil
    @@config['random_names']
  end

  def self.static_username
    Base64.decode64(static_user['data']['email'])
  end

  def self.static_password
    Base64.decode64(static_user['data']['password'])
  end

  def self.backman_username
    backman_config_json['username']
  end

  def self.backman_password
    backman_config_json['password']
  end

  def self.deployment_enabled
    return true if @@config['deployment'] == nil
    return true if @@config['deployment']['enabled'] == nil
    return true if @@config['deployment']['enabled'].to_s.empty?
    @@config['deployment']['enabled']
  end

  def self.dashboard_enabled
    return true if @@config['dashboard'] == nil
    return true if @@config['dashboard']['enabled'] == nil
    return true if @@config['dashboard']['enabled'].to_s.empty?
    @@config['dashboard']['enabled']
  end

  def self.cf_env_enabled
    return true if @@config['cf_env'] == nil
    return true if @@config['cf_env']['enabled'] == nil
    return true if @@config['cf_env']['enabled'].to_s.empty?
    @@config['cf_env']['enabled']
  end

  def self.grafana_enabled
    return true if @@config['grafana'] == nil
    return true if @@config['grafana']['enabled'] == nil
    return true if @@config['grafana']['enabled'].to_s.empty?
    @@config['grafana']['enabled']
  end

  def self.httproute_enabled
    return true if @@config['httproute'] == nil
    return true if @@config['httproute']['enabled'] == nil
    return true if @@config['httproute']['enabled'].to_s.empty?
    @@config['httproute']['enabled']
  end

  def self.lets_encrypt_enabled
    return true if @@config['lets_encrypt'] == nil
    return true if @@config['lets_encrypt']['enabled'] == nil
    return true if @@config['lets_encrypt']['enabled'].to_s.empty?
    @@config['lets_encrypt']['enabled']
  end

  def self.prometheus_enabled
    return true if @@config['prometheus'] == nil
    return true if @@config['prometheus']['enabled'] == nil
    return true if @@config['prometheus']['enabled'].to_s.empty?
    @@config['prometheus']['enabled']
  end

  def self.loki_enabled
    return true if @@config['loki'] == nil
    return true if @@config['loki']['enabled'] == nil
    return true if @@config['loki']['enabled'].to_s.empty?
    @@config['loki']['enabled']
  end

  def self.longhorn_enabled
    return true if @@config['longhorn'] == nil
    return true if @@config['longhorn']['enabled'] == nil
    return true if @@config['longhorn']['enabled'].to_s.empty?
    @@config['longhorn']['enabled']
  end

  def self.pvc_enabled
    return true if @@config['pvc'] == nil
    return true if @@config['pvc']['enabled'] == nil
    return true if @@config['pvc']['enabled'].to_s.empty?
    @@config['pvc']['enabled']
  end

  def self.backman_enabled
    return true if @@config['backman'] == nil
    return true if @@config['backman']['enabled'] == nil
    return true if @@config['backman']['enabled'].to_s.empty?
    @@config['backman']['enabled']
  end

  def self.home_info_enabled
    return true if @@config['home_info'] == nil
    return true if @@config['home_info']['enabled'] == nil
    return true if @@config['home_info']['enabled'].to_s.empty?
    @@config['home_info']['enabled']
  end

  def self.irvisualizer_enabled
    return true if @@config['irvisualizer'] == nil
    return true if @@config['irvisualizer']['enabled'] == nil
    return true if @@config['irvisualizer']['enabled'].to_s.empty?
    @@config['irvisualizer']['enabled']
  end

  def self.jcio_enabled
    return true if @@config['jcio'] == nil
    return true if @@config['jcio']['enabled'] == nil
    return true if @@config['jcio']['enabled'].to_s.empty?
    @@config['jcio']['enabled']
  end

  def self.resume_enabled
    return true if @@config['resume'] == nil
    return true if @@config['resume']['enabled'] == nil
    return true if @@config['resume']['enabled'].to_s.empty?
    @@config['resume']['enabled']
  end

  def self.repo_mirrorer_enabled
    return true if @@config['repo_mirrorer'] == nil
    return true if @@config['repo_mirrorer']['enabled'] == nil
    return true if @@config['repo_mirrorer']['enabled'].to_s.empty?
    @@config['repo_mirrorer']['enabled']
  end

  def self.image_puller_enabled
    return true if @@config['image_puller'] == nil
    return true if @@config['image_puller']['enabled'] == nil
    return true if @@config['image_puller']['enabled'].to_s.empty?
    @@config['image_puller']['enabled']
  end

  def self.lets_encrypt_issuer
    return "lets-encrypt" if @@config['lets_encrypt'] == nil
    return "lets-encrypt" if @@config['lets_encrypt']['issuer'] == nil
    return "lets-encrypt" if @@config['lets_encrypt']['issuer'].to_s.empty?
    @@config['lets_encrypt']['issuer']
  end

  def self.lets_encrypt_server
    return "https://acme-v02.api.letsencrypt.org/directory" if @@config['lets_encrypt'] == nil
    return "https://acme-v02.api.letsencrypt.org/directory" if @@config['lets_encrypt']['server'] == nil
    return "https://acme-v02.api.letsencrypt.org/directory" if @@config['lets_encrypt']['server'].to_s.empty?
    @@config['lets_encrypt']['server']
  end

  def self.lets_encrypt_staging
    lets_encrypt_server == "https://acme-staging-v02.api.letsencrypt.org/directory"
  end
end
