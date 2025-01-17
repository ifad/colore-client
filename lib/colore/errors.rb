# frozen_string_literal: true

module Colore
  # Module for handling Colore-specific errors.
  module Errors
    # Error raised when the Colore storage system is unavailable.
    class ColoreUnavailable < StandardError
      # Initializes the error with a default message.
      def initialize
        super('The Colore storage system is unavailable')
      end
    end

    # Base class for API errors
    class APIError < StandardError
      attr_accessor :http_code, :response_body, :rsp_backtrace

      # Initializes the API error.
      #
      # @param http_code [Integer] the HTTP status code
      # @param message [String] the error message
      # @param rsp_backtrace [Array<String>] the backtrace from the response
      # @param response_body [String] the response body
      def initialize(http_code, message, rsp_backtrace = nil, response_body = nil)
        super(message)
        @http_code = http_code
        @response_body = response_body
        @rsp_backtrace = rsp_backtrace
      end
    end

    # Error class for client-side errors (HTTP status codes 400-499).
    class ClientError < APIError; end

    # Error class for server-side errors (HTTP status codes 500 and above).
    class ServerError < APIError; end

    # Creates an appropriate error object from the given hash.
    #
    # @param hash [Hash, nil] the error details from the API response
    # @param body [String] the response body
    # @return [APIError] the created error object
    def self.from(hash, body)
      if hash.nil?
        ServerError.new(0, 'Unknown error (see response_body)', nil, body)
      else
        case hash['status']
        when 400..499
          ClientError.new(hash['status'].to_i, hash['description'], hash['backtrace'], body)
        else
          ServerError.new(hash['status'].to_i, hash['description'], hash['backtrace'], body)
        end
      end
    end
  end
end
