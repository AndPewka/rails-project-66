# frozen_string_literal: true

require 'dry/container'
require 'dry/auto_inject'
require 'dry/container/stub'

class ApplicationContainer
  extend Dry::Container::Mixin
end

Import = Dry::AutoInject(ApplicationContainer)

ApplicationContainer.enable_stubs! if Rails.env.test?
