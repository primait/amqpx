Amqpx
=========

## About
A simple AMQP library based on [official elixir amqp client](https://hex.pm/packages/amqp)
Written to prevent duplicated and boilerplate code to handle all the lifecycle of the amqp connection. Write your publisher or consumer and forget about the rest!

## Installation

```elixir
def deps do
  [
    {:amqpx, "~> 2.0"}
  ]
end
```

Add amqpx as extra_applications:

```elixir
def application do
  [
    extra_applications: [:amqpx]
  ]
end
```

## Sample configuration

```elixir
config :amqpx,
  consumers: [
    [
      handler_module: Amqpx.ConsumerModule1,
      queue: "test",
      exchange: "amq.topic",
      exchange_type: :topic,
      routing_keys: ["amqpx.test"],
      queue_dead_letter: "test_errored"
    ],
    [
      handler_module: Amqpx.ConsumerModule2,
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
```
