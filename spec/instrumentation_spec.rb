require 'spec_helper'
require 'test_api'

RSpec.describe Grape::Instrumentation do
  include Rack::Test::Methods

  let(:tracer) { OpenTracingTestTracer.build }

  describe 'Class Methods' do
    it { is_expected.to respond_to :instrument }
    it { is_expected.to respond_to :add_subscribers }
    it { is_expected.to respond_to :trace_event }
    it { is_expected.to respond_to :tag_error }
  end

  def app
    ::Test::API
  end

  context 'instrumented API' do
    let(:path) { '/test/test' }
    let(:common_tags) { { 'component' => 'ruby-grape', 'request.id' => anything, 'http.method' => 'GET', 'http.url' => path } }

    before { described_class.instrument(tracer: tracer) }
    after { described_class.uninstrument }

    before { get path }

    it 'adds spans when processing an endpoint' do
      expect(last_response.status).to eq 200
      expect(tracer.spans.count).to eq 8
    end

    it 'adds the correct tags for endpoint_run.grape' do
      span = tracer.spans.detect { |e| e.operation_name = 'endpoint_run.grape' }

      expect(span.tags).to match common_tags
    end

    it 'adds the correct tags for endpoint_render.grape' do
      span = tracer.spans.detect { |e| e.operation_name = 'endpoint_render.grape' }

      expect(span.tags).to match common_tags
    end

    it 'adds the correct tags for endpoint_run_filters.grape' do
      span = tracer.spans.detect { |e| e.operation_name = 'endpoint_run_filters.grape' }

      expect(span.tags).to match common_tags
    end

    it 'adds the correct tags for endpoint_run_validators.grape' do
      span = tracer.spans.detect { |e| e.operation_name = 'endpoint_run_validators.grape' }

      expect(span.tags).to match common_tags
    end

    it 'adds the correct tags for format_response.grape' do
      span = tracer.spans.detect { |e| e.operation_name = 'format_response.grape' }

      expect(span.tags).to match common_tags
    end
  end
end
