# frozen_string_literal: true

module FeedHttpHelpers
  def feed_http_response(code, body: "", headers: {})
    instance_double(Net::HTTPResponse, code: code.to_s).tap do |response|
      allow(response).to receive(:[]) { |name| headers[name.downcase] }
      allow(response).to receive(:read_body) { |&block| block.call(body) unless body.empty? }
    end
  end

  def stub_feed_http(*responses, before_response: nil)
    requests = []
    allow(Feeds::AddressGuard::SystemResolver).to receive(:call).and_return([ "93.184.216.34" ])
    connection = instance_double(Net::HTTP)
    allow(connection).to receive(:request) do |request, &block|
      requests << request
      before_response&.call
      block.call(responses.shift)
    end
    allow(Net::HTTP).to receive(:start).and_yield(connection)
    requests
  end

  def feed_fixture(name)
    Rails.root.join("spec/fixtures/feeds", name).read
  end
end

RSpec.configure do |config|
  config.include FeedHttpHelpers
end
