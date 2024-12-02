# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/primait/amqpx/compare/6.1.1...HEAD
[6.1.1]: https://github.com/primait/amqpx/compare/6.1.0...6.1.1
[6.1.0]: https://github.com/primait/amqpx/compare/6.0.4...6.1.0
[6.0.4]: https://github.com/primait/amqpx/compare/6.0.3...6.0.4
[6.0.3]: https://github.com/primait/amqpx/compare/6.0.2...6.0.3
[6.0.2]: https://github.com/primait/amqpx/compare/6.0.1...6.0.2
[6.0.1]: https://github.com/primait/amqpx/compare/6.0.0...6.0.1
[6.0.0]: https://github.com/primait/amqpx/releases/tag/6.0.0
