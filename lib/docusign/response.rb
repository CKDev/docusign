require 'open-uri'
require 'net/http'

module Docusign
  class Response

    attr_accessor :response, :response_data

    def initialize(response: nil, pdf: false)
      @response = response
      begin
        if response.is_a?(::Net::HTTPResponse) && pdf
          @response_data = response.body
        elsif response.is_a?(::Net::HTTPResponse)
          puts 'parsing JSON'
          @response_data = JSON.parse(response.body).deep_transform_keys { |key| key.to_s.underscore.to_sym }
        else
          @response_data = { error_code: 'NO_RESPONSE', message: 'Provided response object was not an instance of Net::HTTPResponse' }
        end
      rescue => e
        @response_data = { error_code: 'PARSE_ERROR', message: e.message }
      end
    end

    def error?
      response_data[:error_code].present?
    end

    def code
      response_data[:error_code]
    end

    def message
      response_data[:message]
    end

    def method_missing(name, *args, &block)
      if name.to_s =~ /^(\w*)$/
        if response_data.has_key?(name.to_sym)
          ::Docusign::Data.new(response_data).send(name)
        else
          args.first
        end
      else
        super
      end
    end

  end
end