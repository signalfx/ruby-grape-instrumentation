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

    class << self
      COMMON_TAGS = {
        'component' => 'ruby-grape',
      }.freeze

      attr_accessor :tracer

      def instrument(tracer: OpenTracing.global_tracer, parent_span: nil)
        @tracer = tracer
        @parent_span = parent_span
        @subscriber_mutex = Mutex.new
        @subscribers = []

        add_subscribers
      end

      def uninstrument
        clear_subscribers
      end

      def add_subscribers
        clear_subscribers unless @subscribers.empty?

        @subscriber_mutex.synchronize do
          NOTIFICATIONS.each do |notification|
            subscriber = ::ActiveSupport::Notifications.subscribe(notification) do |*args|
              trace_event(::ActiveSupport::Notifications::Event.new(*args))
            end

            @subscribers.append(subscriber)
          end
        end
      end

      def clear_subscribers
        @subscriber_mutex.synchronize do
          @subscribers.each do |s|
            ::ActiveSupport::Notifications.unsubscribe(s)
          end

          @subscribers.clear
        end
      end

      def trace_event(event)
        tags = {
          'request.id' => event.transaction_id
        }.merge(COMMON_TAGS)

        parent = @parent_span.respond_to?(:call) ? @parent_span.call(event.payload) : @parent_span
        span = @tracer.start_span(event.name.to_s,
                                  tags: tags,
                                  child_of: parent,
                                  start_time: event.time,
                                  finish_on_close: false)

        # tag relevant information from the event payload
        tag_endpoint(span, event.payload[:endpoint]) if event.payload[:endpoint]
        tag_error(span, event.payload[:exception_object]) if event.payload[:exception] &&
                                                             event.payload[:exception_object]

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
        span.record_exception(exception_object)
      end
    end
    private_class_method :add_subscribers
    private_class_method :clear_subscribers
  end
end
