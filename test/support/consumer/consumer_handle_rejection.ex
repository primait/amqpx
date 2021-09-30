defmodule Amqpx.Test.Support.HandleRejectionConsumer do
  @moduledoc nil
  @behaviour Amqpx.Gen.Consumer

  alias Amqpx.Basic
  alias Amqpx.Helper

  def setup(channel) do
    Helper.declare(channel, Application.fetch_env!(:amqpx, __MODULE__))
    Basic.consume(channel, Application.fetch_env!(:amqpx, __MODULE__)[:queue], self())
    {:ok, %{}}
  end

  def handle_message_rejection(_) do
    {:ok}
  end

  def handle_message(_payload, _meta, _state) do
    raise "test error"
  end
end
