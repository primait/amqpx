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
  alias Amqpx.Test.Support.ProducerWithRetry
  alias Amqpx.Test.Support.ProducerConnectionTwo

  import Mock

  setup_all do
    start_supervised!(%{
      id: :amqp_connection,
      start:
        {Amqpx.Gen.ConnectionManager, :start_link,
         [%{connection_params: Application.fetch_env!(:amqpx, :amqp_connection)}]}
    })

    start_supervised!(%{
      id: :amqp_connection_two,
      start:
        {Amqpx.Gen.ConnectionManager, :start_link,
         [%{connection_params: Application.fetch_env!(:amqpx, :amqp_connection_two)}]}
    })

    start_supervised!(%{
      id: :producer,
      start: {Amqpx.Gen.Producer, :start_link, [Application.fetch_env!(:amqpx, :producer)]}
    })

    start_supervised!(%{
      id: :producer2,
      start: {Amqpx.Gen.Producer, :start_link, [Application.fetch_env!(:amqpx, :producer2)]}
    })

    start_supervised!(%{
      id: :producer_connection_two,
      start: {Amqpx.Gen.Producer, :start_link, [Application.fetch_env!(:amqpx, :producer_connection_two)]}
    })

    start_supervised!(%{
      id: :producer_with_retry_on_publish_error,
      start: {Amqpx.Gen.Producer, :start_link, [Application.fetch_env!(:amqpx, :producer_with_retry_on_publish_error)]}
    })

    start_supervised!(%{
      id: :producer_with_retry_on_publish_rejected,
      start:
        {Amqpx.Gen.Producer, :start_link, [Application.fetch_env!(:amqpx, :producer_with_retry_on_publish_rejected)]}
    })

    start_supervised!(%{
      id: :producer_with_retry_on_confirm_delivery_timeout,
      start:
        {Amqpx.Gen.Producer, :start_link,
         [Application.fetch_env!(:amqpx, :producer_with_retry_on_confirm_delivery_timeout)]}
    })

    start_supervised!(%{
      id: :producer_with_retry_on_confirm_delivery_timeout_and_on_publish_error,
      start:
        {Amqpx.Gen.Producer, :start_link,
         [
           Application.fetch_env!(
             :amqpx,
             :producer_with_retry_on_confirm_delivery_timeout_and_on_publish_error
           )
         ]}
    })

    start_supervised!(%{
      id: :producer_with_exponential_backoff,
      start:
        {Amqpx.Gen.Producer, :start_link,
         [
           Application.fetch_env!(
             :amqpx,
             :producer_with_exponential_backoff
           )
         ]}
    })

    Application.fetch_env!(:amqpx, :consumers)
    |> Enum.with_index()
    |> Enum.each(fn {opts, id} ->
      start_supervised!(%{
        id: :"consumer_#{id}",
        start: {Amqpx.Gen.Consumer, :start_link, [opts]}
      })
    end)

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

  describe "when publish retry configurations are enabled" do
    test "should retry publish in case of publish error" do
      payload = %{test: 1}

      with_mock(Amqpx.Basic,
        publish: fn _channel, _exchange, _routing_key, _payload, _options ->
          case Process.get(:times_mock_publish_called) do
            nil ->
              Process.put(:times_mock_publish_called, 1)
              {:error, :fail}

            1 ->
              :ok
          end
        end
      ) do
        assert :ok = ProducerWithRetry.send_payload_with_publish_error(payload)
        assert_called_exactly(Amqpx.Basic.publish(:_, :_, :_, :_, :_), 2)
      end
    end

    test "should not retry publish in case of publish error if on_publish_error retry_policy is not set" do
      payload = %{test: 1}

      with_mock(Amqpx.Basic,
        publish: fn _channel, _exchange, _routing_key, _payload, _options ->
          {:error, :blocked}
        end
      ) do
        assert :error = ProducerWithRetry.send_payload_without_publish_error(payload)
        assert_called_exactly(Amqpx.Basic.publish(:_, :_, :_, :_, :_), 1)
      end
    end

    test "should retry publish in case of publish rejection" do
      payload = %{test: 1}

      with_mock(Amqpx.Confirm,
        wait_for_confirms: fn _channel, _timeout ->
          case Process.get(:times_mock_publish_rejected_called) do
            nil ->
              Process.put(:times_mock_publish_rejected_called, 1)
              false

            1 ->
              true
          end
        end
      ) do
        assert :ok = ProducerWithRetry.send_payload_with_publish_rejected(payload)
        assert_called_exactly(Amqpx.Confirm.wait_for_confirms(:_, :_), 2)
      end
    end

    test "should not retry publish in case of publish rejection if on_publish_rejected retry_policy is not set" do
      payload = %{test: 1}

      with_mock(Amqpx.Confirm,
        wait_for_confirms: fn _channel, _timeout ->
          false
        end
      ) do
        assert :error = ProducerWithRetry.send_payload_without_publish_rejected(payload)
        assert_called_exactly(Amqpx.Confirm.wait_for_confirms(:_, :_), 1)
      end
    end

    test "should retry publish in case of confirm delivery timeout" do
      payload = %{test: 1}

      with_mocks([
        {
          Amqpx.Basic,
          [],
          [
            publish: fn _channel, _exchange, _routing_key, _payload, _options ->
              :ok
            end
          ]
        },
        {
          Amqpx.Confirm,
          [],
          [
            wait_for_confirms: fn _channel, _timeout ->
              case Process.get(:times_mock_publish_confirm_delivery_timeout_called) do
                nil ->
                  Process.put(:times_mock_publish_confirm_delivery_timeout_called, 1)
                  :timeout

                1 ->
                  true
              end
            end
          ]
        }
      ]) do
        assert :ok = ProducerWithRetry.send_payload_with_publish_confirm_delivery_timeout(payload)
        assert_called_exactly(Amqpx.Confirm.wait_for_confirms(:_, :_), 2)
        assert_called_exactly(Amqpx.Basic.publish(:_, :_, :_, :_, :_), 2)
      end
    end

    test "should retry publish in case of confirm delivery timeout and on publish error" do
      payload = %{test: 1}

      with_mocks([
        {
          Amqpx.Basic,
          [],
          [
            publish: fn _channel, _exchange, _routing_key, _payload, _options ->
              case Process.get(:times_mock_publish_confirm_delivery_timeout_and_on_publish_error_called) do
                nil ->
                  Process.put(
                    :times_mock_publish_confirm_delivery_timeout_and_on_publish_error_called,
                    :first_publish_fail
                  )

                  {:error, :fail}

                :first_publish_fail ->
                  Process.put(
                    :times_mock_publish_confirm_delivery_timeout_and_on_publish_error_called,
                    :first_confirm_fail
                  )

                  :ok

                :publish_and_confirm_ok ->
                  :ok
              end
            end
          ]
        },
        {
          Amqpx.Confirm,
          [],
          [
            wait_for_confirms: fn _channel, _timeout ->
              case Process.get(:times_mock_publish_confirm_delivery_timeout_and_on_publish_error_called) do
                :first_confirm_fail ->
                  Process.put(
                    :times_mock_publish_confirm_delivery_timeout_and_on_publish_error_called,
                    :publish_and_confirm_ok
                  )

                  :timeout

                :publish_and_confirm_ok ->
                  true
              end
            end
          ]
        }
      ]) do
        assert :ok = ProducerWithRetry.send_payload_with_publish_confirm_delivery_timeout_and_on_publish_error(payload)

        assert_called_exactly(Amqpx.Basic.publish(:_, :_, :_, :_, :_), 3)
        assert_called_exactly(Amqpx.Confirm.wait_for_confirms(:_, :_), 2)
      end
    end
  end

  test "test retry configurations" do
    payload = %{test: 1}

    with_mock(Amqpx.Basic,
      publish: fn _channel, _exchange, _routing_key, _payload, _options ->
        case Process.get(:times_mock_publish_called_2) do
          nil ->
            Process.put(:times_mock_publish_called_2, 2)
            {:error, :fail}

          5 ->
            :ok

          n ->
            Process.put(:times_mock_publish_called_2, n + 1)
            {:error, :fail}
        end
      end
    ) do
      assert :ok = ProducerWithRetry.send_payload_with_publish_error(payload)
      assert_called_exactly(Amqpx.Basic.publish(:_, :_, :_, :_, :_), 5)
    end
  end

  describe "when publish retry configurations are not enabled" do
    test "should not retry publish in case of error" do
      payload = %{test: 1}

      with_mock(Amqpx.Basic,
        publish: fn _channel, _exchange, _routing_key, _payload, _options ->
          {:error, :fail}
        end
      ) do
        assert :error = Producer1.send_payload(payload)
        assert_called_exactly(Amqpx.Basic.publish(:_, :_, :_, :_, :_), 1)
      end
    end
  end

  describe "configuration validation" do
    test "if retry_policy is configured, max_retries must be > 0" do
      assert {:error, {:invalid_configuration, "when retry policy is configured, max_retries must be > 0"}} =
               Amqpx.Gen.Producer.start_link(%{
                 name: :producer_misconfigured_retry_policy_max_retries,
                 exchanges: [
                   %{
                     name: "test_exchange_misconfigured_retry_policy_max_retries",
                     type: :topic,
                     opts: [durable: true]
                   }
                 ],
                 publish_retry_options: [
                   max_retries: 0,
                   retry_policy: [
                     :on_publish_error
                   ]
                 ]
               })
    end

    test "if retry_policy is configured, max_retries must be set" do
      assert {:error, {:invalid_configuration, "when retry policy is configured, max_retries must be > 0"}} =
               Amqpx.Gen.Producer.start_link(%{
                 name: :producer_misconfigured_retry_policy_max_retries,
                 exchanges: [
                   %{
                     name: "test_exchange_misconfigured_retry_policy_max_retries",
                     type: :topic,
                     opts: [durable: true]
                   }
                 ],
                 publish_retry_options: [
                   retry_policy: [
                     :on_publish_error
                   ]
                 ]
               })
    end
  end

  describe "exponential backoff validation" do
    test "should be invoked the configured number of times" do
      payload = %{test: 1}

      with_mocks([
        {
          Amqpx.Basic,
          [],
          [
            publish: fn _channel, _exchange, _routing_key, _payload, _options ->
              {:error, :fail}
            end
          ]
        },
        {
          Amqpx.Backoff.Exponential,
          [],
          [
            backoff: fn
              1,
              %{
                base_backoff_in_ms: 10,
                max_backoff_in_ms: 100
              } ->
                :ok

              2,
              %{
                base_backoff_in_ms: 10,
                max_backoff_in_ms: 100
              } ->
                :ok
            end
          ]
        }
      ]) do
        assert :error = ProducerWithRetry.send_payload_with_exponential_backoff(payload)
        assert_called_exactly(Amqpx.Backoff.Exponential.backoff(:_, :_), 2)
      end
    end
  end
end
