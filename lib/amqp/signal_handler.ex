defmodule Amqpx.SignalHandler do
  @moduledoc """
  This module is responsible for handling signals sent to the application.
  """
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, :running}
  end

  def draining do
    GenServer.call(__MODULE__, :draining)
  end

  def stopping do
    GenServer.call(__MODULE__, :stopping)
  end

  def get_signal_status do
    GenServer.call(__MODULE__, :get_signal_status)
  end

  def handle_call(:draining, _from, _state) do
    {:reply, :ok, :draining}
  end

  def handle_call(:stopping, _from, _state) do
    {:reply, :ok, :stopping}
  end

  def handle_call(:get_signal_status, _from, state) do
    {:reply, state, state}
  end
end
