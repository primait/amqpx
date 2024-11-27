defmodule Amqpx.NoSignalHandler do
  @moduledoc """
  Dummy signal handler module that does handle the graceful termination.
  """

  @behaviour Amqpx.SignalHandler

  @impl true
  def draining?, do: false

  @impl true
  def stopping?, do: false
end
