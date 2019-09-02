Amqpx
=========

## About
A simple AMQP library based on [official elixir amqp client](https://hex.pm/packages/amqp)
Written to prevent duplicated and boilerplate code to handle all the lifecycle of the amqp connection. Write your publisher or consumer and forget about the rest!

## Installation

```elixir
def deps do
  [
    {:amqpx, "~> 3.0"}
  ]
end
```

From 3.0.0 AMQPX is no longer an application. This is so the client can choose in which environment or configuration to have consumers up and running.
You would then need to start your consumers and producer in the client's supervision tree, instead of adding AMQPX to the `extra_application` list as it was in the past:

```elixir
Enum.each(Application.get_env(:amqpx, :consumers), & Amqpx.Consumer.start_link(&1))
Amqpx.Producer.start_link(Application.get_env(:amqpx, :producer))

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
      queue_dead_letter: "test_errored",
      queue_dead_letter_exchange: "test_errored_exchange",
      handler_args: [
          key: "value",
          or: %{}
      ]
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
  publisher_confirms: true,
  publish_timeout: 2_000, #default is 1_000
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
