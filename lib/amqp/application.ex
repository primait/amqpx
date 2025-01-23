defmodule Amqpx.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      %{
        id: Amqpx.SignalHandler,
        start: {Amqpx.SignalHandler, :start_link, []}
      }
    ]

    opts = [strategy: :one_for_one, name: Amqpx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
