defmodule Amqpx.Test.AmqpxTest do
  use ExUnit.Case

  alias Amqpx.Test.Support.Consumer1
  alias Amqpx.Test.Support.Consumer2
  alias Amqpx.Test.Support.HandleRejectionConsumer
  alias Amqpx.Test.Support.NoRequeueConsumer
  alias Amqpx.Test.Support.ConsumerConnectionTwo
  alias Amqpx.Test.Support.Producer1
  alias Amqpx.Test.Support.Producer2
  alias Amqpx.Test.Support.Producer3
  alias Amqpx.Test.Support.ProducerConnectionTwo

  import Mock

  setup_all do
    Amqpx.Gen.ConnectionManager.start_link(%{
      connection_params: Application.fetch_env!(:amqpx, :amqp_connection)
    })

    Amqpx.Gen.ConnectionManager.start_link(%{
      connection_params: Application.fetch_env!(:amqpx, :amqp_connection_two)
    })

    {:ok, _} = Amqpx.Gen.Producer.start_link(Application.fetch_env!(:amqpx, :producer))
    {:ok, _} = Amqpx.Gen.Producer.start_link(Application.fetch_env!(:amqpx, :producer2))
    {:ok, _} = Amqpx.Gen.Producer.start_link(Application.fetch_env!(:amqpx, :producer_connection_two))

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

  test "e2e: should handle message rejected when handle message fails" do
    test_pid = self()

    with_mock(HandleRejectionConsumer,
      handle_message: fn _, _, _ ->
        mock_called =
          case Process.get(:times_mock_called) do
            nil -> 1
            n -> n + 1
          end

        Process.put(:times_mock_called, mock_called)

        raise "test_error ##{mock_called}"
      end,
      handle_message_rejection: fn _, error ->
        send(test_pid, {:ok, error.message})
      end
    ) do
      publish_result =
        Amqpx.Gen.Producer.publish("topic-rejection", "amqpx.test-rejection", "some-message", redeliver: false)

      assert publish_result == :ok

      # ensure handle_message_rejection is called only the second time
      assert_receive {:ok, "test_error #2"}, 1_000
    end
  end

  test "e2e: messages should not be re-enqueued when re-enqueue option is disabled" do
    test_pid = self()
    error_message = "test_error"

    with_mock(NoRequeueConsumer,
      handle_message: fn _, _, _ ->
        mock_called =
          case Process.get(:times_mock_called) do
            nil -> 1
            n -> n + 1
          end

        Process.put(:times_mock_called, mock_called)

        send(test_pid, {:handled_message, mock_called})
        raise error_message
      end,
      handle_message_rejection: fn _, _ -> :ok end
    ) do
      :ok = Amqpx.Gen.Producer.publish("topic-no-requeue", "amqpx.test-no-requeue", "some-message", redeliver: false)
      assert_receive {:handled_message, 1}
      refute_receive {:handled_message, 2}
    end
  end

  test "e2e: handle_message_reject should be called upon first time when re-enqueue option is disabled" do
    test_pid = self()
    error_message = "test-error-requeue"

    with_mock(NoRequeueConsumer,
      handle_message: fn _, _, _ ->
        mock_called =
          case Process.get(:times_mock_handle_message_called) do
            nil -> 1
            n -> n + 1
          end

        Process.put(:times_mock_handle_message_called, mock_called)

        raise "#{error_message} ##{mock_called}"
      end,
      handle_message_rejection: fn _, error ->
        mock_called =
          case Process.get(:times_mock_handle_message_rejection_called) do
            nil -> 1
            n -> n + 1
          end

        Process.put(:times_mock_handle_message_rejection_called, mock_called)

        send(test_pid, {:handled_message, {error.message, mock_called}})
        :ok
      end
    ) do
      :ok = Amqpx.Gen.Producer.publish("topic-no-requeue", "amqpx.test-no-requeue", "some-message", redeliver: false)

      # ensure the handle_message_rejection is called exactly one time after the handle_message call.
      err_msg = {"#{error_message} #1", 1}
      assert_receive {:handled_message, ^err_msg}
      refute_receive {:handled_message, _}, 1_000
    end
  end

  test "e2e: should publish and consume from the right connections" do
    payload = %{test: 1}

    with_mocks [
      {Consumer1, [], handle_message: fn _, _, s -> {:ok, s} end},
      {ConsumerConnectionTwo, [], handle_message: fn _, _, s -> {:ok, s} end}
    ] do
      Producer1.send_payload(payload)
      ProducerConnectionTwo.send_payload(payload)

      :timer.sleep(50)
      assert_called(Consumer1.handle_message(Jason.encode!(payload), :_, :_))
      assert_called(ConsumerConnectionTwo.handle_message(Jason.encode!(payload), :_, :_))
    end
  end
end
