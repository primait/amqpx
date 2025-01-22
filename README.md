# Amqpx

[![Hex pm](http://img.shields.io/hexpm/v/amqpx.svg?style=flat)](https://hex.pm/packages/amqpx)
[![Build Status](https://drone-1.prima.it/api/badges/primait/amqpx/status.svg)](https://drone-1.prima.it/primait/amqpx)

## About

A simple Amqp library based on
[official elixir amqp client](https://hex.pm/packages/amqp).

Written to prevent duplicated and boilerplate code to handle all the lifecycle
of the amqp connection. Write your publisher or consumer and forget about the
rest!

## Installation

```elixir
def deps do
  [
    {:amqpx, "~> 6.1.2"}
  ]
end
```

From 3.0.0 Amqpx is no longer an application. This is so the client can choose
in which environment or configuration to have consumers up and running. You
would then need to start your consumers and producer in the client's supervision
tree, instead of adding Amqpx to the `extra_application` list as it was in the
past.

To start all consumers and producer inside your application, using the library
helper function:

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
Amqpx.Gen.ConnectionManager.start_link(%{connection_params: Application.get_env(:myapp, :amqp_connection)})

Amqpx.Gen.Producer.start_link(Application.get_env(:myapp, :producer))

Enum.each(Application.get_env(:myapp, :consumers), &Amqpx.Gen.Consumer.start_link(&1))
```

## Sample configuration

### Connection

```elixir
config :myapp,
  amqp_connection: [
    username: "amqpx",
    password: "amqpx",
    host: "rabbit",
    port: 5_000,
    virtual_host: "amqpx",
    heartbeat: 30,
    connection_timeout: 10_000,
    obfuscate_password: false, # default is true
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
      handler_module: Myapp.Consumer,
      prefetch_count: 100,
      backoff: 10_000
    }
  ]

config :myapp, Myapp.Consumer, %{
    queue: "my_queue",
    exchanges: [
      %{name: "amq.topic", type: :topic, routing_keys: ["my.routing_key1","my.routing_key2"], opts: [durable: true]},
      %{name: "my_exchange", type: :direct, routing_keys: ["my_queue"], opts: [durable: true]},
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
- publish_retry_options: [ max_retries: 0, retry_policy: [], backoff: [ base_ms:
  10, max_ms: 10_000 ] ]

You can also declare exchanges from the producer module, simply specify them in
the configuration. There is an example below.

```elixir
config :myapp, :producer, %{
  publisher_confirms: false,
  publish_timeout: 0,
  exchanges: [
    %{name: "my_exchange", type: :direct, opts: [durable: true]}
  ]
}
```

#### Publish retry options

- `max_retries`: number of times a `publish` will be retried. A `publish` can be
  executed at most (`max_retries` + 1) times
- `retry_policy`: collection of error conditions which will cause the `publish`
  to be retried. Can be a combination of the following atoms:
  - `:on_publish_rejected` (when the broker itself rejects)
  - `:on_confirm_timeout` (when the confirm from the broker times out)
  - `:on_publish_error` (when there is an error returned at AMQP protocol level)
- `backoff`: sleep time between `publish` retries. Calculated as
  `random_between(0, min(cap, base * 2 ** attempt))`
  - `base_ms`: time in millisecond that is used as `base` term in the formula
    above
  - `max_ms`: time in millisecond that is used as `cap` term in the formula
    above

## Usage example

### Consumer

```elixir
defmodule Myapp.Consumer do
  @moduledoc nil
  @behaviour Amqpx.Gen.Consumer

  alias Amqpx.Basic
  alias Amqpx.Helper

  @config Application.get_env(:myapp, __MODULE__)
  @queue Application.get_env(:myapp, __MODULE__)[:queue]

  def setup(channel) do
    # here you can declare your queues and exchanges
    Helper.declare(channel, @config)
    Basic.consume(channel, @queue, self()) # Don't forget to start consuming here!

    {:ok, %{}}
  end

  def handle_message(payload, meta, state) do
    IO.inspect("payload: #{inspect(payload)}, metadata: #{inspect(meta)}")
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
    Producer.publish("my_exchange", "my_exchange_routing_key", payload)
  end
end
```

## Handle message rejections

You can define an implement an optional callback inside your `Consumer` module
that will be called whenever an error is raised in the `handle_message` callback
and the `redelivered` flag is set to `true`. This callback can be useful
whenever you want to define a standard rejection logic (e.g. datadog alarms and
such).

### Consumer

```elixir
defmodule Myapp.HandleRejectionConsumer do
  @moduledoc nil
  @behaviour Amqpx.Gen.Consumer

  alias Amqpx.Basic
  alias Amqpx.Helper

  @config Application.get_env(:myapp, __MODULE__)
  @queue Application.get_env(:myapp, __MODULE__)[:queue]

  def setup(channel) do
    # here you can declare your queues and exchanges
    Helper.declare(channel, @config)
    Basic.consume(channel, @queue, self()) # Don't forget to start consuming here!

    {:ok, %{}}
  end

  def handle_message(payload, meta, state) do
    IO.inspect("payload: #{inspect(payload)}, metadata: #{inspect(meta)}")
    # something that could fail
    {:ok, state}
  end

  def handle_message_rejection(error) do 
    # will be invoked whenever handle_message fails
    # do something like error logging
    {:ok}
  end
end
```

## Local Environment

### Test suite

In order to run the test suite, you need to startup the docker compose and jump
into it with:

```
docker compose run --service-ports console bash
```

and run the test suite with:

```
mix test
```
