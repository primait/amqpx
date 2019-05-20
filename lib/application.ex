defmodule Amqpx.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children =
      consumers(Application.get_env(:amqpx, :consumers) || []) ++
        producer(Application.get_env(:amqpx, :producer) || [])

    opts = [strategy: :one_for_one, name: Amqpx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp consumers(configs) do
    Enum.map(configs, &Supervisor.child_spec({Amqpx.Consumer, &1}, id: UUID.uuid1()))
  end

  defp producer(config) do
    Supervisor.child_spec({Amqpx.Producer, Keyword.get(config, :exchanges)}, [])
  end
end
