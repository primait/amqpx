defmodule Amqpx.Test.Support.Producer2 do
  @moduledoc nil

  require Logger

  alias Amqpx.Producer

  @spec send_payload(map) :: :ok | :error
  def send_payload(payload) do
    Producer.publish("topic2", "amqpx.test2", Jason.encode!(payload))
  end
end
