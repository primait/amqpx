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
      queue_options: [
        durable: true,
        arguments: [
          {"x-dead-letter-routing-key", :longstr, "test1_errored"},
          {"x-dead-letter-exchange", :longstr, "test1_errored_exchange"}
        ]
      ]
    ],
    [
      handler_module: Amqpx.Test.Support.Consumer2,
      queue: "test2",
      exchange: "topic2",
      exchange_type: :topic,
      routing_keys: ["amqpx.test2"],
      queue_options: [
        durable: true,
        arguments: [
          {"x-dead-letter-routing-key", :longstr, "test2_errored"},
          {"x-dead-letter-exchange", :longstr, "test2_errored_exchange"}
        ]
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
