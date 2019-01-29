require 'grape'

module Test
  class API < Grape::API
    version 'v1', using: :header, vendor: 'test_app'
    format :json

    resource :test do
      desc 'return some json'
      get :test do
        "{ key: 'message', value: 'value'}"
      end
    end
  end
end
