defmodule PrimaAmqp do
  @moduledoc """
  implementazione generica di un consumer AMQP
  """
  require Logger
  use GenServer
  use AMQP
  alias AMQP.Channel

  @default_prefetch_count 50
  @backoff 5_000
  @consumer_timeout 10_000

  defstruct [
    :modulem,
    :channel,
    :queue,
    :exchange,
    :exchange_type,
    :routing_keys,
    :queue_dead_letter,
    :handler_module,
    :handler_state
  ]

  @type state() :: %__MODULE__{}

  @callback setup(Channel.t()) :: {:ok, map()} | {:error, any()}
  @callback handle_message(any(), map()) :: {:ok, map()} | {:error, any()}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    state = struct(__MODULE__, opts)

    with :ok <- Process.send(self(), :setup, []) do
      {:ok, state}
    else
      _ -> {:stop, "ERROR"}
    end
  end

  @spec rabbitmq_connect(state()) :: {:ok, state()}
  defp rabbitmq_connect(%__MODULE__{handler_module: handler_module, queue: queue} = state) do
    case Connection.open(Application.get_env(:prima_amqp, :rabbit)[:connection_params]) do
      {:ok, connection} ->
        Process.monitor(connection.pid)
        {:ok, channel} = Channel.open(connection)
        state = %{state | channel: channel}
        IO.inspect(state)
        {:ok, _} = setup_queue(state)

        handler_state = handler_module.setup(channel, state)
        state = %{state | handler_state: handler_state}

        Basic.qos(channel,
          prefetch_count: Map.get(state, :prefetch_count, @default_prefetch_count)
        )

        {:ok, _consumer_tag} = Basic.consume(channel, queue)

        {:noreply, state}

      {:error, _} ->
        # Reconnection loop
        :timer.sleep(@backoff)
        rabbitmq_connect(state)
    end
  end

  defp setup_queue(%__MODULE__{
         channel: channel,
         queue: queue,
         exchange: exchange,
         exchange_type: exchange_type,
         routing_keys: routing_keys,
         queue_dead_letter: queue_dead_letter
       }) do
    {:ok, _} = Queue.declare(channel, queue_dead_letter, durable: true)

    # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
    {:ok, _} =
      Queue.declare(channel, queue,
        durable: true,
        arguments: [
          {"x-dead-letter-exchange", :longstr, ""},
          {"x-dead-letter-routing-key", :longstr, queue_dead_letter}
        ]
      )

    :ok = Exchange.declare(channel, exchange, exchange_type, durable: true)

    routing_keys
    |> Enum.map(fn rk -> :ok = Queue.bind(channel, queue, exchange, routing_key: rk) end)

    {:ok, %{}}
  end

  defp setup_queue(%__MODULE__{
         channel: channel,
         queue: queue,
         exchange: exchange,
         exchange_type: exchange_type,
         routing_keys: routing_keys
       }) do
    {:ok, _} = Queue.declare(channel, queue, durable: true)

    :ok = Exchange.declare(channel, exchange, exchange_type, durable: true)

    routing_keys
    |> Enum.map(fn rk -> :ok = Queue.bind(channel, queue, exchange, routing_key: rk) end)

    {:ok, %{}}
  end

  def handle_info(:setup, state) do
    Process.flag(:trap_exit, true)

    rabbitmq_connect(state)
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
    {:stop, :basic_cancel, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  def handle_info(
        {:basic_deliver, payload, %{delivery_tag: tag, redelivered: _redelivered}},
        state
      ) do
    message = :erlang.binary_to_term(payload)

    state = handle_message(message, tag, state)

    {:noreply, state}
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    with {:ok, state} <- rabbitmq_connect(state) do
      {:noreply, state}
    end
  end

  def handle_info({:EXIT, _pid, :normal}, state), do: {:noreply, state}

  def handle_info(message, state) do
    Logger.warn("Ricevuto messaggio sconosciuto #{inspect(message)}")
    {:noreply, state}
  end

  def terminate(_, %__MODULE__{channel: channel}) do
    with %Channel{pid: pid} <- channel do
      if Process.alive?(pid) do
        Channel.close(channel)
      end
    end
  end

  defp handle_message(
         message,
         tag,
         %__MODULE__{handler_module: handler_module, handler_state: handler_state} = state
       ) do
    task = Task.async(handler_module, :handle_message, [message, handler_state])

    with {:ok, result} <- Task.yield(task, @consumer_timeout),
         {:ok, handler_state} <- result do
      Basic.ack(state.channel, tag)
      %{state | handler_state: handler_state}
    else
      error ->
        Logger.error("#{error} impossibile gestire il messaggio rabbit #{message}")

        Basic.reject(state.channel, tag)
        :timer.sleep(@backoff)

        state
    end
  end
end
