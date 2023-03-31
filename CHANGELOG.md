# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

---

## [6.0.2] - 2023-03-24

### Changed

- Avoid logging normal exits ([#140](https://github.com/primait/amqpx/pull/140))

---

## [6.0.1] - 2023-03-17

### Added

- [[STAFF-31](https://prima-assicurazioni-spa.myjetbrains.com/youtrack/issue/STAFF-31)] Add proper shutdown handling to Amqpx generic producers and consumers ([#138](https://github.com/primait/amqpx/pull/138))
- Add retry mechanism for publish ([#121](https://github.com/primait/amqpx/pull/121))

### Changed

- Print stacktrace when rescuing exceptions ([#119](https://github.com/primait/amqpx/pull/119))
- [[PLATFORM-886](https://prima-assicurazioni-spa.myjetbrains.com/youtrack/issue/PLATFORM-886)]: Refactor declare function in helper module ([#131](https://github.com/primait/amqpx/pull/131))

---

## [6.0.0] - 2022-12-21

### Added

- Default binding for DLX queues instead of wildcard ([#129](https://github.com/primait/amqpx/pull/))

[Unreleased]: https://github.com/primait/amqpx/compare/6.0.2...HEAD
[6.0.2]: https://github.com/primait/amqpx/compare/6.0.1...6.0.2
[6.0.1]: https://github.com/primait/amqpx/compare/6.0.0...6.0.1
[6.0.0]: https://github.com/primait/amqpx/releases/tag/6.0.0
