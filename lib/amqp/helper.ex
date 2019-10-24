defmodule Amqpx.Helper do
  @moduledoc """
  Helper functions
  """

  alias Amqpx.{Exchange, Queue}

  def manager_supervisor_configuration(config) do
    {Amqpx.Gen.ConnectionManager, %{connection_params: config}}
  end

  def consumers_supervisor_configuration(handlers_conf) do
    Enum.map(handlers_conf, &Supervisor.child_spec({Amqpx.Gen.Consumer, &1}, id: UUID.uuid1()))
  end

  def producer_supervisor_configuration(producer_conf) do
    {Amqpx.Gen.Producer, producer_conf}
  end

  def declare(
        channel,
        %{
          queue: qname,
          opts: opts
        } = queue
      ) do
    case Enum.find(opts[:arguments], &match?({"x-dead-letter-exchange", _, _}, &1)) do
      {_, _, dle} ->
        case Enum.find(opts[:arguments], &match?({"x-dead-letter-routing-key", _, _}, &1)) do
          {_, _, dlrk} ->
            setup_dead_lettering(channel, %{
              queue: "#{qname}_errored",
              exchange: dle,
              routing_key: dlrk
            })

          nil ->
            setup_dead_lettering(channel, %{queue: "#{qname}_errored", exchange: dle})
        end

      nil ->
        nil
    end

    setup_queue(channel, queue)
  end

  def declare(channel, queue) do
    setup_queue(channel, queue)
  end

  def setup_dead_lettering(channel, %{queue: dlq, exchange: ""}) do
    Queue.declare(channel, dlq, durable: true)
  end

  def setup_dead_lettering(channel, %{queue: dlq, exchange: exchange, routing_key: routing_key}) do
    Exchange.declare(channel, exchange, :topic, durable: true)
    Queue.declare(channel, dlq, durable: true)
    Queue.bind(channel, dlq, exchange, routing_key: routing_key)
  end

  def setup_dead_lettering(channel, %{queue: dlq, exchange: exchange}) do
    Exchange.declare(channel, exchange, :topic, durable: true)
    Queue.declare(channel, dlq, durable: true)
  end

  def setup_queue(channel, %{
        queue: queue,
        exchanges: exchanges,
        opts: opts
      }) do
    {:ok, _} = Queue.declare(channel, queue, opts)

    Enum.each(exchanges, &setup_exchange(channel, queue, &1))
  end

  def setup_queue(channel, %{
        queue: queue,
        exchanges: exchanges
      }) do
    {:ok, _} = Queue.declare(channel, queue)

    Enum.each(exchanges, &setup_exchange(channel, queue, &1))
  end

  def setup_exchange(channel, queue, %{
        name: name,
        type: type,
        routing_keys: routing_keys,
        opts: opts
      })
      when type in [:direct, :topic] do
    Exchange.declare(channel, name, type, opts)

    Enum.each(routing_keys, fn rk ->
      :ok = Queue.bind(channel, queue, name, routing_key: rk)
    end)
  end

  def setup_exchange(channel, queue, %{
        name: name,
        type: type,
        routing_keys: routing_keys
      })
      when type in [:direct, :topic] do
    Exchange.declare(channel, name, type)

    Enum.each(routing_keys, fn rk ->
      :ok = Queue.bind(channel, queue, name, routing_key: rk)
    end)
  end

  def setup_exchange(channel, queue, %{name: name, type: :fanout, opts: opts}) do
    Exchange.declare(channel, name, :fanout, opts)
    Queue.bind(channel, queue, name)
  end

  def setup_exchange(channel, queue, %{name: name, type: :fanout}) do
    Exchange.declare(channel, name, :fanout)
    Queue.bind(channel, queue, name)
  end

  def setup_exchange(_chan, _queue, conf) do
    raise "Unhandled exchange configuration #{inspect(conf)}"
  end

  def setup_exchange(channel, %{name: name, type: type, opts: opts}) do
    Exchange.declare(channel, name, type, opts)
  end

  def setup_exchange(channel, %{name: name, type: type}) do
    Exchange.declare(channel, name, type)
  end
end
