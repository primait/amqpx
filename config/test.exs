use Mix.Config

config :logger, :console,
  format: "[$level] $message $metadata\n",
  metadata: [:error, :error_message]

config :logger, level: :error

config :amqpx,
  amqp_connection: [
    username: "amqpx",
    password: "amqpx",
    host: "rabbit",
    virtual_host: "/",
    heartbeat: 30,
    connection_timeout: 10_000,
    obfuscate_password: false
  ]

config :amqpx,
  consumers: [
    %{
      handler_module: Amqpx.Test.Support.Consumer1
    },
    %{
      handler_module: Amqpx.Test.Support.Consumer2
    },
    %{
      handler_module: Amqpx.Test.Support.Consumer3,
      backoff: 10_000
    }
  ]

config :amqpx, Amqpx.Test.Support.Consumer1, %{
  queue: "test1",
  exchanges: [
    %{name: "topic1", type: :topic, routing_keys: ["amqpx.test1"], opts: [durable: true]}
  ],
  opts: [
    durable: true,
    arguments: [
      {"x-dead-letter-routing-key", :longstr, "test1_errored"},
      {"x-dead-letter-exchange", :longstr, "test1_errored_exchange"}
    ]
  ]
}

config :amqpx, Amqpx.Test.Support.Consumer2, %{
  queue: "test2",
  exchanges: [
    %{name: "topic2", type: :topic, routing_keys: ["amqpx.test2"], opts: [durable: true]}
  ],
  opts: [
    durable: true,
    arguments: [
      {"x-dead-letter-exchange", :longstr, "test2_errored_exchange"}
    ]
  ]
}

config :amqpx, Amqpx.Test.Support.Consumer3, %{
  queue: "test3",
  exchanges: [
    %{name: "topic3", type: :fanout, opts: [durable: true]}
  ]
}

config :amqpx, :producer, %{
  publish_timeout: 5_000,
  publisher_confirms: false,
  exchanges: [
    %{
      name: "test_exchange",
      type: :topic,
      opts: [durable: true]
    }
  ]
}
