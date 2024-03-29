defmodule Amqpx.Test.Support.ProducerWithRetry do
  @moduledoc nil

  alias Amqpx.Gen.Producer

  @spec send_payload_with_publish_error(map) :: :ok | :error
  def send_payload_with_publish_error(payload) do
    Producer.publish_by(
      :producer_with_retry_on_publish_error,
      "test_exchange_with_retry",
      "amqpx.test1",
      Jason.encode!(payload)
    )
  end

  @spec send_payload_without_publish_error(map) :: :ok | :error
  def send_payload_without_publish_error(payload), do: send_payload_with_publish_rejected(payload)

  def send_payload_with_publish_rejected(payload) do
    Producer.publish_by(
      :producer_with_retry_on_publish_rejected,
      "test_exchange_with_retry",
      "amqpx.test1",
      Jason.encode!(payload)
    )
  end

  @spec send_payload_without_publish_rejected(map) :: :ok | :error
  def send_payload_without_publish_rejected(payload), do: send_payload_with_publish_error(payload)

  def send_payload_with_publish_confirm_delivery_timeout(payload) do
    Producer.publish_by(
      :producer_with_retry_on_confirm_delivery_timeout,
      "test_exchange_with_retry",
      "amqpx.test1",
      Jason.encode!(payload)
    )
  end

  def send_payload_with_publish_confirm_delivery_timeout_and_on_publish_error(payload) do
    Producer.publish_by(
      :producer_with_retry_on_confirm_delivery_timeout_and_on_publish_error,
      "test_exchange_with_retry",
      "amqpx.test1",
      Jason.encode!(payload)
    )
  end

  def send_payload_with_jittered_backoff(payload) do
    Producer.publish_by(
      :producer_with_jittered_backoff,
      "test_exchange_with_retry",
      "amqpx.test1",
      Jason.encode!(payload)
    )
  end
end
