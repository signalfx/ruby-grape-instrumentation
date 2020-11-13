# Grape::Instrumentation

This gem provides OpenTracing instrumentation for Grape by hooking into ActiveSupport notifications.

The following events are instrumented:
- `endpoint_run.grape`
- `endpoint_run_filters.grape`
- `endpoint_run_validators.grape`
- `endpoint_render.grape`
- `format_response.grape`

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'grape-instrumentation'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install grape-instrumentation

## Usage

```ruby
require `grape/instrumentation`

Grape::Instrumentation.instrument(tracer: OpenTracing.global_tracer, parent_span: ->(payload) { some_parent_span })
```

`Grape::Instrumentation.instrument` optionally takes these arguments:
- `tracer`: OpenTracing tracer to be used for this instrumentation.
  - Default: `OpenTracing.global_tracer`
- `parent_span`: this can be a parent span, or a block that takes an argument,
  `payload`, which is the notification event payload, and returns the that
  should be used as the parent span.
  - Example: `->(payload) { ::Grape::Instrumentation.tracer.active_span }`
  - Default: `nil`

The tracer is made available through `Grape::Instrumentation.tracer`.

This instrumentation can be used in conjunction with [`Rack::Tracer`](https://github.com/signalfx/ruby-rack-tracer) to group spans by request.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/signalfx/ruby-grape-instrumentation.
