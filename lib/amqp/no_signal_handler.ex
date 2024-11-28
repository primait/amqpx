defmodule Amqpx.NoSignalHandler do
  @moduledoc """
  Dummy signal handler module that does not handle the graceful termination.

  It always returns `false` for `draining?/0` and `stopping?/0`.
  I.e. the comsumer will continue without handling signals.
  """

  @behaviour Amqpx.SignalHandler

  @impl true
  def draining?, do: false

  @impl true
  def stopping?, do: false
end
