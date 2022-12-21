defmodule HelperTest do
  use ExUnit.Case

  alias Amqpx.{Channel, Connection, Queue, Exchange, Helper}

  setup do
    {:ok, conn} = Connection.open(Application.fetch_env!(:amqpx, :amqp_connection))
    {:ok, chan} = Channel.open(conn)
    on_exit(fn -> :ok = Connection.close(conn) end)
    {:ok, conn: conn, chan: chan}
  end

  test "declare a queue with a bind to an exchange and a dead letter queue with an errored exchange", meta do
    queue_name = rand_name()
    routing_key_name = rand_name()
    exchange_name = rand_name()

    queue_name_errored = "#{queue_name}_errored"
    exchange_name_errored = "#{exchange_name}_errored"

    assert :ok =
             Helper.declare(meta[:chan], %{
               exchanges: [
                 %{name: exchange_name, opts: [durable: true], routing_keys: [routing_key_name], type: :topic}
               ],
               opts: [
                 durable: true,
                 arguments: [
                   {"x-dead-letter-exchange", :longstr, exchange_name_errored},
                   {"x-dead-letter-routing-key", :longstr, routing_key_name}
                 ]
               ],
               queue: queue_name
             })

    assert :ok = Queue.unbind(meta[:chan], queue_name, exchange_name)
    assert :ok = Queue.unbind(meta[:chan], queue_name_errored, exchange_name_errored)
    assert :ok = Exchange.delete(meta[:chan], exchange_name)
    assert :ok = Exchange.delete(meta[:chan], exchange_name_errored)
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue_name)
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue_name_errored)
  end

  test "configuration without an exchange and with routing key set with correct dead letter queue should not raise an error",
       meta do
    queue_name = rand_name()
    routing_key_name = rand_name()
    exchange_name = rand_name()

    queue_name_errored = "#{queue_name}_errored"

    assert :ok =
             Helper.declare(meta[:chan], %{
               exchanges: [
                 %{name: exchange_name, opts: [durable: true], routing_keys: [routing_key_name], type: :topic}
               ],
               opts: [
                 durable: true,
                 arguments: [
                   {"x-dead-letter-exchange", :longstr, ""},
                   {"x-dead-letter-routing-key", :longstr, queue_name_errored}
                 ]
               ],
               queue: queue_name
             })

    assert :ok = Queue.unbind(meta[:chan], queue_name, exchange_name)
    assert :ok = Exchange.delete(meta[:chan], exchange_name)
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue_name)
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue_name_errored)
  end

  test "bad configuration with dead letter exchange empty and routing key set should raise an error", meta do
    queue_name = rand_name()
    routing_key_name = rand_name()
    exchange_name = rand_name()

    queue_name_errored = "BadDeadLetterQueue"

    assert_raise RuntimeError,
                 "Configuring x-dead-letter-exchange with empty string, x-dead-letter-routing-key should be '#{queue_name}_errored' instead of '#{queue_name_errored}'",
                 fn ->
                   Helper.declare(meta[:chan], %{
                     exchanges: [
                       %{name: exchange_name, opts: [durable: true], routing_keys: [routing_key_name], type: :topic}
                     ],
                     opts: [
                       durable: true,
                       arguments: [
                         {"x-dead-letter-exchange", :longstr, ""},
                         {"x-dead-letter-routing-key", :longstr, queue_name_errored}
                       ]
                     ],
                     queue: queue_name
                   })
                 end
  end

  test "bad configuration with empty dead letter exchange and routing key should raise an error", meta do
    queue_name = rand_name()
    routing_key_name = rand_name()
    exchange_name = rand_name()

    assert_raise RuntimeError,
                 "Configuring x-dead-letter-exchange with empty string, x-dead-letter-routing-key should be '#{queue_name}_errored' instead of ''",
                 fn ->
                   Helper.declare(meta[:chan], %{
                     exchanges: [
                       %{name: exchange_name, opts: [durable: true], routing_keys: [routing_key_name], type: :topic}
                     ],
                     opts: [
                       durable: true,
                       arguments: [
                         {"x-dead-letter-exchange", :longstr, ""},
                         {"x-dead-letter-routing-key", :longstr, ""}
                       ]
                     ],
                     queue: queue_name
                   })
                 end
  end

  defp rand_name do
    :crypto.strong_rand_bytes(8) |> Base.encode64()
  end
end
