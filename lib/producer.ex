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
          # TODO: Correct type
          channel: any(),
          exchanges: list(exchange())
        }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = %{
      channel: nil,
      exchanges: opts
    }

    with :ok <- Process.send(self(), :setup, []) do
      {:ok, state}
    else
      _ -> {:stop, "ERROR"}
    end
  end

  @spec broker_connect(state()) :: {:ok, state()}
  defp broker_connect(%{exchanges: exchanges} = state) do
    case Connection.open(Application.get_env(:amqpx, :broker)[:connection_params]) do
      {:ok, connection} ->
        Process.monitor(connection.pid)
        {:ok, channel} = Channel.open(connection)
        state = %{state | channel: channel}

        Enum.each(exchanges, fn [name: name, type: type] ->
          :ok = Exchange.declare(channel, name, type, durable: true)
        end)

        {:ok, state}

      {:error, _} ->
        # Reconnection loop
        Logger.error("Unable to connect to Broker! Retrying with #{@backoff}ms backoff")
        :timer.sleep(@backoff)
        broker_connect(state)
    end
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

  def terminate(_, %{channel: channel}) do
    with %Channel{pid: pid} <- channel do
      if Process.alive?(pid) do
        Channel.close(channel)
      end
    end
  end

  def handle_call(
        {:publish, {exchange, routing_key, payload}},
        _from,
        %{channel: channel} = state
      ) do
    Confirm.select(channel)

    with :ok <- Basic.publish(channel, exchange, routing_key, payload, persistent: true),
         {:confirm, true} <- {:confirm, Confirm.wait_for_confirms(channel, @publish_timeout)} do
      {:reply, :ok, state}
    else
      {:error, reason} ->
        Logger.error("cannot publish message to broker: #{inspect(reason)}")
        {:stop, reason, "error", state}

      {:confirm, :timeout} ->
        Logger.error("cannot publish message to broker: publisher timeout")
        {:stop, "publisher timeout", "timeout", state}

      {:confirm, false} ->
        Logger.error("cannot publish message to broker: broker nack")
        {:stop, "publisher error", "error", state}
    end
  end

  def publish(name, routing_key, payload) do
    with :ok <- GenServer.call(__MODULE__, {:publish, {name, routing_key, payload}}) do
      :ok
    else
      reason ->
        Logger.error("Error during publish: #{inspect(reason)}")
        :error
    end
  end
end
