# frozen_string_literal: true

require 'spec_helper'

describe 'kubectl', :client => true, :fast => true do
  subject(:kubectl) do
    KUBECTL.new()
  end

  it 'can connect to the cluster' do
    info = kubectl.cluster_info
    expect(info).to include("Kubernetes master is running").or include("Kubernetes control plane is running at")
    expect(info).to include("CoreDNS is running")
  end

  it 'can list all expected namespaces' do
    namespaces = kubectl.get_namespaces
    expect(namespaces).to_not be_nil
    expect(namespaces.count).to be > 1

    namespaces.map! { |namespace| namespace['metadata']['name'] }
    expect(namespaces).to include("kube-system", "pgweb", "postgres", "oauth2-proxy")
    if Config.dashboard_enabled
      expect(namespaces).to include("kubernetes-dashboard")
    end
    if Config.grafana_enabled
      expect(namespaces).to include("grafana")
    end
    if Config.ingress_enabled
      expect(namespaces).to include("ingress-nginx")
    end
    if Config.lets_encrypt_enabled
      expect(namespaces).to include("cert-manager")
    end
    if Config.prometheus_enabled
      expect(namespaces).to include("prometheus")
    end
    if Config.loki_enabled
      expect(namespaces).to include("loki")
    end
    if Config.longhorn_enabled
      expect(namespaces).to include("longhorn-system")
    end
    if Config.backman_enabled
      expect(namespaces).to include("backman")
    end
    if Config.home_info_enabled
      expect(namespaces).to include("home-info")
    end
    if Config.irvisualizer_enabled
      expect(namespaces).to include("irvisualizer")
    end
    if Config.jcio_enabled
      expect(namespaces).to include("jcio")
    end
    if Config.resume_enabled
      expect(namespaces).to include("resume")
    end
    if Config.repo_mirrorer_enabled
      expect(namespaces).to include("repo-mirrorer")
    end
    if Config.image_puller_enabled
      expect(namespaces).to include("image-puller")
    end
    expect(namespaces).to include(Config.namespace)
  end
end
