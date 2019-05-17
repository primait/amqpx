Amqpx
=========

## About
A simple AMQP library based on [official elixir amqp client](https://hex.pm/packages/amqp)
Written to prevent duplicated and boilerplate code to handle all the lifecycle of the amqp connection. Write your publisher or consumer and forget about the rest!

## Installation

```elixir
def deps do
  [
    {:amqpx, "~> 1.0"}
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
      handler_module: Amqpx.Example,
      queue: "test",
      exchange: "amq.topic",
      exchange_type: :topic,
      routing_keys: ["amqpx.test"],
      queue_dead_letter: "test_errored"
    ],
    [
      handler_module: Amqpx.Example,
      queue: "blabla",
      exchange: "amq.topic",
      exchange_type: :topic,
      routing_keys: ["amqpx.bla"],
      queue_dead_letter: "test_bla"
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
