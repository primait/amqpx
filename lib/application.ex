defmodule Amqpx.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children =
      consumers(Application.get_env(:amqpx, :consumers)) ++
        producers(Application.get_env(:amqpx, :producers))

    opts = [strategy: :one_for_one, name: Amqpx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp consumers(nil) do
    []
  end

  defp consumers(configs) do
    Enum.map(configs, fn conf -> {Amqpx.Consumer, conf} end)
  end

  defp producers(nil) do
    []
  end

  defp producers(configs) do
    Enum.map(configs, fn conf -> {Amqpx.Producer, conf} end)
  end
end
