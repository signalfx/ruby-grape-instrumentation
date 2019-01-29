require 'grape/instrumentation/version'

require 'grape'
require 'opentracing'
require 'rack/tracer'
require 'pp'

module Grape
  module Instrumentation
    class Error < StandardError; end

    NOTIFICATIONS = %w[
      endpoint_run.grape
      endpoint_render.grape
      endpoint_run_filters.grape
      endpoint_run_validators.grape
      format_response.grape
    ].freeze

    attr_accessor :tracer

    class << self
      COMMON_TAGS = {
        'component' => 'ruby-grape',
      }.freeze

      def instrument(tracer: OpenTracing.global_tracer)
        @tracer = tracer
        @subscriber_mutex = Mutex.new
        @subscribers = []
        
        @subscriber_mutex.synchronize do
          add_subscribers
        end
      end

      def uninstrument
        @subscriber_mutex.synchronize do
          clear_subscribers
        end
      end

      def add_subscribers
        clear_subscribers unless @subscribers.empty?

        NOTIFICATIONS.each do |notification|
          subscriber = ::ActiveSupport::Notifications.subscribe(notification) do |*args|
            trace_event(::ActiveSupport::Notifications::Event.new(*args))
          end

          @subscribers.append(subscriber)
        end
      end

      def clear_subscribers
        @subscribers.each do |s|
          ::ActiveSupport::Notifications.unsubscribe(s)
        end

        @subscribers.clear
      end

      def trace_event(event)
        tags = {
          'request.id' => event.transaction_id
        }.merge(COMMON_TAGS)

        span = @tracer.start_span("#{event.name}", tags: tags, start_time: event.time, finish_on_close: false)

        # tag relevant information from the event payload
        tag_endpoint(span, event.payload[:endpoint]) if event.payload[:endpoint]
        tag_error(span, event.payload[:exception_object]) if event.payload[:exception] && event.payload[:exception_object]

        span.finish(end_time: event.end)
      end

      def tag_endpoint(span, endpoint)
        # ideally there would be a member of endpoint that has the request path.
        # currently, it seems like only the Rack env contains it
        env = endpoint.env
        span.set_tag('http.url', env['PATH_INFO']) if env['PATH_INFO']

        span.set_tag('http.method', endpoint.options[:method].first)
      end

      def tag_error(span, exception_object)
        span.set_tag('error', true)
        span.log_kv(key: 'error.object', value: exception_object)
        span.log_kv(key: 'message', value: exception_object.message)
      end
    end
  end
end
