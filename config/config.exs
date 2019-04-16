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
#     config :prima_amqp, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:prima_amqp, :key)
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
#     import_config "#{Mix.env()}.exs"

config :amqpx,
  consumers: [
    [
      handler_module: Amqpx.Example,
      queue: "test",
      exchange: "amq.topic",
      exchange_type: :topic,
      routing_keys: ["amqpx.test"],
      queue_dead_letter: "test_errored"
    ]
  ]

config :amqpx,
  producers: [
    [
      exchange: "amq.topic",
      exchange_type: :topic,
      routing_key: "amqpx.test"
    ]
  ]

config :amqpx, :rabbit,
  connection_params: [
    username: "amqpx",
    password: "amqpx",
    host: "rabbit",
    virtual_host: "amqpx",
    heartbeat: 30,
    connection_timeout: 10_000
  ]
