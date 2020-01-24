defmodule ConfirmTest do
  use ExUnit.Case

  alias Amqpx.Connection
  alias Amqpx.Channel
  alias Amqpx.Confirm

  setup do
    {:ok, conn} = Connection.open(Application.get_env(:amqpx, :amqp_connection))
    {:ok, chan} = Channel.open(conn)
    :ok = Confirm.select(chan)

    on_exit(fn ->
      :ok = Connection.close(conn)
    end)

    {:ok, chan: chan}
  end

  describe "next_publish_seqno" do
    test "returns 1 whe no messages where sent", ctx do
      assert 1 == Confirm.next_publish_seqno(ctx[:chan])
    end
  end

  describe "register_confirm_handler" do
    test "handler receive confirm with message seqno", ctx do
      :ok = Confirm.register_confirm_handler(ctx[:chan], self())
      seq_no = Confirm.next_publish_seqno(ctx[:chan])
      :ok = Amqpx.Basic.publish(ctx[:chan], "", "", "foo")

      assert_receive {:"basic.ack", ^seq_no, false}
      :ok = Confirm.unregister_confirm_handler(ctx[:chan])
    end
  end

  describe "unregister_confirm_handler" do
    setup ctx do
      :ok = Confirm.register_confirm_handler(ctx[:chan], self())
      {:ok, ctx}
    end

    test "handler no more receive confirm", ctx do
      :ok = Confirm.unregister_confirm_handler(ctx[:chan])
      :ok = Amqpx.Basic.publish(ctx[:chan], "", "", "foo")
      refute_receive {:basic_ack, 1, false}
    end
  end

  describe "register_return_handler" do
  end

  describe "unregister_return_handler" do
  end

  describe "register_flow_handler" do
  end

  describe "unregister_flow_handler" do
  end
end
