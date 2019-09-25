defmodule Amqpx.Helper do
  @moduledoc """
  Helper functions
  """

  alias AMQP.{Exchange, Queue}

  def consumers_supervisor_configuration(handlers_conf, connection_params) do
    Enum.map(
      handlers_conf,
      &Supervisor.child_spec(
        {Amqpx.Consumer, Map.put(&1, :connection_params, connection_params)},
        id: UUID.uuid1()
      )
    )
  end

  def producer_supervisor_configuration(producer_conf, connection_params) do
    {Amqpx.Producer, Map.put(producer_conf, :connection_params, connection_params)}
  end

  def declare_queue(
        channel,
        %{
          name: name,
          opts: opts
        } = queue
      ) do
    case Enum.find(opts[:arguments], &match?({"x-dead-letter-exchange", _, _}, &1)) do
      {_, _, dle} ->
        case Enum.find(opts[:arguments], &match?({"x-dead-letter-routing-key", _, _}, &1)) do
          {_, _, dlrk} ->
            setup_dead_lettering(channel, %{
              queue: "#{name}_errored",
              exchange: dle,
              routing_key: dlrk
            })

          nil ->
            setup_dead_lettering(channel, %{queue: "#{name}_errored", exchange: dle})
        end

      nil ->
        nil
    end

    setup_queue(channel, queue)
  end

  def declare_queue(channel, queue) do
    setup_queue(channel, queue)
  end

  defp setup_dead_lettering(channel, %{queue: dlq, exchange: ""}) do
    Queue.declare(channel, dlq, durable: true)
  end

  defp setup_dead_lettering(channel, %{queue: dlq, exchange: exchange, routing_key: routing_key}) do
    Exchange.declare(channel, exchange, :topic, durable: true)
    Queue.declare(channel, dlq, durable: true)
    Queue.bind(channel, dlq, exchange, routing_key: routing_key)
  end

  defp setup_dead_lettering(channel, %{queue: dlq, exchange: exchange}) do
    Exchange.declare(channel, exchange, :topic, durable: true)
    Queue.declare(channel, dlq, durable: true)
  end

  defp setup_queue(channel, %{
         name: qname,
         exchanges: exchanges,
         opts: opts
       }) do
    {:ok, _} = Queue.declare(channel, qname, opts)

    Enum.each(exchanges, &setup_exchange(channel, qname, &1))
  end

  defp setup_queue(channel, %{
         name: qname,
         exchanges: exchanges
       }) do
    {:ok, _} = Queue.declare(channel, qname)

    Enum.each(exchanges, &setup_exchange(channel, qname, &1))
  end

  defp setup_exchange(channel, queue, %{
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

  defp setup_exchange(channel, queue, %{
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

  defp setup_exchange(channel, queue, %{name: name, type: :fanout, opts: opts}) do
    Exchange.declare(channel, name, :fanout, opts)
    Queue.bind(channel, queue, name)
  end

  defp setup_exchange(channel, queue, %{name: name, type: :fanout}) do
    Exchange.declare(channel, name, :fanout)
    Queue.bind(channel, queue, name)
  end

  defp setup_exchange(_chan, _queue, conf) do
    raise "Unhandled exchange configuration #{inspect(conf)}"
  end
end
