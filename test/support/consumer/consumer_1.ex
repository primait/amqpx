defmodule Amqpx.Test.Support.Consumer1 do
  @moduledoc nil

  @behaviour Amqpx.Consumer

  def setup(_channel, args) do
    IO.inspect args
    {:ok, %{}}
  end

  def handle_message(_payload, state) do
    {:ok, state}
  end
end
