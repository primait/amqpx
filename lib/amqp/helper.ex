defmodule Amqpx.Helper do
  @moduledoc """
  Helper functions
  """

  alias Amqpx.{Exchange, Queue}

  def manager_supervisor_configuration(config) do
    {Amqpx.Gen.ConnectionManager, %{connection_params: encrypt_password(config)}}
  end

  def consumers_supervisor_configuration(handlers_conf) do
    Enum.map(handlers_conf, &Supervisor.child_spec({Amqpx.Gen.Consumer, &1}, id: UUID.uuid1()))
  end

  def producer_supervisor_configuration(producer_conf) do
    {Amqpx.Gen.Producer, producer_conf}
  end

  def encrypt_password(config) do
    case Keyword.get(config, :obfuscate_password, true) do
      true ->
        Keyword.put(config, :password, :credentials_obfuscation.encrypt(Keyword.get(config, :password, "guest")))

      _ ->
        config
    end
  end

  def get_password(config, nil) do
    case Keyword.get(config, :obfuscate_password, true) do
      true ->
        :credentials_obfuscation.decrypt(Keyword.get(config, :password, "guest"))

      _ ->
        Keyword.get(config, :password, "guest")
    end
  end

  def get_password(config, params) do
    case Keyword.get(config, :obfuscate_password, true) do
      true ->
        :credentials_obfuscation.decrypt(Keyword.get(config, :password, Keyword.get(params, :password)))

      _ ->
        Keyword.get(config, :password, Keyword.get(params, :password))
    end
  end

  def declare(
        channel,
        %{
          queue: qname,
          opts: opts,
          exchanges: exchanges
        } = queue
      ) do
    dead_lettering_config = %{queue: "#{qname}_errored"}

    case Enum.find(opts[:arguments], &match?({"x-dead-letter-exchange", :longstr, _}, &1)) do
      {_, _, dle} ->
        Map.put(dead_lettering_config, :exchange, dle)

        {dlr_config_key, dlr_config_value} =
          case Enum.find(opts[:arguments], &match?({"x-dead-letter-routing-key", :longstr, _}, &1)) do
            {_, _, dlrk} ->
              {:routing_key, dlrk}

            nil ->
              original_routing_keys = Enum.map(exchanges, & &1.routing_keys)
              {:original_routing_keys, original_routing_keys}
          end

        setup_dead_lettering(channel, %{dlr_config_key => dlr_config_value, queue: "#{qname}_errored", exchange: dle})

      nil ->
        nil
    end

    setup_queue(channel, queue)
  end

  def declare(channel, queue) do
    setup_queue(channel, queue)
  end

  def setup_dead_lettering(channel, %{queue: dlq, exchange: "", routing_key: dlq}) do
    # DLX will work through [default exchange](https://www.rabbitmq.com/tutorials/amqp-concepts.html#exchange-default)
    # since `x-dead-letter-routing-key` matches the queue name
    Queue.declare(channel, dlq, durable: true)
  end

  def setup_dead_lettering(_channel, %{queue: dlq, exchange: "", routing_key: bad_dlq}) do
    raise "If x-dead-letter-exchange is an empty string, x-dead-letter-routing-key should be '#{dlq}' instead of '#{bad_dlq}'"
  end

  def setup_dead_lettering(channel, %{queue: dlq, exchange: exchange, routing_key: routing_key}) do
    Exchange.declare(channel, exchange, :topic, durable: true)
    Queue.declare(channel, dlq, durable: true)
    Queue.bind(channel, dlq, exchange, routing_key: routing_key)
  end

  def setup_dead_lettering(channel, %{queue: dlq, exchange: exchange, original_routing_keys: original_routing_keys}) do
    Exchange.declare(channel, exchange, :topic, durable: true)
    Queue.declare(channel, dlq, durable: true)

    original_routing_keys
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.each(fn rk ->
      :ok = Queue.bind(channel, dlq, exchange, routing_key: rk)
    end)
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
