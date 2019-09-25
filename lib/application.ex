defmodule Amqpx.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec, warn: false

  alias Amqpx.Helper

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    children =
      Enum.concat(
        [
          Helper.producer_supervisor_configuration(
            Application.get_env(:amqpx, :producer),
            Application.get_env(:amqpx, :connection_params)
          )
        ],
        Helper.consumers_supervisor_configuration(
          Application.get_env(:amqpx, :consumers),
          Application.get_env(:amqpx, :connection_params)
        )
      )

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Amqpx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
