# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Opentelemetry instrumentation

---

## [7.1.0] - 2025-09-22

### Added

- `Amqpx.Helper.consumers_supervisor_configuration/1` now accepts an optional `concurrency_level` key in consumers configuration that can be used to spawn multiple competing consumers on the same queue.

  ```elixir
  config :myapp,
  consumers: [
    %{
      handler_module: Myapp.Consumer,
      prefetch_count: 100,
      backoff: 10_000,
      concurrency_level: 2  # <-- New!
    }
  ]

  # It's equivalent to
  config :myapp,
  consumers: [
    %{
      handler_module: Myapp.Consumer,
      prefetch_count: 100,
      backoff: 10_000
    },
    %{
      handler_module: Myapp.Consumer,
      prefetch_count: 100,
      backoff: 10_000
    }
  ]
  ```

---

## [7.0.0] - 2025-01-24

### Changed

- When you pass an `x-queue-type` to `Amqpx.Helper.declare/2` now it will be used also for the dead letter queue

  This is a breaking change: if you are already using `Helper.declare` with an `x-queue-type` that is not the default type this will try to change the dead letter queue type.

  In this case you can either remove the dead letter queue and recreate it with the correct type, or you can migrate to a new dead letter queue with a different name and remove the old one when it's fully drained:

  ```elixir
  queue_spec = %{
    queue: "test_1",
    opts: [
      durable: true,
      arguments: [
        {"x-queue-type", :longstr, "quorum"},
        {"x-dead-letter-exchange", :longstr, "test_dle"},
        {"x-dead-letter-routing-key", :longstr, "test_rk"}
      ]
    ],
    exchanges: [
      %{name: "test_exchange", type: :topic, routing_keys: ["test_rk"], opts: [durable: true]},
    ]
  }

  # As an example we'll take the following `Amqpx.Helper.declare`
  # that creates a queue called `test_1` and a corresponding `test_1_errored`
  :ok = Amqpx.Helper.declare(chan, queue_spec)

  # Amqpx.Helper.setup_queue/2 takes the exact same queue_spec
  # as declare/2 but it doesn't declare the dead letter queue
  :ok = Amqpx.Helper.setup_queue(chan, queue_spec)

  # Now we can create a new dead letter queue with type "quorum"
  # by using a different name, we just need to make sure
  # its routing key will match the `x-dead-letter-routing-key` argument
  :ok = Amqpx.Helper.setup_dead_lettering(chan, %{
    routing_key: "test_rk",
    queue: "test_1_dlq",
    exchange: "test_dle",
    queue_opts: [durable: true, arguments: [{"x-queue-type", :longstr, "quorum"}]]
  })

  # At this point dead-lettered messages should be delivered to both
  # `test_1_errored` and `test_1_dlq`, in this way we can migrate everything
  # to the new one and as soon as it empties we can remove the old one
  ```

- The `original_routing_keys` option accepted by `Amqpx.Helper.setup_dead_lettering/2` must be a `[String.t()]`, if you are passing a `[[String.t()]]` to this function you have to pipe trough `List.flatten` now

### Added

- `Amqpx.Helper.setup_dead_lettering/2` now accepts a `queue_opts` key which will be used as third argument for `Amqpx.Queue.declare/3`

---

## [6.1.3] - 2025-01-23

### Fixed

- Elixir applications are no more forced to start `Amqpx.SignalHandler` manually

### Updated

- rabbit libraries to `amqp_client` and `rabbit_common` to 4.0

- Increased minimum supported elixir version to 1.16, otp 26

This is due to elixir rabbit not supporting the older versions of the libraries

---

## [6.1.2] - 2024-12-02

### Added

- ([#211](https://github.com/primait/amqpx/pull/211)) Allow to skip the DLK check for a 
  list of dead letter queues

---

## [6.1.1] - 2024-12-02

### Added

- ([#208](https://github.com/primait/amqpx/pull/208)) Reverse the logic for draining.
  Now the application signal handler call the Amqpx.SignalHandler to trigger the drain.

---

## [6.1.0] - 2024-11-29

### Added

- ([#208](https://github.com/primait/amqpx/pull/208)) Introduces the possibility
  of configuring a signal handler which can be used for graceful termination.
  When the SIGTERM arrive, we cancel all the consumer to stop taking new
  messages.

### Changed

- Minimum supported Elixir version is now 1.14

---

## [6.0.4] - 2024-09-02

### Added

- ([#199](https://github.com/primait/amqpx/pull/199)) `host` param will be
  resolved to a list of `ip`s, if it's a hostname, and the connection will be
  established to the first available one.

---

## [6.0.3] - 2024-05-28

### Fixed

- ([#190](https://github.com/primait/amqpx/pull/191)) Suppress noisy error logs
  at GenServer shutdown.
- ([#191](https://github.com/primait/amqpx/pull/190)) GenServer now trap exit
  and gracefully shutdown instead of force the process to exit.

---

## [6.0.2] - 2023-03-24

### Changed

- ([#140](https://github.com/primait/amqpx/pull/140)) Avoid logging normal exits

---

## [6.0.1] - 2023-03-17

### Added

- ([#138](https://github.com/primait/amqpx/pull/138)) Add proper shutdown
  handling to Amqpx generic producers and consumers
- ([#121](https://github.com/primait/amqpx/pull/121)) Add retry mechanism for
  publish

### Changed

- ([#119](https://github.com/primait/amqpx/pull/119)) Print stacktrace when
  rescuing exceptions
- ([#131](https://github.com/primait/amqpx/pull/131)) Refactor declare function
  in helper module

---

## [6.0.0] - 2022-12-21

### Added

- ([#129](https://github.com/primait/amqpx/pull/)) Default binding for DLX
  queues instead of wildcard


[Unreleased]: https://github.com/primait/amqpx/compare/7.1.0...HEAD
[7.1.0]: https://github.com/primait/amqpx/compare/7.0.0...7.1.0
[7.0.0]: https://github.com/primait/amqpx/compare/6.1.3...7.0.0
[6.1.3]: https://github.com/primait/amqpx/compare/6.1.2...6.1.3
[6.1.2]: https://github.com/primait/amqpx/compare/6.1.1...6.1.2
[6.1.1]: https://github.com/primait/amqpx/compare/6.1.0...6.1.1
[6.1.0]: https://github.com/primait/amqpx/compare/6.0.4...6.1.0
[6.0.4]: https://github.com/primait/amqpx/compare/6.0.3...6.0.4
[6.0.3]: https://github.com/primait/amqpx/compare/6.0.2...6.0.3
[6.0.2]: https://github.com/primait/amqpx/compare/6.0.1...6.0.2
[6.0.1]: https://github.com/primait/amqpx/compare/6.0.0...6.0.1
[6.0.0]: https://github.com/primait/amqpx/releases/tag/6.0.0
