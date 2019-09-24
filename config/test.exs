use Mix.Config

config :logger, :console,
  format: "[$level] $message $metadata\n",
  metadata: [:error, :error_message]

config :logger, level: :warning

config :amqpx,
  connection_params: [
    username: "amqpx",
    password: "amqpx",
    host: "rabbit",
    virtual_host: "amqpx",
    heartbeat: 30,
    connection_timeout: 10_000
  ]

config :amqpx,
  consumers: [
    [
      handler_module: Amqpx.Test.Support.Consumer1
    ],
    [
      handler_module: Amqpx.Test.Support.Consumer2
    ]
  ]

config :amqpx, Amqpx.Test.Support.Consumer1, %{
  name: "test1",
  exchanges: [
    %{name: "topic1", type: "topic", routing_keys: ["amqpx.test1"], opts: [durable: true]}
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
  name: "test2",
  exchanges: [
    %{name: "topic2", type: "topic", routing_keys: ["amqpx.test2"], opts: [durable: true]}
  ],
  opts: [
    durable: true,
    arguments: [
      {"x-dead-letter-exchange", :longstr, "test2_errored_exchange"}
    ]
  ]
}

config :amqpx, :producer,
  connection_params: Application.get_env(:amqpx, :broker)[:connection_params],
  publisher_confirms: false

config :amqpx, Amqpx.Producer,
  exchanges: [
    [
      name: "topic1",
      type: :topic,
      routing_keys: []
    ],
    [
      name: "topic2",
      type: :topic,
      routing_keys: []
    ]
  ]
