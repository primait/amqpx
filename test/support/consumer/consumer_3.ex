defmodule Amqpx.Test.Support.Consumer3 do
  @moduledoc nil
  @behaviour Amqpx.Gen.Consumer

  alias Amqpx.Basic
  alias Amqpx.Helper

  @config Application.get_env(:amqpx, __MODULE__)
  @queue Application.get_env(:amqpx, __MODULE__)[:queue]

  def setup(channel) do
    Helper.declare(channel, @config)
    Basic.consume(channel, @queue, self())
    {:ok, %{}}
  end

  def handle_message(_payload, _meta, state) do
    {:ok, state}
  end
end
