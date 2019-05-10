defmodule Amqpx.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children =
      consumers(Application.get_env(:amqpx, :consumers) || []) ++
        producers(Application.get_env(:amqpx, :producers) || [])

    opts = [strategy: :one_for_one, name: Amqpx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp consumers(configs) do
    Enum.map(configs, &Supervisor.child_spec({Amqpx.Consumer, &1}, id: UUID.uuid1()))
  end

  defp producers(configs) do
    Enum.map(configs, &Supervisor.child_spec({Amqpx.Producer, &1}, id: UUID.uuid1()))
  end
end
