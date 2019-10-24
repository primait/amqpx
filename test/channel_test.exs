defmodule ChannelTest do
  use ExUnit.Case

  alias Amqpx.Connection
  alias Amqpx.Channel

  setup do
    {:ok, conn} = Connection.open(Application.get_env(:amqpx, :amqp_connection))
    on_exit(fn -> :ok = Connection.close(conn) end)
    {:ok, conn: conn}
  end

  test "open channel", meta do
    assert {:ok, chan} = Channel.open(meta[:conn])
    assert :ok = Channel.close(chan)
  end
end
