defmodule Amqpx.Test.AmqpxTest do
  use ExUnit.Case

  alias Amqpx.Test.Support.Consumer1
  alias Amqpx.Test.Support.Consumer2
  alias Amqpx.Test.Support.Producer1
  alias Amqpx.Test.Support.Producer2
  alias Amqpx.Test.Support.Producer3

  import Mock

  setup_all do
    Amqpx.Gen.ConnectionManager.start_link(%{
      connection_params: Application.fetch_env!(:amqpx, :amqp_connection)
    })

    {:ok, _} = Amqpx.Gen.Producer.start_link(Application.fetch_env!(:amqpx, :producer))
    {:ok, _} = Amqpx.Gen.Producer.start_link(Application.fetch_env!(:amqpx, :producer2))

    Enum.each(Application.fetch_env!(:amqpx, :consumers), &Amqpx.Gen.Consumer.start_link(&1))

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

  test "e2e: publish messages using more than one registered producer" do
    test_pid = self()

    with_mock(Consumer1,
      handle_message: fn p, _, s ->
        send(test_pid, {:consumer1_msg, p})
        {:ok, s}
      end
    ) do
      with_mock(Consumer2,
        handle_message: fn p, _, s ->
          send(test_pid, {:consumer2_msg, p})
          {:ok, s}
        end
      ) do
        publish_1_result = Amqpx.Gen.Producer.publish("topic1", "amqpx.test1", "some-message")
        publish_2_result = Amqpx.Gen.Producer.publish_by(:producer2, "topic2", "amqpx.test2", "some-message-2")

        assert publish_1_result == :ok
        assert publish_2_result == :ok
        assert_receive {:consumer1_msg, "some-message"}
        assert_receive {:consumer2_msg, "some-message-2"}
        refute_receive {:consumer1_msg, "some-message-2"}
        refute_receive {:consumer2_msg, "some-message"}
      end
    end
  end
end
