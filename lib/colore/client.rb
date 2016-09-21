require 'json'
require 'tempfile'
require 'rest_client'
require 'securerandom'
require 'logger'

module Colore
  # The name of the 'current' version
  CURRENT = 'current'

  class Client
    attr_accessor :backtrace
    attr_accessor :logger

    # Generates a document id that is reasonably guaranteed to be unique for your app
    def self.generate_doc_id
      SecureRandom.uuid
    end

    # Constructor
    # @param base_uri [String] The base URI of the Colore service that you wish to attach to
    # @param app [String] The name of your application (all documents will be stored under this name)
    # @param logger [Logger] An optional logger, which will log all requests and responses
    # @param backtrace [Bool] Used for debugging purposes, to extract backtraces from Colore
    def initialize( base_uri: 'http://localhost:9240/', app:, logger: Logger.new(nil), backtrace: false )
      @base_uri = base_uri
      @app = app
      @backtrace = backtrace
      @logger = logger
    end

    # Generates a document id that is reasonably guaranteed to be unique for your app
    def generate_doc_id
      self.class.generate_doc_id
    end

    # Tests the connection with Colore. Will raise an error if the connection cannot be
    # established.
    def ping
      response, body = send_request :get, '', :binary
      true
    end

    # Stores the specified document on Colore
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
    #        results of the conversion in it.
    # @param ephemeral [Boolean] marks the document as ephemeral. Won't be stored indefinitely
    def create_document( doc_id:, filename:, content:, title:nil, author:nil, actions:nil, callback_url:nil, ephemeral:false)
      params = {}
      params[:title] = title if title
      params[:actions] = actions if actions
      params[:author] = author if author
      params[:callback_url] = callback_url if callback_url
      params[:ephemeral] = ephemeral if ephemeral
      params[:backtrace] = @backtrace if @backtrace

      base_filename = File.basename(filename)
      response = nil
      with_tempfile(content) do |io|
        params[:file] = io
        response = send_request :put, "#{url_for_base doc_id}/#{base_filename}", params, :json
      end
      response
    end

    # Updates the specified document on Colore - creates a new version and stores the new file.
    # @param doc_id [String] the document's unique identifier
    # @param filename [String] the name of the file to store
    # @param content [String or IO] the body of the file
    # @param author [String] An optional name of the author of the new version
    # @param actions [Array] a list of optional conversions to perform once the
    #        file has been stored (e.g. ['ocr', 'ocr_text']
    # @param callback_url [String] an optional callback URL that Colore will send the
    #        results of its conversions to (one per action). It is your responsibility to
    #        have something listening on this URL, ready to take a JSON object with the
    #        results of the conversion in it.
    def update_document( doc_id:, filename:, content: nil, author: nil, actions:nil, callback_url:nil )
      params = {}
      params[:actions] = actions if actions
      params[:author] = author if author
      params[:callback_url] = callback_url if callback_url
      params[:backtrace] = @backtrace if @backtrace

      base_filename = File.basename(filename)
      response = nil
      if content
        with_tempfile(content) do |io|
          params[:file] = io
          response = send_request :post, "document/#{@app}/#{doc_id}/#{base_filename}", params, :json
        end
      else
        response = send_request :post, "document/#{@app}/#{doc_id}/#{base_filename}", params, :json
      end
      response
    end

    # Updates the document title
    # @param doc_id [String] the document's unique identifier
    # @param title [String] A short description of the document
    def update_title( doc_id:, title: )
      send_request :post, "document/#{@app}/#{doc_id}/title/#{URI.escape title}", {}, :json
    end

    # Requests a conversion of an existing document
    # @param doc_id [String] the document's unique identifier
    # @param filename [String] the name of the file to convert
    # @param version [String] the version to store (if not specified, will be [CURRENT]
    # @param action [String] the conversion to perform
    # @param callback_url [String] an optional callback URL that Colore will send the
    #        results of its conversion to. It is your responsibility to
    #        have something listening on this URL, ready to take a JSON object with the
    #        results of the conversion in it.
    # @return [Hash] a standard response
    def request_conversion( doc_id:, version:CURRENT, filename:, action:, callback_url:nil )
      params = {}
      params[:callback_url] = callback_url if callback_url
      params[:backtrace] = @backtrace if @backtrace

      send_request :post, "#{path_for(doc_id, filename, version)}/#{action}", params, :json
    end

    # Completely deletes a document
    # @param doc_id [String] the document's unique identifier
    # @return [Hash] a standard response
    def delete_document( doc_id: )
      params = {}
      params[:backtrace] = @backtrace if @backtrace
      send_request :delete, url_for_base(doc_id), params, :json
    end

    # Completely deletes a document's version (you cannot delete the current one)
    # @param doc_id [String] the document's unique identifier
    # @param version [String] the version to delete
    # @return [Hash] a standard response
    def delete_version( doc_id:, version: )
      params = {}
      params[:backtrace] = @backtrace if @backtrace
      send_request :delete, "#{url_for_base doc_id}/#{version}", params, :json
    end

    # Retrieves a document. Please note that this method puts unwanted load on the Colore
    # service and it is recommended that you access the document directly, using a proxying
    # web server such as Nginx.
    # @param doc_id [String] the document's unique identifier
    # @param version [String] the version to delete
    # @param filename [String] the name of the file to retrieve
    # @return [String] the file contents
    def get_document( doc_id:, version:CURRENT, filename: )
      params = {}
      params[:backtrace] = @backtrace if @backtrace
      send_request :get, path_for(doc_id, filename, version), {}, :binary
    end

    # Retrieves information about a document.
    # @param doc_id [String] the document's unique identifier
    # @return [Hash] a list of document details
    def get_document_info( doc_id: )
      params = {}
      params[:backtrace] = @backtrace if @backtrace
      send_request :get, url_for_base(doc_id), params, :json
    end

    # Performs a foreground conversion of a file
    # @param content [String] the file contents
    # @param action [String] the conversion to perform
    # @param language [String] the language of the file (defaults to 'en') - only needed for OCR operations
    def convert( content:, action:, language:'en' )
      params = {}
      response = nil
      with_tempfile(content) do |io|
        params[:file] = io
        params[:action] = action
        params[:language] = language if language
        params[:backtrace] = @backtrace if @backtrace
        response  = send_request :post, "convert", params, :binary
      end
      response
    end

    def path_for(doc_id, filename, version = 'current')
      "#{url_for_base doc_id}/#{version}/#{File.basename(filename)}"
    end

    protected

    def url_for_base doc_id
      "/document/#{@app}/#{doc_id}"
    end

    def send_request type, path, params={}, expect=:binary
      url = URI.join(@base_uri, path).to_s
      logger.debug( "Send #{type}: #{url}" )
      logger.debug( "  params: #{params.inspect}" )
      response = nil
      case type
        when :get
          response = RestClient.get url
        else
          response = RestClient.send type.to_sym, url, params
      end
      if expect == :json
        logger.debug( "  received : #{response}")
        return JSON.parse(response)
      else
        logger.debug( "  received : [BINARY #{response.size} bytes]")
        return response
      end
    rescue Errno::ECONNREFUSED
      raise Errors::ColoreUnavailable.new
    rescue RestClient::InternalServerError, RestClient::BadRequest, RestClient::Conflict => e
      logger.debug( "  received #{e.class.name}: #{e.message}")
      error = nil
      begin
        error = Colore::Errors.from JSON.parse(e.http_body), e.http_body
      rescue StandardError => ex
        error = Colore::Errors.from nil, e.http_body
      end
      raise error
    end

    #
    # Saves the content into a tempfile, rather than trying to read it all into memory
    # This allows us to handle passing an IO for a 300MB file without crashing.
    # RestClient needs a file for uploads.
    #
    def with_tempfile content, &block
      Tempfile.open( 'colore' ) do |tf|
        tf.binmode
        if content.respond_to?(:read)
          IO.copy_stream(content,tf)
        else
          tf.write content
        end
        tf.close
        yield File.new(tf)
      end
    end
  end
end
