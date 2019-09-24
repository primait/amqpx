defmodule Amqpx.Producer do
  @moduledoc """
  Generic implementation of AMQP producer
  """
  require Logger
  use GenServer
  use AMQP
  alias AMQP.Channel

  @type state() :: %__MODULE__{}

  defstruct [
    :connection_params,
    :channel,
    :publisher_confirms,
    publish_timeout: 1_000,
    backoff: 5_000
  ]

  # Public API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec publish(String.t(), String.t(), String.t(), Keyword.t()) :: :ok | :error
  def publish(name, routing_key, payload, options \\ []) do
    case GenServer.call(__MODULE__, {:publish, {name, routing_key, payload, options}}) do
      :ok ->
        :ok

      reason ->
        Logger.error("Error during publish: #{inspect(reason)}")
        :error
    end
  end

  # Callbacks

  def init(opts) do
    state = struct(__MODULE__, opts)
    state = %{state | connection_params: Application.get_env( Mix.Project.config()[:app], :connection_params)}
    Process.send(self(), :setup, [])
    {:ok, state}
  end

  def handle_info(:setup, %{backoff: backoff} = state) do
    try do
      {:noreply, broker_connect(state)}
    rescue
      exception in _ ->
        Logger.error("Unable to connect to Broker! Retrying with #{inspect(backoff)}ms backoff",
          error: inspect(exception)
        )

        :timer.sleep(backoff)
        {:stop, exception, state}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    {:stop, {:DOWN, reason}, state}
  end

  # def handle_info({:EXIT, _pid, :normal}, state), do: {:noreply, state}

  def handle_info(message, state) do
    Logger.warn("Unknown message received #{inspect(message)}")
    {:noreply, state}
  end

  def handle_call(_msg, _from, %{channel: nil}) do
    {:reply, {:error, :not_connected}}
  end

  def handle_call(
        {:publish, {exchange, routing_key, payload, options}},
        _from,
        %{
          channel: channel,
          publisher_confirms: publisher_confirms,
          publish_timeout: publish_timeout
        } = state
      ) do
    with :ok <-
           Basic.publish(
             channel,
             exchange,
             routing_key,
             payload,
             Keyword.merge([persistent: true], options)
           ),
         {:confirm, true} <-
           {:confirm, confirm_delivery(publisher_confirms, publish_timeout, channel)} do
      {:reply, :ok, state}
    else
      {:error, reason} ->
        Logger.error("cannot publish message to broker: #{inspect(reason)}")
        {:stop, reason, {:error, reason}, state}

      {:confirm, :timeout} ->
        Logger.error("cannot publish message to broker: publisher timeout")
        {:stop, "publisher timeout", {:error, :timeout}, state}

      {:confirm, false} ->
        Logger.error("cannot publish message to broker: broker nack")
        {:stop, "publisher error", {:error, :nack}, state}
    end
  end

  def terminate(_, %__MODULE__{channel: channel}) do
    with %Channel{conn: %Connection{pid: pid} = conn} <- channel do
      if Process.alive?(pid) do
        Connection.close(conn)
      end
    end
  end

  # Private functions

  @spec confirm_delivery(boolean(), integer(), Channel.t()) :: boolean() | :timeout
  defp confirm_delivery(false, _, _), do: true

  defp confirm_delivery(true, timeout, channel) do
    Confirm.wait_for_confirms(channel, timeout)
  end

  @spec broker_connect(state()) :: {:ok, state()}
  defp broker_connect(
         %{publisher_confirms: publisher_confirms, connection_params: connection_params} = state
       ) do
    {:ok, connection} = Connection.open(connection_params)
    Process.monitor(connection.pid)

    {:ok, channel} = Channel.open(connection)
    state = %{state | channel: channel}

    if publisher_confirms do
      Confirm.select(channel)
    end

    state
  end
end
