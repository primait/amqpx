defmodule Amqpx.Helper do
  @moduledoc """
  Helper functions
  """

  require Logger

  alias Amqpx.{Basic, Channel, Exchange, Queue}

  @dead_letter_queue_defaults [durable: true]

  # Supervisor.module_spec() has been introduced with elixir 1.16
  # we can remove this when we update the minimum supported version
  @type module_spec :: {module, arg :: any}

  @type exchange_spec :: %{
          name: Basic.exchange(),
          type: atom,
          routing_keys: [String.t()],
          opts: Keyword.t()
        }

  @type queue_spec :: %{
          :queue => Basic.queue(),
          :exchanges => [exchange_spec],
          optional(:opts) => Keyword.t()
        }

  @type dead_letter_queue_spec :: %{
          :queue => Basic.queue(),
          :exchange => Basic.exchange(),
          :routing_key => String.t(),
          optional(:original_routing_keys) => [String.t()],
          optional(:queue_opts) => Keyword.t()
        }

  @spec manager_supervisor_configuration(Keyword.t()) :: module_spec
  def manager_supervisor_configuration(config) do
    {Amqpx.Gen.ConnectionManager, %{connection_params: encrypt_password(config)}}
  end

  @spec consumers_supervisor_configuration([handler_conf :: map]) :: [Supervisor.child_spec()]
  def consumers_supervisor_configuration(handlers_conf) do
    handlers_conf
    |> Enum.flat_map(&duplicate_concurrent_consumers/1)
    |> Enum.map(&Supervisor.child_spec({Amqpx.Gen.Consumer, &1}, id: UUID.uuid1()))
  end

  @spec producer_supervisor_configuration(producer_conf :: map) :: module_spec
  def producer_supervisor_configuration(producer_conf) do
    {Amqpx.Gen.Producer, producer_conf}
  end

  @spec encrypt_password(Keyword.t()) :: Keyword.t()
  def encrypt_password(config) do
    case Keyword.get(config, :obfuscate_password, true) do
      true ->
        Keyword.put(config, :password, :credentials_obfuscation.encrypt(Keyword.get(config, :password, "guest")))

      _ ->
        config
    end
  end

  @spec get_password(Keyword.t(), Keyword.t() | nil) :: Keyword.value()
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

  @spec declare(Channel.t(), queue_spec) :: :ok | no_return
  def declare(
        channel,
        %{
          queue: qname,
          opts: opts,
          exchanges: exchanges
        } = queue
      ) do
    arguments = Keyword.get(opts, :arguments, [])

    case Enum.find(arguments, &match?({"x-dead-letter-exchange", :longstr, _}, &1)) do
      {_, _, dle} ->
        {dlr_config_key, dlr_config_value} =
          case Enum.find(arguments, &match?({"x-dead-letter-routing-key", :longstr, _}, &1)) do
            {_, _, dlrk} ->
              {:routing_key, dlrk}

            nil ->
              original_routing_keys = Enum.flat_map(exchanges, & &1.routing_keys)
              {:original_routing_keys, original_routing_keys}
          end

        setup_dead_lettering(channel, %{
          dlr_config_key => dlr_config_value,
          queue: "#{qname}_errored",
          exchange: dle,
          queue_opts: set_dead_letter_queue_type(@dead_letter_queue_defaults, arguments)
        })

      nil ->
        nil
    end

    setup_queue(channel, queue)
  end

  def declare(channel, queue) do
    setup_queue(channel, queue)
  end

  @spec setup_dead_lettering(Channel.t(), dead_letter_queue_spec) :: :ok | {:ok, map} | Basic.error()
  def setup_dead_lettering(channel, %{queue: dlq, exchange: "", routing_key: dlq} = spec) do
    # DLX will work through [default exchange](https://www.rabbitmq.com/tutorials/amqp-concepts.html#exchange-default)
    # since `x-dead-letter-routing-key` matches the queue name
    Queue.declare(channel, dlq, dead_letter_queue_opts(spec))
  end

  def setup_dead_lettering(_channel, %{queue: dlq, exchange: "", routing_key: bad_dlq}) do
    msg =
      "If x-dead-letter-exchange is an empty string, x-dead-letter-routing-key should be '#{dlq}' instead of '#{bad_dlq}'"

    if Enum.member?(skip_dead_letter_routing_key_check_for(), bad_dlq) do
      Logger.warning(msg)
    else
      raise msg
    end
  end

  def setup_dead_lettering(channel, %{queue: dlq, exchange: exchange, routing_key: routing_key} = spec) do
    Exchange.declare(channel, exchange, :topic, durable: true)
    Queue.declare(channel, dlq, dead_letter_queue_opts(spec))
    Queue.bind(channel, dlq, exchange, routing_key: routing_key)
  end

  def setup_dead_lettering(
        channel,
        %{queue: dlq, exchange: exchange, original_routing_keys: original_routing_keys} = spec
      ) do
    Exchange.declare(channel, exchange, :topic, durable: true)
    Queue.declare(channel, dlq, dead_letter_queue_opts(spec))

    original_routing_keys
    |> Enum.uniq()
    |> Enum.each(fn rk ->
      :ok = Queue.bind(channel, dlq, exchange, routing_key: rk)
    end)
  end

  @spec setup_queue(Channel.t(), queue_spec) :: :ok | no_return
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

  @spec setup_exchange(Channel.t(), Basic.queue(), exchange_spec) :: :ok | Basic.error() | no_return
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

  @spec dead_letter_queue_opts(dead_letter_queue_spec) :: Keyword.t()
  defp dead_letter_queue_opts(spec) do
    Map.get(spec, :queue_opts, @dead_letter_queue_defaults)
  end

  @spec set_dead_letter_queue_type(Keyword.t(), [{String.t(), atom, any}]) :: Keyword.t()
  defp set_dead_letter_queue_type(dlq_opts, queue_args) do
    case Enum.find(queue_args, &match?({"x-queue-type", :longstr, _}, &1)) do
      nil ->
        dlq_opts

      queue_type ->
        Keyword.update(dlq_opts, :arguments, [queue_type], &[queue_type | &1])
    end
  end

  defp skip_dead_letter_routing_key_check_for,
    do: Application.get_env(:amqpx, :skip_dead_letter_routing_key_check_for, [])

  @spec duplicate_concurrent_consumers(map) :: [map]
  defp duplicate_concurrent_consumers(conf) do
    {concurrency_level, conf} = Map.pop(conf, :concurrency_level, 1)
    List.duplicate(conf, concurrency_level)
  end
end
