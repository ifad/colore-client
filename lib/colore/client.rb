require 'json'
require 'tempfile'
require 'rest_client'
require 'securerandom'
require 'logger'
require 'hashugar'

module Colore
  CURRENT = 'current'

  class Client
    attr_accessor :backtrace
    attr_accessor :logger

    def initialize( base_uri: 'http://localhost:9240/', app:, backtrace: false, logger: Logger.new(nil) )
      @base_uri = base_uri
      @app = app
      @backtrace = backtrace
      @logger = logger
    end

    def url_for_base doc_id
      "document/#{@app}/#{doc_id}"
    end

    def url_for doc_id, version, filename
      "#{url_for_base doc_id}/#{version}/#{File.basename(filename)}"
    end

    def generate_doc_id
      SecureRandom.uuid
    end

    def ping
      response, body = send_request :get, '', :binary
      body
    end

    def create_document( doc_id:, filename:, content:, title:nil, formats:nil, callback_url:nil )
      params = {}
      params[:title] = title if title
      params[:formats] = formats if formats
      params[:callback_url] = callback_url if callback_url
      params[:backtrace] = @backtrace if @backtrace

      base_filename = File.basename(filename)
      response = nil
      Tempfile.open( 'colore' ) do |tf|
        tf.write content
        tf.close
        params[:file] = File.new(tf)
        response = send_request :put, "#{url_for_base doc_id}/#{base_filename}", params, :json
      end
      response
    end

    def update_document( doc_id:, version:CURRENT, filename:, content: nil, title:nil, formats:nil, callback_url:nil )
      params = {}
      params[:title] = title if title
      params[:formats] = formats if formats
      params[:callback_url] = callback_url if callback_url
      params[:backtrace] = @backtrace if @backtrace

      base_filename = File.basename(filename)
      response = nil
      if content
        Tempfile.open( 'colore' ) do |tf|
          tf.write content
          tf.close
          params[:file] = File.new(tf)
          response = send_request :post, "document/#{@app}/#{doc_id}/#{base_filename}", params, :json
        end
      else
        response = send_request :post, "document/#{@app}/#{doc_id}/#{base_filename}", params, :json
      end
      response
    end

    def request_new_format( doc_id:, version:CURRENT, filename:, format:, callback_url:nil )
      params = {}
      params[:callback_url] = callback_url if callback_url
      params[:backtrace] = @backtrace if @backtrace

      send_request :post, "#{url_for doc_id, version, filename}/#{format}", params, :json
    end

    def delete_document( doc_id: )
      params = {}
      params[:backtrace] = @backtrace if @backtrace
      send_request :delete, url_for_base(doc_id), params, :json
    end

    def delete_version( doc_id:, version: )
      params = {}
      params[:backtrace] = @backtrace if @backtrace
      send_request :delete, "#{url_for_base doc_id}/#{version}", params, :json
    end

    def get_document( doc_id:, version:CURRENT, filename: )
      params = {}
      params[:backtrace] = @backtrace if @backtrace
      send_request :get, url_for(doc_id,version,filename), {}, :binary
    end

    def get_document_info( doc_id: )
      params = {}
      params[:backtrace] = @backtrace if @backtrace
      send_request :get, url_for_base(doc_id), params, :json
    end

    def convert( content:, format:, language:nil )
      params = {}
      response = nil
      Tempfile.open( 'colore' ) do |tf|
        tf.write(content)
        tf.close
        params[:file] = File.new(tf)
        params[:format] = format
        params[:language] = language if language
        params[:backtrace] = @backtrace if @backtrace
        response  = send_request :post, "convert", params, :binary
      end
      response 
    end

    protected

    def send_request type, path, params={}, expect=:binary
      url = "#{@base_uri}#{path}"
      logger.debug( "Send #{type}: #{url}" )
      logger.debug( "  params: #{params.inspect}" )
      response = nil
      case type
        when :get
          response = RestClient.get url 
        else
          response = RestClient.send type.to_sym, url , params
      end
      logger.debug( "  received : #{response}")
      return JSON.parse(response).to_hashugar if expect == :json
      return response
    rescue RestClient::InternalServerError, RestClient::BadRequest, RestClient::Conflict => e
      logger.debug( "  received #{e.class.name}: #{e.message}")
      error = nil
      begin
        error = Errors.from JSON.parse(e.http_body), e.http_body
      rescue StandardError => ex
        error = Errors.from nil, e.http_body
      end
      raise error
    end
  end
end
