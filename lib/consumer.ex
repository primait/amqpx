defmodule Amqpx.Consumer do
  @moduledoc """
  Generic implementation of AMQP consumer
  """
  require Logger
  use GenServer
  alias AMQP.{Connection, Channel, Basic}

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
  @callback handle_message(any(), map(), map()) :: {:ok, map()} | {:error, any()}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    state = struct(__MODULE__, opts)
    Process.send(self(), :setup, [])
    {:ok, state}
  end

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
  def handle_info({:basic_consume_ok, _consumer_tag}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, _consumer_tag}, state) do
    {:stop, :basic_cancel, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, _consumer_tag}, state) do
    {:stop, :basic_cancel_ok, state}
  end

  def handle_info(
        {:basic_deliver, payload, meta},
        state
      ) do
    {:noreply, handle_message(payload, meta, state)}
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    {:stop, {:DOWN, reason}, state}
  end

  def handle_info({:EXIT, _pid, :normal}, state), do: {:stop, :EXIT, state}

  def handle_info(message, state) do
    Logger.warn("Unknown message received #{inspect(message)}")
    {:noreply, state}
  end

  def terminate(_, %__MODULE__{channel: nil}), do: nil

  def terminate(_, %__MODULE__{channel: channel}) do
    if Process.alive?(channel.pid) do
      Channel.close(channel)
    end

    if Process.alive?(channel.conn.pid) do
      Connection.close(channel.conn)
    end
  end

  @spec broker_connect(state()) :: state()
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
    Process.monitor(channel.pid)
    state = %{state | channel: channel}

    Basic.qos(channel, prefetch_count: prefetch_count)

    {:ok, handler_state} = handler_module.setup(channel)
    state = %{state | handler_state: handler_state}

    state
  end

  defp handle_message(
         message,
         %{delivery_tag: tag, redelivered: redelivered} = meta,
         %__MODULE__{
           handler_module: handler_module,
           handler_state: handler_state,
           backoff: backoff
         } = state
       ) do
    try do
      {:ok, handler_state} = handler_module.handle_message(message, meta, handler_state)
      Basic.ack(state.channel, tag)
      %{state | handler_state: handler_state}
    rescue
      e in _ ->
        Logger.error(inspect(e))

        Task.start(fn ->
          :timer.sleep(backoff)
          Basic.reject(state.channel, tag, requeue: !redelivered)
        end)

        state
    end
  end
end
