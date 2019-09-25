defmodule Amqpx.Test.Support.Consumer2 do
  @moduledoc nil
  @behaviour Amqpx.Consumer

  alias AMQP.Basic
  alias Amqpx.Helper

  @config Application.get_env(:amqpx, __MODULE__)
  @queue Application.get_env(:amqpx, __MODULE__)[:name]

  def setup(channel) do
    Helper.declare_queue(channel, @config)
    Basic.consume(channel, @queue)
    {:ok, %{}}
  end

  def handle_message(_payload, _meta, state) do
    {:ok, state}
  end
end
