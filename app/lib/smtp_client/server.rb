# frozen_string_literal: true

module SMTPClient
  class Server

    attr_reader :hostname
    attr_reader :port
    attr_accessor :ssl_mode
    attr_accessor :auth_username
    attr_accessor :auth_password
    attr_accessor :auth_type
    attr_accessor :helo_hostname

    def initialize(hostname, port: 25, ssl_mode: SSLModes::AUTO,
                   auth_username: nil, auth_password: nil,
                   auth_type: "plain", helo_hostname: nil)
      @hostname = hostname
      @port = port
      @ssl_mode = ssl_mode
      @auth_username = auth_username
      @auth_password = auth_password
      @auth_type = auth_type.presence || "plain"
      @helo_hostname = helo_hostname
    end

    # Return all IP addresses for this server by resolving its hostname.
    # IPv6 addresses will be returned first.
    #
    # @return [Array<SMTPClient::Endpoint>]
    def endpoints
      ips = []

      DNSResolver.local.aaaa(@hostname).each do |ip|
        ips << Endpoint.new(self, ip)
      end

      DNSResolver.local.a(@hostname).each do |ip|
        ips << Endpoint.new(self, ip)
      end

      ips
    end

  end
end
