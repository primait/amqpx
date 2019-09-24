defmodule Amqpx.Consumer do
  @moduledoc """
  Generic implementation of AMQP consumer
  """
  require Logger
  use GenServer
  use AMQP
  alias AMQP.Channel

  defstruct [
    :connection_params,
    :channel,
    :handler_module,
    :handler_state,
    prefetch_count: 50,
    backoff: 5_000
  ]

  @type state() :: %__MODULE__{}

  @callback setup(Channel.t()) :: {:ok, map()} | {:error, any()}
  @callback handle_message(any(), map()) :: {:ok, map()} | {:error, any()}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    state = struct(__MODULE__, opts)
    Process.send(self(), :setup, [])
    {:ok, state}
  end

  # defp setup_queue(%__MODULE__{
  #        channel: channel,
  #        queue: queue,
  #        exchange: exchange,
  #        exchange_type: exchange_type,
  #        routing_keys: routing_keys,
  #        queue_options: options
  #      }) do
  #   case Enum.find(options[:arguments], &match?({"x-dead-letter-routing-key", _, _}, &1)) do
  #     {"x-dead-letter-routing-key", _, queue_dead_letter} ->
  #       # Errored queue
  #       {:ok, _} = Queue.declare(channel, queue_dead_letter, durable: true)
  #
  #     nil ->
  #       nil
  #   end
  #
  #   # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
  #   {:ok, _} =
  #     Queue.declare(
  #       channel,
  #       queue,
  #       options
  #     )
  #
  #   :ok = Exchange.declare(channel, exchange, exchange_type, durable: true)
  #
  #   Enum.each(routing_keys, fn rk ->
  #     :ok = Queue.bind(channel, queue, exchange, routing_key: rk)
  #   end)
  #
  #   {:ok, %{}}
  # end

  def handle_info(:setup, %{backoff: backoff} = state) do
    try do
      {:noreply, broker_connect(state)}
    rescue
      exception in _ ->
        Logger.error("Unable to connect to Broker! Retrying with #{backoff}ms backoff",
          error: inspect(exception)
        )

        :timer.sleep(backoff)
        {:stop, exception, state}
    end
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:stop, :basic_cancel, state}
  end

  def handle_info(
        {:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}},
        state
      ) do
    {:noreply, handle_message(payload, tag, redelivered, state)}
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    {:stop, {:DOWN, reason}, state}
  end

  # def handle_info({:EXIT, _pid, :normal}, state), do: {:noreply, state}

  def handle_info(message, state) do
    Logger.warn("Unknown message reiceived #{inspect(message)}")
    {:noreply, state}
  end

  def terminate(_, %__MODULE__{channel: channel}) do
    with %Channel{conn: %Connection{pid: pid} = conn} <- channel do
      if Process.alive?(pid) do
        Connection.close(conn)
      end
    end
  end

  @spec broker_connect(state()) :: {:ok, state()}
  defp broker_connect(
         %__MODULE__{
           connection_params: connection_params,
           handler_module: handler_module,
           prefetch_count: prefetch_count
         } = state
       ) do
    {:ok, connection} = Connection.open(connection_params)
    Process.monitor(connection.pid)

    {:ok, channel} = Channel.open(connection)
    state = %{state | channel: channel}
    # {:ok, _} = setup_queue(state) da spostare nel setup

    {:ok, handler_state} = handler_module.setup(channel)
    state = %{state | handler_state: handler_state}

    Basic.qos(channel, prefetch_count: prefetch_count)

    # {:ok, _consumer_tag} = Basic.consume(channel, queue) da spostare nel setup

    state
  end

  defp handle_message(
         message,
         tag,
         redelivered,
         %__MODULE__{
           handler_module: handler_module,
           handler_state: handler_state,
           backoff: backoff
         } = state
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
        :timer.sleep(backoff)
        state
    end
  end
end
