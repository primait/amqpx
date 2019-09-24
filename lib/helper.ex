defmodule Amqpx.Helper do
  alias AMQP.{Exchange, Queue}

  def declare_queue(
        channel,
        %{
          name: name,
          opts: [
            arguments: [
              {"x-dead-letter-routing-key", _, dlrk},
              {"x-dead-letter-exchange", _, dle}
            ]
          ]
        } = queue
      ) do
    setup_dead_lettering(channel, %{queue: "#{name}_errored", exchange: dle, routing_key: dlrk})
    setup_queue(channel, queue)
  end

  def declare_queue(
        channel,
        %{
          name: name,
          opts: [
            arguments: [
              {"x-dead-letter-exchange", _type, dle}
            ]
          ]
        } = queue
      ) do
    setup_dead_lettering(channel, %{queue: "#{name}_errored", exchange: dle})
    setup_queue(channel, queue)
  end

  def declare_queue(channel, queue) do
    setup_queue(channel, queue)
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

  defp setup_dead_lettering(_channel, conf) do
    raise "Unhandled dead letter configuration #{inspect(conf)}"
  end

  defp setup_queue(channel, %{
         name: qname,
         exchanges: exchanges,
         opts: opts
       }) do
    {:ok, _} = Queue.declare(channel, qname, opts)

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

  defp setup_exchange(channel, queue, %{name: name, type: :fanout, opts: opts}) do
    Exchange.declare(channel, name, :fanout, opts)
    Queue.bind(channel, queue, name)
  end

  defp setup_exchange(channel, queue, %{
         name: name,
         type: :headers,
         bind_opts: bind_opts,
         opts: opts
       }) do
    Exchange.declare(channel, name, :headers, opts)
    Queue.bind(channel, queue, name, bind_opts)
  end

  defp setup_exchange(_chan, _queue, conf) do
    raise "Unhandled exchange configuration #{inspect(conf)}"
  end
end
