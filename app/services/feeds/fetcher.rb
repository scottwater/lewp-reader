# frozen_string_literal: true

require "net/http"

module Feeds
  class Fetcher
    MAX_REDIRECTS = 5
    MAX_BODY_BYTES = 5 * 1024 * 1024
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15
    WRITE_TIMEOUT = 5
    USER_AGENT = "LewpReader/1.0 (RSS/Atom feed fetcher)"
    REDIRECT_CODES = [ 301, 302, 303, 307, 308 ].freeze

    class Error < StandardError; end
    class InvalidUrl < Error; end
    class UnsafeAddress < InvalidUrl; end
    class TooManyRedirects < Error; end
    class ResponseTooLarge < Error; end
    class HttpError < Error; end

    Result = Data.define(:body, :etag, :last_modified, :not_modified) do
      def not_modified?
        not_modified
      end
    end

    Response = Data.define(:code, :body, :etag, :last_modified, :location)

    def initialize(feed, http: Net::HTTP, resolver: AddressGuard::SystemResolver)
      @feed = feed
      @http = http
      @address_guard = AddressGuard.new(resolver: resolver)
    end

    def call
      uri = parse_uri(@feed.url)
      redirects = 0

      loop do
        response = request(uri)

        if response.code == 304
          return Result.new(
            body: nil,
            etag: response.etag || @feed.etag,
            last_modified: response.last_modified || @feed.last_modified,
            not_modified: true
          )
        end

        if REDIRECT_CODES.include?(response.code)
          raise TooManyRedirects, "Feed redirected more than #{MAX_REDIRECTS} times" if redirects >= MAX_REDIRECTS

          uri = redirect_uri(uri, response.location)
          redirects += 1
          next
        end

        unless response.code.between?(200, 299)
          raise HttpError, "Feed request failed with HTTP #{response.code}"
        end

        return Result.new(
          body: response.body,
          etag: response.etag,
          last_modified: response.last_modified,
          not_modified: false
        )
      end
    end

    private

    def parse_uri(value)
      uri = URI.parse(value)
      valid = uri.is_a?(URI::HTTP) && uri.host.present? && %w[http https].include?(uri.scheme)
      raise InvalidUrl, "Feed URL must use HTTP or HTTPS" unless valid

      uri
    rescue URI::InvalidURIError, TypeError
      raise InvalidUrl, "Feed URL must use HTTP or HTTPS"
    end

    def redirect_uri(current_uri, location)
      raise InvalidUrl, "Feed redirect did not include a valid location" if location.blank?

      parse_uri(URI.join(current_uri.to_s, location).to_s)
    rescue URI::InvalidURIError
      raise InvalidUrl, "Feed redirect did not include a valid location"
    end

    def request(uri)
      captured = nil
      ipaddr = resolve_address(uri.hostname)

      @http.start(
        uri.hostname,
        uri.port,
        nil,
        nil,
        nil,
        nil,
        use_ssl: uri.scheme == "https",
        ipaddr: ipaddr,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT,
        write_timeout: WRITE_TIMEOUT
      ) do |connection|
        connection.request(build_request(uri)) do |response|
          captured = build_response(response)
        end
      end

      captured
    end

    def resolve_address(hostname)
      @address_guard.resolve!(hostname)
    rescue AddressGuard::UnsafeAddress => error
      raise UnsafeAddress, error.message
    rescue AddressGuard::ResolutionError => error
      raise InvalidUrl, error.message
    end

    def build_request(uri)
      Net::HTTP::Get.new(uri).tap do |request|
        request["User-Agent"] = USER_AGENT
        request["Accept"] = "application/atom+xml, application/rss+xml, application/xml, text/xml;q=0.9, */*;q=0.1"
        request["If-None-Match"] = @feed.etag if @feed.etag.present?
        request["If-Modified-Since"] = @feed.last_modified if @feed.last_modified.present?
      end
    end

    def build_response(response)
      code = response.code.to_i
      body = code.between?(200, 299) ? read_body(response) : nil

      Response.new(
        code: code,
        body: body,
        etag: response["etag"].presence,
        last_modified: response["last-modified"].presence,
        location: response["location"].presence
      )
    end

    def read_body(response)
      content_length = Integer(response["content-length"], exception: false)
      raise ResponseTooLarge, "Feed response exceeds #{MAX_BODY_BYTES} bytes" if content_length&.>(MAX_BODY_BYTES)

      body = String.new(encoding: Encoding::BINARY)
      response.read_body do |chunk|
        body << chunk.b
        raise ResponseTooLarge, "Feed response exceeds #{MAX_BODY_BYTES} bytes" if body.bytesize > MAX_BODY_BYTES
      end
      body
    end
  end
end
