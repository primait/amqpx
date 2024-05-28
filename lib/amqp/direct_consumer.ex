defmodule Amqpx.DirectConsumer do
  @moduledoc """
  This module "wraps" the [amqp_direct_consumer](https://github.com/rabbitmq/rabbitmq-server/blob/main/deps/amqp_client/src/amqp_direct_consumer.erl) module to manage the race condition that occurs at supervisor shutdown, leading to error logs such as:
  ```
  [error] GenServer #PID<0.846.0> terminating
  ** (stop) {:error, {:consumer_died, :shutdown}}
  Last message: {:DOWN, #Reference<0.1010163881.3799777283.106124>, :process, #PID<0.798.0>, :shutdown}.
  ```
  The reason for this behavior is that the `amqp_direct_consumer` module considers any exit reason other than `:normal` as an error, prompting it to exit.
  In our implementation, we have introduced two pattern matches to treat the exit reasons `:shutdown` and `{:shutdown, reason}` as normal occurrences; these conditions typically arise when the supervisor terminates the consumer, such as during a standard shutdown of the application."
  """

  @behaviour :amqp_gen_consumer

  defdelegate init(opts), to: :amqp_direct_consumer

  defdelegate handle_consume(m, a, c), to: :amqp_direct_consumer

  defdelegate handle_consume_ok(m, a, c), to: :amqp_direct_consumer

  defdelegate handle_cancel(m, c), to: :amqp_direct_consumer

  defdelegate handle_cancel_ok(m, a, c), to: :amqp_direct_consumer

  defdelegate handle_server_cancel(m, c), to: :amqp_direct_consumer

  defdelegate handle_deliver(m, a, c), to: :amqp_direct_consumer

  defdelegate handle_deliver(m, a, delivery_ctx, c), to: :amqp_direct_consumer

  defdelegate handle_call(m, a, c), to: :amqp_direct_consumer

  defdelegate terminate(reason, c), to: :amqp_direct_consumer

  def handle_info({:DOWN, _mref, :process, c, :shutdown}, c) do
    {:ok, c}
  end

  def handle_info({:DOWN, _mref, :process, c, {:shutdown, _}}, c) do
    {:ok, c}
  end

  def handle_info(m, c) do
    :amqp_direct_consumer.handle_info(m, c)
  end
end
