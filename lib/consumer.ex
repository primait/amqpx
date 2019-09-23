defmodule Amqpx.Consumer do
  @moduledoc """
  Generic implementation of AMQP consumer
  """
  require Logger
  use GenServer
  use AMQP
  alias AMQP.Channel

  @default_prefetch_count 50
  @backoff 5_000

  defstruct [
    :channel,
    :queue,
    :exchange,
    :exchange_type,
    :routing_keys,
    :handler_module,
    :handler_state,
    handler_args: [],
    queue_options: [
      durable: true
    ]
  ]

  @type state() :: %__MODULE__{}

  @callback setup(Channel.t(), any()) :: {:ok, map()} | {:error, any()}
  @callback handle_message(any(), map()) :: {:ok, map()} | {:error, any()}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    state = struct(__MODULE__, opts)

    case Process.send(self(), :setup, []) do
      :ok ->
        {:ok, state}

      _ ->
        {:stop, "ERROR"}
    end
  end

  @spec broker_connect(state()) :: {:ok, state()}
  defp broker_connect(
         %__MODULE__{handler_module: handler_module, queue: queue, handler_args: handler_args} =
           state
       ) do
    case Connection.open(Application.get_env(:amqpx, :broker)[:connection_params]) do
      {:ok, connection} ->
        Process.monitor(connection.pid)
        {:ok, channel} = Channel.open(connection)

        state = %{state | channel: channel}
        {:ok, _} = setup_queue(state)

        {:ok, handler_state} = handler_module.setup(channel, handler_args)
        state = %{state | handler_state: handler_state}

        Basic.qos(channel,
          prefetch_count: Map.get(state, :prefetch_count, @default_prefetch_count)
        )

        {:ok, _consumer_tag} = Basic.consume(channel, queue)

        {:ok, state}

      {:error, _} ->
        # Reconnection loop
        Logger.error("Unable to connect to Broker! Retrying with #{@backoff}ms backoff")
        :timer.sleep(@backoff)
        broker_connect(state)
    end
  end

  defp setup_queue(%__MODULE__{
         channel: channel,
         queue: queue,
         exchange: exchange,
         exchange_type: exchange_type,
         routing_keys: routing_keys,
         queue_options: options
       }) do
    {"x-dead-letter-routing-key", _, queue_dead_letter} = Enum.find(options[:arguments], &match?({"x-dead-letter-routing-key", _, _},&1))
    # Errored queue
    {:ok, _} = Queue.declare(channel, queue_dead_letter, durable: true)

    # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
    {:ok, _} =
      Queue.declare(
        channel,
        queue,
        options
      )

    :ok = Exchange.declare(channel, exchange, exchange_type, durable: true)

    Enum.each(routing_keys, fn rk ->
      :ok = Queue.bind(channel, queue, exchange, routing_key: rk)
    end)

    {:ok, %{}}
  end

  defp setup_queue(%__MODULE__{
         channel: channel,
         queue: queue,
         exchange: exchange,
         exchange_type: exchange_type,
         routing_keys: routing_keys,
         queue_options: options
       }) do
    {:ok, _} = Queue.declare(channel, queue, options)

    :ok = Exchange.declare(channel, exchange, exchange_type, durable: true)

    Enum.each(routing_keys, fn rk ->
      :ok = Queue.bind(channel, queue, exchange, routing_key: rk)
    end)

    {:ok, %{}}
  end

  def handle_info(:setup, state) do
    with {:ok, state} <- broker_connect(state) do
      {:noreply, state}
    end
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
        {:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}},
        state
      ) do
    {:noreply, handle_message(payload, tag, redelivered, state)}

    {:noreply, state}
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    with {:ok, state} <- broker_connect(state) do
      {:noreply, state}
    end
  end

  def handle_info({:EXIT, _pid, :normal}, state), do: {:noreply, state}

  def handle_info(message, state) do
    Logger.warn("Unknown message reiceived #{inspect(message)}")
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
         redelivered,
         %__MODULE__{handler_module: handler_module, handler_state: handler_state} = state
       ) do
    try do
      {:ok, handler_state} = handler_module.handle_message(message, handler_state)
      Basic.ack(state.channel, tag)
      %{state | handler_state: handler_state}
    rescue
      e in _ ->
        Logger.error(
          "Message not handled",
          error: inspect(e)
        )

        Basic.reject(state.channel, tag, requeue: !redelivered)
        :timer.sleep(@backoff)
        state
    end
  end
end
