# frozen_string_literal: true

require "ipaddr"
require "socket"

module Feeds
  class AddressGuard
    class Error < StandardError; end
    class ResolutionError < Error; end
    class UnsafeAddress < Error; end

    module SystemResolver
      module_function

      def call(hostname)
        Addrinfo
          .getaddrinfo(hostname, nil, Socket::AF_UNSPEC, Socket::SOCK_STREAM)
          .select(&:ip?)
          .map(&:ip_address)
          .uniq
      end
    end

    IPV4_NON_GLOBAL_RANGES = %w[
      0.0.0.0/8
      10.0.0.0/8
      100.64.0.0/10
      127.0.0.0/8
      169.254.0.0/16
      172.16.0.0/12
      192.0.0.0/24
      192.0.2.0/24
      192.88.99.0/24
      192.168.0.0/16
      198.18.0.0/15
      198.51.100.0/24
      203.0.113.0/24
      224.0.0.0/3
    ].map { IPAddr.new(_1).freeze }.freeze

    IPV6_GLOBAL_UNICAST_RANGE = IPAddr.new("2000::/3").freeze
    IPV6_NAT64_RANGE = IPAddr.new("64:ff9b::/96").freeze
    IPV6_NON_GLOBAL_RANGES = %w[
      2001::/32
      2001:2::/48
      2001:10::/28
      2001:db8::/32
      2002::/16
      3fff::/20
    ].map { IPAddr.new(_1).freeze }.freeze

    def initialize(resolver: SystemResolver)
      @resolver = resolver
    end

    def resolve!(hostname)
      addresses = Array(@resolver.call(hostname)).map { parse_address(_1) }.uniq
      raise ResolutionError, "Feed host could not be resolved" if addresses.empty?

      unless addresses.all? { globally_reachable?(_1) }
        raise UnsafeAddress, "Feed host resolves to a non-public IP address"
      end

      addresses.first.to_s
    rescue SocketError, SystemCallError, IPAddr::InvalidAddressError, TypeError
      raise ResolutionError, "Feed host could not be resolved"
    end

    private

    def parse_address(address)
      address.is_a?(IPAddr) ? address : IPAddr.new(address.to_s)
    end

    def globally_reachable?(address)
      return ipv4_globally_reachable?(address) if address.ipv4?
      return nat64_globally_reachable?(address) if IPV6_NAT64_RANGE.include?(address)

      IPV6_GLOBAL_UNICAST_RANGE.include?(address) &&
        IPV6_NON_GLOBAL_RANGES.none? { _1.include?(address) }
    end

    def ipv4_globally_reachable?(address)
      IPV4_NON_GLOBAL_RANGES.none? { _1.include?(address) }
    end

    def nat64_globally_reachable?(address)
      embedded_ipv4 = IPAddr.new(address.to_i & 0xffffffff, Socket::AF_INET)
      ipv4_globally_reachable?(embedded_ipv4)
    end
  end
end
