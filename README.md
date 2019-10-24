Amqpx
=========

## About
A simple Amqpx library based on [official elixir amqp client](https://hex.pm/packages/amqp)
Written to prevent duplicated and boilerplate code to handle all the lifecycle of the amqp connection. Write your publisher or consumer and forget about the rest!

## Installation

```elixir
def deps do
  [
    {:amqpx, "~> 5.1"}
  ]
end
```

From 3.0.0 Amqpx is no longer an application. This is so the client can choose in which environment or configuration to have consumers up and running.
You would then need to start your consumers and producer in the client's supervision tree, instead of adding Amqpx to the `extra_application` list as it was in the past.

To start all consumers and producer inside your application, using the library helper function:
```elixir
defmodule Application do
  alias Amqpx.Helper
  import Supervisor.Spec, warn: false

  def start(_type, _args) do

    children =
      Enum.concat(
        [
          Helper.manager_supervisor_configuration(
            Application.get_env(:myapp, :amqp_connection)
          ),
          Helper.producer_supervisor_configuration(
            Application.get_env(:myapp, :producer)
          )
        ],
        Helper.consumers_supervisor_configuration(
          Application.get_env(:myapp, :consumers)
        )
      )
    opts = [strategy: :one_for_one, name: Supervisor, max_restarts: 5] # set this accordingly with your consumers count, ex: max_restarts: n_consumer + 5 
    Supervisor.start_link(children, opts)
  end
end
```

Start consumers and producer manually:
```elixir
Amqpx.ConnectionManager.start_link(%{connection_params: Application.get_env(:myapp, :amqp_connection)})

Amqpx.Producer.start_link(Application.get_env(:myapp, :producer))

Enum.each(Application.get_env(:myapp, :consumers), &Amqpx.Consumer.start_link(&1))
```

## Sample configuration

### Connection
```elixir
config :myapp,
  amqp_connection: [
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

WARNING: headers exchange binding not supported by library helpers functions

```elixir
config :myapp,
  consumers: [
    %{
      handler_module: Your.Handler.Module,
      prefetch_count: 100,
      backoff: 10_000
    }

config :myapp, Your.Handler.Module, %{
    queue: "my_queue",
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
- exchanges: []

You can also declare exchanges from the producer module, simply specify them in the configuration. There is an example below.
 
```elixir
config :myapp, :producer, %{
  publisher_confirms: false,
  publish_timeout: 0.
  exchanges: [
    %{name: "my_exchange", type: :direct, opts: [durable: true]}
  ]
}
```
## Usage example

### Consumer
```elixir
defmodule Myapp.Consumer do
  @moduledoc nil
  @behaviour Amqpx.Gen.Consumer

  alias Amqpx.Basic
  alias Amqpx.Helper

  @config Application.get_env(:amqpx, __MODULE__)
  @queue Application.get_env(:amqpx, __MODULE__)[:queue]

  def setup(channel) do
    # here you can declare your queues and exchanges
    Helper.declare(channel, @config)
    Basic.consume(channel, @queue) # Don't forget to start consuming here!

    {:ok, %{}}
  end

  def handle_message(payload, meta, state) do
    IO.inspect("payload: #{inspect(payload)}, metadata: #{meta}")
    {:ok, state}
  end
end
```

### Producer
```elixir
defmodule Myapp.Producer do
  @moduledoc nil

  alias Amqpx.Gen.Producer

  def send_payload(payload) do
    Producer.publish("myexchange", "my.routing_key", payload)
  end
end
```
