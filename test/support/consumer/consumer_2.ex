defmodule Amqpx.Test.Support.Consumer2 do
  @moduledoc nil

  @behaviour Amqpx.Consumer

  def setup(_channel) do
    {:ok, %{}}
  end

  def handle_message(payload, _state) do
    {:ok, Jason.decode!(payload)}
  end
end
