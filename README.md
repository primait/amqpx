Amqpx
=========

## About
A simple AMQP library based on [official elixir amqp client](https://hex.pm/packages/amqp)
Written to prevent duplicated and boilerplate code to handle all the lifecycle of the amqp connection. Write your publisher or consumer and forget about the rest!

## Installation

```elixir
def deps do
  [
    {:amqpx, "~> 5.0"}
  ]
end
```

From 3.0.0 AMQPX is no longer an application. This is so the client can choose in which environment or configuration to have consumers up and running.
You would then need to start your consumers and producer in the client's supervision tree, instead of adding AMQPX to the `extra_application` list as it was in the past.

To start all consumers:
```elixir
Enum.each(Application.get_env(:amqpx, :consumers), & Amqpx.Consumer.start_link(&1))
```

To start all producers:
```elixir
Amqpx.Producer.start_link(Application.get_env(:amqpx, :producer))
```

## Sample configuration

### Broker
```elixir
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

### Consumers
Default parameters:
- handler_args: []
- queue_options:
```elixir
    queue_options: [
      durable: true,
      arguments: []
    ]
```
- arguments (in queue_options): []
```elixir
config :amqpx,
  consumers: [
    [
      handler_module: Your.Handler.Module,
      queue: "test",
      exchange: "amq.topic",
      exchange_type: :topic,
      routing_keys: ["amqpx.test"],
      handler_args: [
          key: "value",
          # or something else
      ],
      queue_options: [
        durable: true,
        arguments: [
          {"x-dead-letter-routing-key", :longstr, "test_errored"},
          {"x-dead-letter-exchange", :longstr, "test_errored_exchange"}
        ]
        # available options: auto_delete, exclusive, passive, no_wait
      ]
    ]
  ]
```

### Producers
Default parameters:
- publish_timeout: 1_000
```elixir
config :amqpx, :producer,
  publisher_confirms: true,
  publish_timeout: 2_000,
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
```

### Consumer
```elixir
defmodule Consumer do
  @moduledoc nil

  @behaviour Amqpx.Consumer

  def setup(_channel, _args) do
    {:ok, %{}}
  end

  def handle_message(_payload, state) do
    {:ok, state}
  end
end
```

### Producer
```elixir
defmodule Producer do
  @moduledoc nil
  
  alias Amqpx.Producer

  @spec send_payload(map) :: :ok | :error
  def send_payload(payload) do
    Producer.publish("topic1", "amqpx.test1", Jason.encode!(payload))
  end
end
```

### Application
Setup consumers and/or producers inside your Application
```elixir
defmodule Application do
  def start(_type, _args) do
    import Supervisor.Spec
    children =
      [
        producers()
      ]
      |> Kernel.++(consumers())

    opts = [strategy: :one_for_one, name: Supervisor]
    Supervisor.start_link(children, opts)
  end

  def consumers() do
    Enum.map(
      Application.get_env(:amqpx, :consumers),
      &Supervisor.child_spec({Amqpx.Consumer, &1}, id: UUID.uuid1())
    )
  end

  def producers() do
    {Amqpx.Producer, Application.get_env(:amqpx, :producer)}
  end
end
```
