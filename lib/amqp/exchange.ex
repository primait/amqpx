defmodule Amqpx.Exchange do
  @moduledoc """
  Functions to operate on Exchanges.
  """

  import Amqpx.Core

  alias Amqpx.{Basic, Channel}

  @doc """
  Declares an Exchange. The default Exchange type is `direct`.

  Amqpx 0-9-1 brokers provide four pre-declared exchanges:

  *   `:direct` exchange: (empty string) or `amq.direct`
  *   `:fanout` exchange: `amq.fanout`
  *   `:topic` exchange: `amq.topic`
  *   `:headers` exchange: `amq.match` (and `amq.headers` in RabbitMQ)

  Besides the exchange name and type, the following options can be used:

  ## Options

    * `:durable` - If set, keeps the Exchange between restarts of the broker;
    * `:auto_delete` - If set, deletes the Exchange once all queues unbind from it;
    * `:passive` - If set, returns an error if the Exchange does not already exist;
    * `:internal` - If set, the exchange may not be used directly by publishers, but only when bound to other exchanges. Internal exchanges are used to construct wiring that is not visible to applications.
    * `:no_wait` - If set, the declare operation is asynchronous. Defaults to
      `false`.
    * `:arguments` - A list of arguments to pass when declaring (of type `t:Amqpx.arguments/0`).
      See the README for more information. Defaults to `[]`.

  """
  @spec declare(Channel.t(), Basic.exchange(), type :: atom, keyword) :: :ok | Basic.error()
  def declare(%Channel{pid: pid}, exchange, type \\ :direct, options \\ []) do
    exchange_declare =
      exchange_declare(
        exchange: exchange,
        type: Atom.to_string(type),
        passive: Keyword.get(options, :passive, false),
        durable: Keyword.get(options, :durable, false),
        auto_delete: Keyword.get(options, :auto_delete, false),
        internal: Keyword.get(options, :internal, false),
        nowait: Keyword.get(options, :no_wait, false),
        arguments: Keyword.get(options, :arguments, [])
      )

    case :amqp_channel.call(pid, exchange_declare) do
      exchange_declare_ok() -> :ok
      error -> {:error, error}
    end
  end

  @doc """
  Deletes an Exchange by name. When an Exchange is deleted all bindings to it are
  also deleted.

  ## Options

    * `:if_unused` - If set, the server will only delete the exchange if it has no queue
      bindings.
    * `:no_wait` - If set, the delete operation is asynchronous. Defaults to
      `false`.

  """
  @spec delete(Channel.t(), Basic.exchange(), keyword) :: :ok | Basic.error()
  def delete(%Channel{pid: pid}, exchange, options \\ []) do
    exchange_delete =
      exchange_delete(
        exchange: exchange,
        if_unused: Keyword.get(options, :if_unused, false),
        nowait: Keyword.get(options, :no_wait, false)
      )

    case :amqp_channel.call(pid, exchange_delete) do
      exchange_delete_ok() -> :ok
      error -> {:error, error}
    end
  end

  @doc """
  Binds an Exchange to another Exchange using the
  exchange.bind Amqpx method (a RabbitMQ-specific extension).

  ## Options

    * `:routing_key` - the routing key to use for the binding. Defaults to `""`.
    * `:no_wait` - If set, the bind operation is asynchronous. Defaults to
      `false`.
    * `:arguments` - A list of arguments to pass when binding (of type `t:Amqpx.arguments/0`).
      See the README for more information. Defaults to `[]`.

  """
  @spec bind(Channel.t(), destination :: String.t(), source :: String.t(), keyword) ::
          :ok | Basic.error()
  def bind(%Channel{pid: pid}, destination, source, options \\ []) do
    exchange_bind =
      exchange_bind(
        destination: destination,
        source: source,
        routing_key: Keyword.get(options, :routing_key, ""),
        nowait: Keyword.get(options, :no_wait, false),
        arguments: Keyword.get(options, :arguments, [])
      )

    case :amqp_channel.call(pid, exchange_bind) do
      exchange_bind_ok() -> :ok
      error -> {:error, error}
    end
  end

  @doc """
  Unbinds an Exchange from another Exchange or a Queue using the
  exchange.unbind Amqpx method (a RabbitMQ-specific extension).

  ## Options

    * `:routing_key` - the routing key to use for the binding. Defaults to `""`.
    * `:no_wait` - If set, the declare operation is asynchronous. Defaults to
      `false`.
    * `:arguments` - A list of arguments to pass when declaring (of type `t:Amqpx.arguments/0`).
      See the README for more information. Defaults to `[]`.

  """
  @spec unbind(Channel.t(), destination :: String.t(), source :: String.t(), keyword) ::
          :ok | Basic.error()
  def unbind(%Channel{pid: pid}, destination, source, options \\ []) do
    exchange_unbind =
      exchange_unbind(
        destination: destination,
        source: source,
        routing_key: Keyword.get(options, :routing_key, ""),
        nowait: Keyword.get(options, :no_wait, false),
        arguments: Keyword.get(options, :arguments, [])
      )

    case :amqp_channel.call(pid, exchange_unbind) do
      exchange_unbind_ok() -> :ok
      error -> {:error, error}
    end
  end

  @doc """
  Convenience function to declare an Exchange of type `direct`.

  ## Options

  This function takes the same options as `declare/4`.
  """
  @spec direct(Channel.t(), Basic.exchange(), keyword) :: :ok | Basic.error()
  def direct(%Channel{} = channel, exchange, options \\ []) do
    declare(channel, exchange, :direct, options)
  end

  @doc """
  Convenience function to declare an Exchange of type `fanout`.

  ## Options

  This function takes the same options as `declare/4`.
  """
  @spec fanout(Channel.t(), Basic.exchange(), keyword) :: :ok | Basic.error()
  def fanout(%Channel{} = channel, exchange, options \\ []) do
    declare(channel, exchange, :fanout, options)
  end

  @doc """
  Convenience function to declare an Exchange of type `topic`.

  ## Options

  This function takes the same options as `declare/4`.
  """
  @spec topic(Channel.t(), Basic.exchange(), keyword) :: :ok | Basic.error()
  def topic(%Channel{} = channel, exchange, options \\ []) do
    declare(channel, exchange, :topic, options)
  end
end
