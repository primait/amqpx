defmodule Amqpx.Test.Support.ProducerConnectionTwo do
  @moduledoc nil

  alias Amqpx.Gen.Producer

  @spec send_payload(map) :: :ok | :error
  def send_payload(payload) do
    publisher_name = :amqpx |> Application.fetch_env!(:producer_connection_two) |> Map.fetch!(:name)
    Producer.publish_by(publisher_name, "connection-two", "amqpx.test_connection_two", Jason.encode!(payload))
  end
end
