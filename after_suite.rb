# frozen_string_literal: true

require 'rest-client'
require 'securerandom'

require_relative 'spec/support/kubectl'
require_relative 'spec/support/config'
require_relative 'spec/support/util'

include UtilHelpers

puts "running env cleanup for kubernetes-testing ..."
kubectl = Kubectl.new
kubectl.cleanup_env
puts "finished cleaning up kubernetes-testing!"
