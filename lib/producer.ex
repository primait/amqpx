defmodule Amqpx.Producer do
  @moduledoc """
  Generic implementation of AMQP producer
  """
  require Logger
  use GenServer
  alias AMQP.{Channel, Basic, Confirm}

  @type state() :: %__MODULE__{}

  defstruct [
    :channel,
    :publisher_confirms,
    publish_timeout: 1_000,
    backoff: 5_000,
    exchanges: []
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
    Process.send(self(), :setup, [])
    {:ok, state}
  end

  def handle_info(:setup, %{publisher_confirms: publisher_confirms, exchanges: exchanges} = state) do
    connection = GenServer.call(AmqpxConnectionManager, :get_connection)

    {:ok, channel} = Channel.open(connection)
    Process.monitor(channel.pid)
    state = %{state | channel: channel}

    channel.pid
    |> :erlang.process_info()
    |> Keyword.get(:dictionary)
    |> Keyword.get(:"$ancestors")
    |> Enum.each(&Process.monitor(&1))

    declare_exchanges(exchanges, channel)

    if publisher_confirms do
      Confirm.select(channel)
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    Logger.error("Monitored channel process crashed: #{inspect(reason)}")
    {:stop, :channel_exited, state}
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

  # Private functions

  @spec confirm_delivery(boolean(), integer(), Channel.t()) :: boolean() | :timeout
  defp confirm_delivery(false, _, _), do: true

  defp confirm_delivery(true, timeout, channel) do
    Confirm.wait_for_confirms(channel, timeout)
  end

  defp declare_exchanges(exchanges, channel) do
    exchanges
    |> Enum.each(&Amqpx.Helper.setup_exchange(channel, &1))
  end
end
