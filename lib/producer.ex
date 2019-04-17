defmodule Amqpx.Producer do
  @moduledoc """
  implementazione generica di un producer AMQP
  """
  require Logger
  use GenServer
  use AMQP
  alias AMQP.Channel

  @backoff 5_000
  @publish_timeout 1_000

  defstruct [
    :channel,
    :exchange,
    :exchange_type,
    :routing_key
  ]

  @type state() :: %__MODULE__{}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
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
  defp rabbitmq_connect(%__MODULE__{exchange: exchange, exchange_type: exchange_type} = state) do
    case Connection.open(Application.get_env(:amqpx, :rabbit)[:connection_params]) do
      {:ok, connection} ->
        Process.monitor(connection.pid)
        {:ok, channel} = Channel.open(connection)
        state = %{state | channel: channel}

        :ok = Exchange.declare(channel, exchange, exchange_type, durable: true)

        {:noreply, state}

      {:error, _} ->
        # Reconnection loop
        Logger.error("Unable to connect to RabbitMQ! Retrying with #{@backoff}ms backoff")
        :timer.sleep(@backoff)
        rabbitmq_connect(state)
    end
  end

  def handle_info(:setup, state) do
    rabbitmq_connect(state)
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

  def handle_call(
        payload,
        _from,
        %__MODULE__{
          channel: channel,
          exchange: exchange,
          routing_key: routing_key
        } = state
      ) do
    Confirm.select(channel)

    with :ok <- Basic.publish(channel, exchange, routing_key, payload, persistent: true),
         {:confirm, true} <- {:confirm, Confirm.wait_for_confirms(channel, @publish_timeout)} do
      {:reply, :ok, state}
    else
      {:error, reason} ->
        Logger.error("cannot publish message to RabbitMQ: #{inspect(reason)}")
        {:stop, reason, "error", state}

      {:confirm, :timeout} ->
        Logger.error("cannot publish message to RabbitMQ: publisher timeout")
        {:stop, "publisher timeout", "timeout", state}

      {:confirm, false} ->
        Logger.error("cannot publish message to RabbitMQ: broker nack")
        {:stop, "publisher error", "error", state}
    end
  end

  def publish(payload) do
    with :ok <- GenServer.call(__MODULE__, payload) do
      :ok
    else
      reason ->
        Logger.error("Error during publish: #{inspect(reason)}")
        :error
    end
  end
end
