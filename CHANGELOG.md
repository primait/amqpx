# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

---

## [6.0.2] - 2023-03-24

### Changed

- ([#140](https://github.com/primait/amqpx/pull/140)) Avoid logging normal exits

---

## [6.0.1] - 2023-03-17

### Added

- ([#138](https://github.com/primait/amqpx/pull/138)) Add proper shutdown handling to Amqpx generic producers and consumers
- ([#121](https://github.com/primait/amqpx/pull/121)) Add retry mechanism for publish

### Changed

- ([#119](https://github.com/primait/amqpx/pull/119)) Print stacktrace when rescuing exceptions
- ([#131](https://github.com/primait/amqpx/pull/131)) Refactor declare function in helper module

---

## [6.0.0] - 2022-12-21

### Added

- ([#129](https://github.com/primait/amqpx/pull/)) Default binding for DLX queues instead of wildcard

[Unreleased]: https://github.com/primait/amqpx/compare/6.0.2...HEAD
[6.0.2]: https://github.com/primait/amqpx/compare/6.0.1...6.0.2
[6.0.1]: https://github.com/primait/amqpx/compare/6.0.0...6.0.1
[6.0.0]: https://github.com/primait/amqpx/releases/tag/6.0.0
