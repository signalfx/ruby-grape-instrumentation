require 'spec_helper'
require 'test_api'

RSpec.describe Grape::Instrumentation do
  include Rack::Test::Methods

  let(:tracer) { OpenTracingTestTracer.build }

  describe 'Class Methods' do
    it { is_expected.to respond_to :instrument }
    it { is_expected.to respond_to :trace_event }
    it { is_expected.to respond_to :tag_error }
  end

  def app
    ::Test::API
  end

  context 'when instrumenting an API' do
    let(:path) { '/test/test' }
    let(:common_tags) do
      { 'component' => 'ruby-grape',
        'request.id' => anything,
        'http.method' => 'GET',
        'http.url' => path }
    end

    context 'when getting an endpoint' do
      before do
        described_class.instrument(tracer: tracer)
        get path
      end

      after { described_class.uninstrument }

      it 'adds spans when processing an endpoint' do
        expect(last_response.status).to eq 200
        expect(tracer.spans.count).not_to be 0
      end

      it 'adds the correct tags for endpoint_run.grape' do
        span = tracer.spans.detect { |e| e.operation_name == 'endpoint_run.grape' }

        expect(span.tags).to match common_tags
      end

      it 'adds the correct tags for endpoint_render.grape' do
        span = tracer.spans.detect { |e| e.operation_name == 'endpoint_render.grape' }

        expect(span.tags).to match common_tags
      end

      it 'adds the correct tags for endpoint_run_filters.grape' do
        span = tracer.spans.detect { |e| e.operation_name == 'endpoint_run_filters.grape' }

        expect(span.tags).to match common_tags
      end

      it 'adds the correct tags for endpoint_run_validators.grape' do
        span = tracer.spans.detect { |e| e.operation_name == 'endpoint_run_validators.grape' }

        expect(span.tags).to match common_tags
      end

      it 'adds the correct tags for format_response.grape' do
        span = tracer.spans.detect { |e| e.operation_name == 'format_response.grape' }

        format_response_tags = { 'component' => 'ruby-grape', 'request.id' => anything }
        expect(span.tags).to match format_response_tags
      end
    end

    context 'when getting an endpoint with parent span' do
      let(:span) { tracer.start_span('test_span') }

      before { described_class.instrument(tracer: tracer, parent_span: span) }

      after { described_class.uninstrument }

      it 'adds the correct parent id for each span' do
        get path

        span_id = span.context.span_id

        tracer.spans.each do |s|
          expect(s.context.parent_id).to eq span_id unless s.operation_name == span.operation_name
        end
      end
    end

    context 'when getting an endpoing with a parent span block' do
      let(:span) { tracer.start_span('test_span') }
      let(:parent_span) { ->(_) { span } }

      before { described_class.instrument(tracer: tracer, parent_span: parent_span) }

      after { described_class.uninstrument }

      it 'adds the correct parent id for each span' do
        get path

        span_id = span.context.span_id

        tracer.spans.each do |s|
          expect(s.context.parent_id).to eq span_id unless s.operation_name == span.operation_name
        end
      end
    end

    context 'when event with exception is received' do
      before { described_class.instrument(tracer: tracer) }

      after { described_class.uninstrument }
      it 'it correctly records the error on span' do
        error = nil
        begin
          raise StandardError, "test error"
        rescue => err 
          error = err
        end
        event = ActiveSupport::Notifications::Event.new(
          "test-event", "", "", "1", {
            :exception => ["StandardError", "Invalid value"],
            :exception_object => err
          }
        )
        described_class.trace_event event
        span = tracer.spans.first

        err_tags = {
          'component' => 'ruby-grape',
          'error' => true,
          'request.id' => '1',
          'sfx.error.kind' => 'StandardError',
          'sfx.error.message' => 'test error',
          'sfx.error.stack' => error.backtrace.join('\n')
        }
        expect(span.tags).to match err_tags
      end
    end
  end
end
