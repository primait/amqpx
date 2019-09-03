defmodule Amqpx.Example do
  @moduledoc false
  @behaviour Amqpx.Consumer
  require Logger

  def setup(_channel, _args) do
    {:ok, %{}}
  end

  def handle_message(payload, state) do
    Logger.info("Payload reiceived: #{inspect(payload)}")
    Logger.info("Current state: #{inspect(state)}")
    {:ok, %{}}

    # :error
  end
end
