defmodule Amqpx.Test.AmqpxTest do
  use ExUnit.Case
  alias Amqpx.Test.Support.{Consumer1, Consumer2, Producer1, Producer2, Producer3}
  alias Amqpx.Helper
  import Mock

  setup_all do
    {_, producer} =
      Helper.producer_supervisor_configuration(
        Application.get_env(:amqpx, :producer),
        Application.get_env(:amqpx, :connection_params)
      )

    Amqpx.Producer.start_link(producer)

    Enum.each(
      Application.get_env(:amqpx, :consumers),
      &Amqpx.Consumer.start_link(
        Map.put(&1, :connection_params, Application.get_env(:amqpx, :connection_params))
      )
    )

    :timer.sleep(1_000)
    :ok
  end

  test "e2e: should publish message and consume it" do
    payload = %{test: 1}

    with_mock(Consumer1, handle_message: fn _, _, s -> {:ok, s} end) do
      Producer1.send_payload(payload)
      :timer.sleep(50)
      assert_called(Consumer1.handle_message(Jason.encode!(payload), :_, :_))
    end
  end

  test "e2e: should publish message and trigger the right consumer" do
    payload = %{test: 1}
    payload2 = %{test: 2}

    with_mock(Consumer1, handle_message: fn _, _, s -> {:ok, s} end) do
      with_mock(Consumer2, handle_message: fn _, _, s -> {:ok, s} end) do
        Producer1.send_payload(payload)
        :timer.sleep(50)
        assert_called(Consumer1.handle_message(Jason.encode!(payload), :_, :_))
        refute called(Consumer2.handle_message(Jason.encode!(payload), :_, :_))

        Producer2.send_payload(payload2)
        :timer.sleep(50)
        assert_called(Consumer2.handle_message(Jason.encode!(payload2), :_, :_))
        refute called(Consumer1.handle_message(Jason.encode!(payload2), :_, :_))
      end
    end
  end

  test "e2e: try to publish to an exchange defined in producer conf" do
    payload = %{test: 1}

    assert Producer3.send_payload(payload) === :ok
  end
end
