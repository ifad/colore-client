# frozen_string_literal: true

module Colore
  module Errors
    class ColoreUnavailable < StandardError
      def initialize
        super('The Colore storage system is unavailable')
      end
    end

    class APIError < StandardError
      attr_accessor :http_code, :response_body, :rsp_backtrace

      def initialize(http_code, message, rsp_backtrace = nil, response_body = nil)
        super(message)
        @http_code = http_code
        @response_body = response_body
        @rsp_backtrace = rsp_backtrace
      end
    end

    class ClientError < APIError; end
    class ServerError < APIError; end

    def self.from(hash, body)
      if hash.nil?
        ServerError.new(0, 'Unknown error (see response_body)', nil, body)
      else
        case hash['status']
        when 400..409
          ClientError.new(hash['status'].to_i, hash['description'], hash['backtrace'], body)
        else
          ServerError.new(hash['status'].to_i, hash['description'], hash['backtrace'], body)
        end
      end
    end
  end
end
