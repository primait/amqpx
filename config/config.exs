# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# third-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :amqpx, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:amqpx, :key)
#
# You can also configure a third-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#

config :amqpx,
  consumers: [
    [
      handler_module: Amqpx.Test.Support.Consumer1,
      queue: "test",
      exchange: "amq.topic",
      exchange_type: :topic,
      routing_keys: ["amqpx.test"],
      queue_dead_letter: "test_errored",
      queue_dead_letter_exchange: "test_errored_exchange",
      handler_args: [
      ]
    ],
    [
      handler_module: Amqpx.Test.Support.Consumer2,
      queue: "blabla",
      exchange: "amq.topic",
      exchange_type: :topic,
      routing_keys: ["amqpx.bla"],
      queue_dead_letter: "test_bla"
    ]
  ]

config :amqpx, :producer,
  publisher_confirms: false,
  exchanges: [
    [
      name: "amq.topic",
      type: :topic
    ]
  ]

config :amqpx, :broker,
  connection_params: [
    username: "amqpx",
    password: "amqpx",
    host: "rabbit",
    virtual_host: "amqpx",
    heartbeat: 30,
    connection_timeout: 10_000
  ]

import_config "#{Mix.env()}.exs"
