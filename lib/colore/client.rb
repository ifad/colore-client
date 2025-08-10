# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'
require 'json'
require 'logger'
require 'marcel'
require 'securerandom'
require 'tempfile'
require 'uri'

require_relative 'client/version'
require_relative 'errors'

# The Colore module serves as the namespace for the Colore client and related classes.
module Colore
  # The name of the 'current' version.
  CURRENT = 'current'

  # Client for interacting with the Colore service.
  class Client
    attr_reader :backtrace, :logger, :base_uri, :app

    # Generates a document id that is reasonably guaranteed to be unique for your app.
    def self.generate_doc_id
      SecureRandom.uuid
    end

    # Constructor.
    #
    # @param base_uri [String] The base URI of the Colore service that you wish to attach to
    # @param app [String] The name of your application. All documents will be stored under this name
    # @param logger [Logger] An optional logger, which will log all requests and responses. Defaults to `Logger.new(nil)`
    # @param backtrace [Bool] Used for debugging purposes, to extract backtraces from Colore. Defaults to `false`
    # @param user_agent [String] User Agent header that will be sent to Colore. Defaults to `Colore Client`
    def initialize(app:, base_uri:, logger: Logger.new(nil), backtrace: false, user_agent: 'Colore Client')
      @base_uri = base_uri
      @app = app
      @backtrace = backtrace
      @logger = logger
      @connection = Faraday.new(url: base_uri, headers: { 'User-Agent' => user_agent }) do |faraday|
        faraday.request :multipart
        faraday.request :url_encoded
        faraday.adapter :net_http
      end
    end

    # Generates a document id that is reasonably guaranteed to be unique for your app.
    def generate_doc_id
      self.class.generate_doc_id
    end

    # Tests the connection with Colore. Will raise an error if the connection cannot be
    # established.
    def ping # rubocop:disable Naming/PredicateMethod
      send_request :head, '/'
      true
    end

    # Stores the specified document on Colore.
    #
    # @param doc_id [String] the document's unique identifier
    # @param filename [String] the name of the file to store
    # @param content [String or IO] the body of the file
    # @param title [String] An optional short description of the document
    # @param author [String] An optional name of the author of the document
    # @param actions [Array] a list of optional conversions to perform once the
    #        file has been stored (e.g. ['ocr', 'ocr_text']
    # @param callback_url [String] an optional callback URL that Colore will send the
    #        results of its conversions to (one per action). It is your responsibility to
    #        have something listening on this URL, ready to take a JSON object with the
    #        results of the conversion in it
    #
    # @return [Hash] a standard response
    def create_document(doc_id:, filename:, content:, title: nil, author: nil, actions: nil, callback_url: nil)
      params = {}
      params[:title] = title if title
      params[:actions] = actions if actions
      params[:author] = author if author
      params[:callback_url] = callback_url if callback_url
      params[:backtrace] = backtrace if backtrace

      base_filename = File.basename(filename)

      response = nil
      with_tempfile(content) do |io|
        params[:file] = file_param(io)
        response = send_request :put, "#{url_for_base doc_id}/#{encode_param(base_filename)}", params, :json
      end
      response
    end

    # Updates the specified document on Colore - creates a new version and stores the new file.
    #
    # @param doc_id [String] the document's unique identifier
    # @param filename [String] the name of the file to store
    # @param content [String or IO] the body of the file
    # @param author [String] An optional name of the author of the new version
    # @param actions [Array] a list of optional conversions to perform once the
    #        file has been stored (e.g. ['ocr', 'ocr_text']
    # @param callback_url [String] an optional callback URL that Colore will send the
    #        results of its conversions to (one per action). It is your responsibility to
    #        have something listening on this URL, ready to take a JSON object with the
    #        results of the conversion in it
    #
    # @return [Hash] a standard response
    def update_document(doc_id:, filename:, content:, author: nil, actions: nil, callback_url: nil)
      params = {}
      params[:actions] = actions if actions
      params[:author] = author if author
      params[:callback_url] = callback_url if callback_url
      params[:backtrace] = backtrace if backtrace

      base_filename = File.basename(filename)

      response = nil
      with_tempfile(content) do |io|
        params[:file] = file_param(io)
        response = send_request :post, "#{url_for_base(doc_id)}/#{encode_param(base_filename)}", params, :json
      end
      response
    end

    # Updates the document title.
    #
    # @param doc_id [String] the document's unique identifier
    # @param title [String] A short description of the document
    #
    # @return [Hash] a standard response
    def update_title(doc_id:, title:)
      send_request :post, "#{url_for_base(doc_id)}/title/#{encode_param(title)}", {}, :json
    end

    # Requests a conversion of an existing document.
    #
    # @param doc_id [String] the document's unique identifier
    # @param filename [String] the name of the file to convert
    # @param version [String] the version to store (defaults to {Colore::CURRENT})
    # @param action [String] the conversion to perform
    # @param callback_url [String] an optional callback URL that Colore will send the
    #        results of its conversion to. It is your responsibility to
    #        have something listening on this URL, ready to take a JSON object with the
    #        results of the conversion in it
    #
    # @return [Hash] a standard response
    def request_conversion(doc_id:, filename:, action:, version: Colore::CURRENT, callback_url: nil)
      params = {}
      params[:callback_url] = callback_url if callback_url
      params[:backtrace] = backtrace if backtrace

      send_request :post, "#{path_for(doc_id, filename, version)}/#{action}", params, :json
    end

    # Completely deletes a document
    #
    # @param doc_id [String] the document's unique identifier
    #
    # @return [Hash] a standard response
    def delete_document(doc_id:)
      params = {}
      params[:backtrace] = backtrace if backtrace
      send_request :delete, url_for_base(doc_id), params, :json
    end

    # Completely deletes a document's version (you cannot delete the current one)
    #
    # @param doc_id [String] the document's unique identifier
    # @param version [String] the version to delete
    #
    # @return [Hash] a standard response
    def delete_version(doc_id:, version:)
      params = {}
      params[:backtrace] = backtrace if backtrace
      send_request :delete, "#{url_for_base doc_id}/#{version}", params, :json
    end

    # Retrieves a document.
    #
    # Please note that this method puts unwanted load on the Colore service and
    # it is recommended that you access the document directly, using a proxying
    # web server such as Nginx.
    #
    # @param doc_id [String] the document's unique identifier
    # @param version [String] the version to delete
    # @param filename [String] the name of the file to retrieve
    #
    # @return [String] the file contents
    def get_document(doc_id:, filename:, version: Colore::CURRENT)
      params = {}
      params[:backtrace] = backtrace if backtrace
      send_request :get, path_for(doc_id, filename, version), {}
    end

    # Retrieves information about a document.
    #
    # @param doc_id [String] the document's unique identifier
    #
    # @return [Hash] a list of document details
    def get_document_info(doc_id:)
      params = {}
      params[:backtrace] = backtrace if backtrace
      send_request :get, url_for_base(doc_id), params, :json
    end

    # Performs a foreground conversion of a file.
    #
    # @param content [String] the file contents
    # @param action [String] the conversion to perform
    # @param language [String] the language of the file (defaults to 'en') - only needed for OCR operations
    #
    # @return [Hash] a standard response
    def convert(content:, action:, language: 'en')
      params = {}

      response = nil
      with_tempfile(content) do |io|
        params[:file] = file_param(io)
        params[:action] = action
        params[:language] = language if language
        params[:backtrace] = backtrace if backtrace
        response = send_request :post, 'convert', params
      end
      response
    end

    # Generates a path for the document based on its ID, filename, and version.
    #
    # @param doc_id [String] the document's unique identifier
    # @param filename [String] the name of the file
    # @param version [String] the version of the document (defaults to {Colore::CURRENT})
    # @return [String] the generated path
    def path_for(doc_id, filename, version = Colore::CURRENT)
      "#{url_for_base doc_id}/#{version}/#{File.basename(filename)}"
    end

    protected

    def url_for_base(doc_id)
      "/document/#{app}/#{doc_id}"
    end

    def send_request(type, path, params = {}, expect = :binary)
      url = path.to_s
      logger.debug("Send #{type}: #{url}")
      logger.debug("  params: #{params.inspect}")
      response =
        if type == :get
          connection.get(url)
        else
          connection.send(type.to_sym, url, params)
        end

      if response.success?
        response_body = response.body

        if expect == :json
          logger.debug("  received : #{response_body}")
          return JSON.parse(response_body)
        else
          logger.debug("  received : [BINARY #{response_body.bytesize} bytes]")
          return response_body
        end
      end

      logger.debug("  received #{response.status}: #{response.reason_phrase}")

      error =
        begin
          Colore::Errors.from JSON.parse(response.body), response.body
        rescue StandardError
          Colore::Errors.from nil, response.body
        end

      raise error
    rescue Faraday::ConnectionFailed
      raise Errors::ColoreUnavailable
    end

    private

    attr_reader :connection

    # Saves the content into a tempfile, rather than trying to read it all into memory
    # This allows us to handle passing an IO for a 300MB file without crashing.
    def with_tempfile(content)
      Tempfile.open('colore') do |tf|
        tf.binmode
        if content.respond_to?(:read)
          IO.copy_stream(content, tf)
        else
          tf.write content
        end
        tf.close
        yield File.new(tf)
      end
    end

    def file_param(io)
      Faraday::Multipart::FilePart.new(io, Marcel::MimeType.for(io))
    end

    def encode_param(param)
      URI.encode_www_form_component(param).gsub('+', '%20')
    end
  end
end
