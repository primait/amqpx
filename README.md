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

To start all consumers and producer inside your application, using the library helper function:
```elixir
defmodule Application do
  alias Amqpx.Helper
  import Supervisor.Spec, warn: false

  def start(_type, _args) do

    children =
      Enum.concat(
        [
          Helper.producer_supervisor_configuration(
            Application.get_env(:myapp, :myproducer),
            Application.get_env(:myapp, :amqp_connection)
          )
        ],
        Helper.consumers_supervisor_configuration(
          Application.get_env(:myapp, :consumers),
          Application.get_env(:myapp, :amqp_connection)
        )
      )
    opts = [strategy: :one_for_one, name: Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Start consumers and producer manually:
```elixir
{_, producer} =
  Helper.producer_supervisor_configuration(
    Application.get_env(:myapp, :producer),
    Application.get_env(:myapp, :amqp_connection)
  )

Amqpx.Producer.start_link(producer)

Enum.each(
  Application.get_env(:myapp, :consumers),
  &Amqpx.Consumer.start_link(
    Map.put(&1, :connection_params, Application.get_env(:myapp, :amqp_connection))
  )
)
```

## Sample configuration

### Connection
```elixir
config :myapp, :amqp_connection,
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
- prefetch_count: 50
- backoff: 5_000 (connection retry)

N.B: headers exchange declaration not supported by library helpers functions

```elixir
config :myapp,
  consumers: [
    %{
      handler_module: Your.Handler.Module,
      prefetch_count: 100,
      backoff: 10_00
    }

config :myapp, Your.Handler.Module, %{
    name: "my_queue",
    exchanges: [
      %{name: "amq.topic", type: :topic, routing_keys: ["my.routing_key1","my.routing_key2"], opts: [durable: true]},
      %{name: "my_exchange", type: :direct, routing_keys: ["my_queue"]},
      %{name: "my_exchange_fanout", type: :fanout, opts: [durable: true]}
    ],
    opts: [
      durable: true,
      arguments: [
        {"x-dead-letter-routing-key", :longstr, "my_queue_errored"},
        {"x-dead-letter-exchange", :longstr, ""}
      ]
    ]
  }      
```

### Producers
Default parameters:
- publish_timeout: 1_000
- backoff: 5_000 (connection retry)


: 
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
