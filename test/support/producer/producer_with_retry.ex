defmodule Amqpx.Test.Support.ProducerWithRetry do
  @moduledoc nil

  alias Amqpx.Gen.Producer

  @spec send_payload(map) :: :ok | :error
  def send_payload(payload) do
    Producer.publish_by(
      :producer_with_retry_on_publish_error,
      "test_exchange_with_retry",
      "amqpx.test1",
      Jason.encode!(payload)
    )
  end

  def send_payload_with_publish_rejected(payload) do
    Producer.publish_by(
      :producer_with_retry_on_publish_rejected,
      "test_exchange_with_retry",
      "amqpx.test1",
      Jason.encode!(payload)
    )
  end
end
