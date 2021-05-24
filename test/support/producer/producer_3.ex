defmodule Amqpx.Test.Support.Producer3 do
  @moduledoc nil

  alias Amqpx.Gen.Producer

  @spec send_payload(map) :: :ok | :error
  def send_payload(payload) do
    Producer.publish("test_exchange", "", Jason.encode!(payload))
  end
end
