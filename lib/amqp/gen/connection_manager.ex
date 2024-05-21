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

  def start_link(%{connection_params: connection_params} = opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(connection_params, :name, Amqpx.Gen.ConnectionManager))
  end

  def init(opts) do
    Process.flag(:trap_exit, true)
    state = struct(__MODULE__, opts)
    Process.send(self(), :setup, [])
    {:ok, state}
  end

  def handle_call(:get_connection, _from, %{connection: connection} = state) do
    {:reply, connection, state}
  end

  def handle_info(:setup, %{backoff: backoff, connection_params: connection_params} = state) do
    case connect(connection_params) do
      {:ok, connection} ->
        state = %{state | connection: connection}
        {:noreply, state}

      error ->
        Logger.error("Unable to connect to Broker! Retrying with #{backoff}ms backoff",
          error: inspect(error)
        )

        Process.send_after(self(), {:shutdown, error}, backoff, [])
        {:noreply, state}
    end
  end

  def handle_info({:shutdown, reason}, state) do
    {:stop, reason, state}
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    Logger.error("Monitored connection process crashed: #{inspect(reason)}")
    state = %{state | connection: nil}
    {:stop, :connection_exited, state}
  end

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

  @spec connect(map) :: {:ok, Connection.t()} | {:error, any}
  defp connect(connection_params) do
    with {:ok, connection} <- Connection.open(connection_params) do
      Process.monitor(connection.pid)

      {:ok, connection}
    end
  catch
    _, reason ->
      {:error, reason}
  end
end
