defmodule BasicTest do
  use ExUnit.Case

  alias Amqpx.Gen.Consumer
  alias Amqpx.{Basic, Channel}

  import Mock
  import Amqpx.Core

  describe "Amqpx.Gen.Consumer" do
    test "handle basic ack automatically by default", _meta do
      with_mocks([
        {GenServer, [], call: fn _, _ -> %{} end},
        {Channel, [], open: fn _, _ -> {:ok, %{pid: self()}} end},
        {Basic, [], qos: fn _, _ -> :ok end}
      ]) do
        assert {:noreply, %Consumer{autoack: true}} =
                 Consumer.handle_info(:setup, %Consumer{handler_module: __MODULE__})
      end

      with_mock(Basic, ack: fn _, _ -> :ok end) do
        Consumer.handle_info(
          {
            basic_deliver(delivery_tag: "the_tag", redelivered: "redelivered"),
            amqp_msg()
          },
          %Consumer{handler_module: __MODULE__, autoack: true, channel: "channel"}
        )

        assert_called(Basic.ack("channel", "the_tag"))
      end
    end

    test "can be configured by consumers" do
      with_mocks([
        {GenServer, [], call: fn _, _ -> %{} end},
        {Channel, [], open: fn _, _ -> {:ok, %{pid: self()}} end},
        {Basic, [], qos: fn _, _ -> :ok end}
      ]) do
        assert {:noreply, %Consumer{autoack: false}} =
                 Consumer.handle_info(:setup, %Consumer{handler_module: __MODULE__, autoack: false})
      end
    end

    test "doesn't ack with autoack set to false" do
      with_mock(Basic, ack: fn _, _ -> :ok end) do
        Consumer.handle_info(
          {
            basic_deliver(delivery_tag: "the_tag", redelivered: "redelivered"),
            amqp_msg()
          },
          %Consumer{autoack: false, handler_module: __MODULE__, channel: "channel"}
        )

        assert_not_called(Basic.ack(:_, :_))
      end
    end
  end

  def setup(_channel) do
    {:ok, %{}}
  end

  def handle_message(_message, _meta, state) do
    {:ok, state}
  end
end
