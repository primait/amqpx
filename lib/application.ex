defmodule Amqpx.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [] ++ consumers() ++ producers()

    opts = [strategy: :one_for_one, name: Amqpx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp consumers() do
    Enum.map(Application.get_env(:amqpx, :consumers), fn conf -> {Amqpx.Consumer, conf} end)
  end

  defp producers() do
    Enum.map(Application.get_env(:amqpx, :producers), fn conf -> {Amqpx.Producer, conf} end)
  end
end
