defmodule ReturnTest do
  use ExUnit.Case

  alias Amqpx.{Basic, Confirm, Connection, Channel}

  setup do
    {:ok, conn} = Connection.open(Application.get_env(:amqpx, :amqp_connection))
    {:ok, chan} = Channel.open(conn)
    :ok = Confirm.select(chan)

    on_exit(fn ->
      :ok = Connection.close(conn)
    end)

    {:ok, conn: conn, chan: chan}
  end

  describe "register_return_handler" do
    setup ctx do
      :ok = Confirm.register_return_handler(ctx[:chan], self())
      {:ok, ctx}
    end

    test "handle correctly existenting queue message", ctx do
      exchange = ""
      routing_key = "non-existent-queue"
      payload = "foo"

      :ok = Basic.publish(ctx[:chan], exchange, routing_key, payload, mandatory: true)

      assert_receive {{:"basic.return", 312, "NO_ROUTE", ^exchange, ^routing_key},
                      {:amqp_msg, {:P_basic, _, _, _, 1, _, _, _, _, _, _, _, _, _, _}, ^payload}}

      :ok = Confirm.unregister_return_handler(ctx[:chan])

      :ok = Basic.publish(ctx[:chan], exchange, routing_key, payload, mandatory: true)

      refute_receive {:basic_return, _, _}
    end
  end
end
