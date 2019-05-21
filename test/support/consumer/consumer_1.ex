defmodule Amqpx.Test.Support.Consumer1 do
  @moduledoc nil

  @behaviour Amqpx.Consumer

  def setup(_channel) do
    {:ok, %{}}
  end

  def handle_message(_payload, state) do
    {:ok, state}
  end
end
