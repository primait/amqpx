defmodule Amqpx.Test.AmqpxTest do
  alias Amqpx.Test.Support.Producer1

  import Mock

  test "e2e: should publish message and consume it" do
    payload = %{test: 1}

    Producer1.publish(payload)

    with_mock(Amqpx.Test.Support.Consumer1,
      handle_message: fn input_payload, _ ->
        assert Jason.decode!(input_payload, keys: :atoms) == payload
      end
    )
  end
end
