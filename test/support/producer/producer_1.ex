defmodule Amqpx.Test.Support.Producer1 do
  @moduledoc nil

  require Logger

  alias Amqpx.Producer

  @spec send_payload(map) :: :ok | :error
  def send_payload(payload) do
    Producer.publish(Jason.encode!(payload))
  end
end
