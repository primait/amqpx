defmodule Amqpx.RabbitCase do
  @moduledoc """
  modulo da usare per i test con rabbit,
  cancella le code dopo i test
  """
  use ExUnit.CaseTemplate

  @queues ~w(test1 test2 test1_errored test2_errored)

  setup do
    on_exit(fn ->
      use AMQP

      {:ok, connection} =
        Connection.open(Application.get_env(:amqpx, :broker)[:connection_params])

      {:ok, channel} = Channel.open(connection)
      Enum.each(@queues, &Queue.purge(channel, &1))
    end)

    :ok
  end
end
