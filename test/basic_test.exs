defmodule BasicTest do
  use ExUnit.Case

  alias Amqpx.{Basic, Connection, Channel, Queue}

  setup do
    {:ok, conn} = Connection.open(Application.get_env(:amqpx, :amqp_connection))
    {:ok, chan} = Channel.open(conn)

    on_exit(fn ->
      :ok = Connection.close(conn)
    end)

    {:ok, conn: conn, chan: chan}
  end

  test "basic publish to default exchange", meta do
    assert :ok = Basic.publish(meta[:chan], "", "", "ping")
  end

  test "basic return", meta do
    :ok = Basic.return(meta[:chan], self())

    exchange = ""
    routing_key = "non-existent-queue"
    payload = "payload"

    Basic.publish(meta[:chan], exchange, routing_key, payload, mandatory: true)

    assert_receive {{:"basic.return", 312, "NO_ROUTE", ^exchange, ^routing_key},
                    {:amqp_msg, _, ^payload}}

    :ok = Basic.cancel_return(meta[:chan])

    Basic.publish(meta[:chan], exchange, routing_key, payload, mandatory: true)

    refute_receive {:basic_return, _payload, _properties}
  end

  describe "basic consume" do
    setup meta do
      {:ok, %{queue: queue}} = Queue.declare(meta[:chan])

      on_exit(fn ->
        if Process.alive?(meta[:chan].pid) do
          Queue.delete(meta[:chan], queue)
          Channel.close(meta[:chan])
        end
      end)

      {:ok, Map.put(meta, :queue, queue)}
    end

    test "consumer receives :basic_consume_ok message", meta do
      {:ok, consumer_tag} = Basic.consume(meta[:chan], meta[:queue], self())
      assert_receive {:"basic.consume_ok", ^consumer_tag}
      {:ok, ^consumer_tag} = Basic.cancel(meta[:chan], consumer_tag)
    end

    test "consumer receives :basic_deliver message", meta do
      {:ok, consumer_tag} = Basic.consume(meta[:chan], meta[:queue], self())

      payload = "foo"
      correlation_id = "correlation_id"
      exchange = ""
      routing_key = meta[:queue]

      Basic.publish(meta[:chan], exchange, routing_key, payload, correlation_id: correlation_id)

      assert_receive {{:"basic.deliver", ^consumer_tag, _, _, ^exchange, ^routing_key},
                      {:amqp_msg,
                       {:P_basic, _, _, _, _, _, ^correlation_id, _, _, _, _, _, _, _, _},
                       ^payload}}

      {:ok, ^consumer_tag} = Basic.cancel(meta[:chan], consumer_tag)
    end

    test "consumer receives :basic_cancel_ok message", meta do
      {:ok, consumer_tag} = Basic.consume(meta[:chan], meta[:queue], self())
      {:ok, ^consumer_tag} = Basic.cancel(meta[:chan], consumer_tag)

      assert_receive {:"basic.cancel_ok", ^consumer_tag}
    end

    test "consumer receives :basic_cancel message", meta do
      {:ok, consumer_tag} = Basic.consume(meta[:chan], meta[:queue], self())
      {:ok, _} = Queue.delete(meta[:chan], meta[:queue])

      assert_receive {:"basic.cancel", ^consumer_tag, true}
    end

    test "cancel returns {:ok, consumer_tag}", meta do
      {:ok, consumer_tag} = Basic.consume(meta[:chan], meta[:queue], self())

      assert {:ok, ^consumer_tag} = Basic.cancel(meta[:chan], consumer_tag)
    end

    test "cancel exits the process when channel is closed", meta do
      {:ok, consumer_tag} = Basic.consume(meta[:chan], meta[:queue], self())

      Channel.close(meta[:chan])

      Process.flag(:trap_exit, true)
      assert {:normal, _} = catch_exit(Basic.cancel(meta[:chan], consumer_tag))
    end
  end
end
