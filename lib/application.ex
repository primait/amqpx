defmodule Amqpx.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec, warn: false

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    children =
      [
        producers()
      ]
      |> Kernel.++(consumers())

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Amqpx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def consumers() do
    Enum.map(
      Application.get_env(:amqpx, :consumers),
      &Supervisor.child_spec({Amqpx.Consumer, &1}, id: UUID.uuid1())
    )
  end

  def consumers(_), do: []

  def producers() do
    {Amqpx.Producer, Application.get_env(:amqpx, :producer)}
  end
end
