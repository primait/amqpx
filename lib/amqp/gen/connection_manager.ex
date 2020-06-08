defmodule Amqpx.Gen.ConnectionManager do
  @moduledoc """
  Handle connection for all consumers and producer
  """
  require Logger
  use GenServer
  alias Amqpx.Connection

  defstruct [
    :connection_params,
    backoff: 5_000,
    connection: nil
  ]

  @type state() :: %__MODULE__{}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Amqpx.Gen.ConnectionManager)
  end

  def init(opts) do
    state = struct(__MODULE__, opts)
    Process.send(self(), :setup, [])
    {:ok, state}
  end

  def handle_call(:get_connection, _from, %{connection: connection} = state) do
    {:reply, connection, state}
  end

  def handle_info(:setup, %{backoff: backoff} = state) do
    {:noreply, broker_connect(state)}
  rescue
    exception in _ ->
      Logger.error(
        "Unable to connect to Broker! Retrying with #{backoff}ms backoff. Error: #{
          inspect(exception)
        }",
        error: inspect(exception)
      )

      :timer.sleep(backoff)
      {:stop, exception, state}
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    Logger.error("Monitored connection process crashed: #{inspect(reason)}")
    state = %{state | connection: nil}
    {:stop, :connection_exited, state}
  end

  def handle_info({:EXIT, _pid, :normal}, state), do: {:stop, :EXIT, state}

  def handle_info(message, state) do
    Logger.warn("Unknown message received #{inspect(message)}")
    {:noreply, state}
  end

  def terminate(_, %__MODULE__{connection: nil}), do: nil

  def terminate(_, %__MODULE__{connection: connection}) do
    if Process.alive?(connection.pid) do
      Process.exit(connection.pid, :kill)
    end
  end

  @spec broker_connect(state()) :: state()
  defp broker_connect(%__MODULE__{connection_params: connection_params} = state) do
    {:ok, connection} = Connection.open(connection_params)
    state = %{state | connection: connection}
    Process.monitor(connection.pid)

    state
  end
end
