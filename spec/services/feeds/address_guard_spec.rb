# frozen_string_literal: true

require "rails_helper"

RSpec.describe Feeds::AddressGuard do
  def resolve(*addresses)
    described_class.new(resolver: ->(_hostname) { addresses }).resolve!("feeds.example")
  end

  it "returns the first address when every DNS answer is globally reachable" do
    expect(resolve("93.184.216.34", "2606:4700:4700::1111")).to eq("93.184.216.34")
  end

  it "rejects non-global IPv4 destinations" do
    addresses = %w[
      0.0.0.0
      10.0.0.1
      100.64.0.1
      127.0.0.1
      169.254.169.254
      172.16.0.1
      192.0.0.1
      192.0.2.1
      192.88.99.1
      192.168.0.1
      198.18.0.1
      198.51.100.1
      203.0.113.1
      224.0.0.1
      240.0.0.1
      255.255.255.255
    ]

    addresses.each do |address|
      expect { resolve(address) }
        .to raise_error(described_class::UnsafeAddress), "expected #{address} to be rejected"
    end
  end

  it "rejects non-global IPv6 destinations" do
    addresses = %w[
      ::
      ::1
      ::ffff:127.0.0.1
      64:ff9b::192.168.0.1
      64:ff9b:1::1
      100::1
      100:0:0:1::1
      2001::1
      2001:2::1
      2001:10::1
      2001:db8::1
      2002::1
      3fff::1
      5f00::1
      fc00::1
      fe80::1
      ff02::1
    ]

    addresses.each do |address|
      expect { resolve(address) }
        .to raise_error(described_class::UnsafeAddress), "expected #{address} to be rejected"
    end
  end

  it "rejects a hostname if any DNS answer is non-public" do
    expect { resolve("93.184.216.34", "10.0.0.1") }
      .to raise_error(described_class::UnsafeAddress)
  end

  it "rejects missing and malformed DNS answers" do
    expect { resolve }.to raise_error(described_class::ResolutionError)
    expect { resolve("not-an-ip") }.to raise_error(described_class::ResolutionError)
  end
end
