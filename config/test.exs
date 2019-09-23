use Mix.Config

config :logger, :console,
  format: "[$level] $message $metadata\n",
  metadata: [:error, :error_message]

config :logger, level: :warning

config :amqpx,
  consumers: [
    [
      handler_module: Amqpx.Test.Support.Consumer1,
      queue: "test1",
      exchange: "topic1",
      exchange_type: :topic,
      routing_keys: ["amqpx.test1"],
      queue_dead_letter: "test1_errored",
      queue_dead_letter_exchange: "test1_errored_exchange_aa",
      queue_options: [
        durable: true
      ]
    ],
    [
      handler_module: Amqpx.Test.Support.Consumer2,
      queue: "test2",
      exchange: "topic2",
      exchange_type: :topic,
      routing_keys: ["amqpx.test2"],
      queue_dead_letter: "test2_errored",
      queue_dead_letter_exchange: nil,
      queue_options: [
        durable: true
      ]
    ]
  ]

config :amqpx, :producer,
  publisher_confirms: false,
  exchanges: [
    [
      name: "topic1",
      type: :topic
    ],
    [
      name: "topic2",
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
