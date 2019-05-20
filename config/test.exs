use Mix.Config

config :amqpx,
  consumers: [
    [
      handler_module: Amqpx.Test.Support.Consumer1,
      queue: "test",
      exchange: "amq.topic1",
      exchange_type: :topic,
      routing_keys: ["amqpx.test1"],
      queue_dead_letter: "test1_errored"
    ],
    [
      handler_module: Amqpx.Test.Support.Consumer2,
      queue: "test",
      exchange: "amq.topic2",
      exchange_type: :topic,
      routing_keys: ["amqpx.test2"],
      queue_dead_letter: "test2_errored"
    ]
  ]

config :amqpx, :producer,
  exchanges: [
    [
      name: "amq.topic1",
      type: :topic
    ],
    [
      name: "amq.topic2",
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
