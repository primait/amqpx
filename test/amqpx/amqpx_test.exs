defmodule Amqpx.Test.AmqpxTest do
  use ExUnit.Case
  use Amqpx.RabbitCase
  alias Amqpx.Test.Support.{Consumer1, Consumer2, Producer1, Producer2}

  import Mock

  test "e2e: should publish message and consume it" do
    payload = %{test: 1}

    with_mock(Consumer1, handle_message: fn _, s -> {:ok, s} end) do
      Producer1.send_payload(payload)
      :timer.sleep(50)
      assert_called(Consumer1.handle_message(Jason.encode!(payload), :_))
    end
  end

  test "e2e: should publish message and trigger the right consumer" do
    payload = %{test: 1}
    payload2 = %{test: 2}

    with_mock(Consumer1, handle_message: fn _, s -> {:ok, s} end) do
      with_mock(Consumer2, handle_message: fn _, s -> {:ok, s} end) do
        Producer1.send_payload(payload)
        :timer.sleep(50)
        assert_called(Consumer1.handle_message(Jason.encode!(payload), :_))
        refute called(Consumer2.handle_message(Jason.encode!(payload), :_))

        Producer2.send_payload(payload2)
        :timer.sleep(50)
        assert_called(Consumer2.handle_message(Jason.encode!(payload2), :_))
        refute called(Consumer1.handle_message(Jason.encode!(payload2), :_))
      end
    end
  end
end
