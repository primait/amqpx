defmodule Amqpx.Producer do
  @moduledoc """
  Generic implementation of AMQP producer
  """
  require Logger
  use GenServer
  use AMQP
  alias AMQP.Channel

  @backoff 5_000
  @publish_timeout 1_000

  @type exchange() :: %{
          name: String.t(),
          type: String.t()
        }
  @type state() :: %{
          channel: Connection.t(),
          publisher_confirms: boolean,
          exchanges: list(exchange())
        }

  # Public API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec publish(String.t(), String.t(), String.t()) :: :ok | :error
  def publish(name, routing_key, payload) do
    with :ok <- GenServer.call(__MODULE__, {:publish, {name, routing_key, payload}}) do
      :ok
    else
      reason ->
        Logger.error("Error during publish: #{inspect(reason)}")
        :error
    end
  end

  # Callbacks

  def init(publisher_confirms: publisher_confirms, exchanges: exchanges) do
    state = %{
      channel: nil,
      publisher_confirms: publisher_confirms,
      exchanges: exchanges
    }

    # Can't return anything else but :ok when sending to self()
    Process.send(self(), :setup, [])

    {:ok, state}
  end

  def handle_info(:setup, state) do
    with {:ok, state} <- broker_connect(state) do
      {:noreply, state}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    with {:ok, state} <- broker_connect(state) do
      {:noreply, state}
    end
  end

  def handle_info({:EXIT, _pid, :normal}, state), do: {:noreply, state}

  def handle_info(message, state) do
    Logger.warn("Ricevuto messaggio sconosciuto #{inspect(message)}")
    {:noreply, state}
  end

  def handle_call(_msg, _from, %{channel: nil}) do
    {:reply, {:error, :not_connected}}
  end

  def handle_call(
        {:publish, {exchange, routing_key, payload}},
        _from,
        %{channel: channel, publisher_confirms: publisher_confirms} = state
      ) do
    with :ok <- Basic.publish(channel, exchange, routing_key, payload, persistent: true),
         {:confirm, true} <- {:confirm, confirm_delivery(publisher_confirms, channel)} do
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

  def terminate(_, %{channel: channel}) do
    with %Channel{pid: pid} <- channel do
      if Process.alive?(pid) do
        Channel.close(channel)
      end
    end
  end

  # Private functions

  @spec confirm_delivery(boolean(), Channel.t()) :: boolean() | :timeout
  defp confirm_delivery(false, _), do: true

  defp confirm_delivery(true, channel) do
    Confirm.wait_for_confirms(channel, @publish_timeout)
  end

  @spec broker_connect(state()) :: {:ok, state()}
  defp broker_connect(%{exchanges: exchanges, publisher_confirms: publisher_confirms} = state) do
    case Connection.open(Application.get_env(:amqpx, :broker)[:connection_params]) do
      {:ok, connection} ->
        Process.monitor(connection.pid)
        {:ok, channel} = Channel.open(connection)
        state = %{state | channel: channel}

        if publisher_confirms do
          Confirm.select(channel)
        end

        Enum.each(exchanges, fn [name: name, type: type] ->
          :ok = Exchange.declare(channel, name, type, durable: true)
        end)

        {:ok, state}

      {:error, _} ->
        # Reconnection loop
        Logger.error("Unable to connect to Broker! Retrying with #{@backoff}ms backoff")
        Process.send_after(self(), :setup, @backoff)
    end
  end
end
