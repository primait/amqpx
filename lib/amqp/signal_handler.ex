defmodule Amqpx.SignalHandler do
  @moduledoc """
  Signal handler behaviour is used to catch the SIGTERM signal and gracefully stop the application.
  In the context of Rabbitmq, it will:
    cancel the channel when we are in draining mode to stop prefetch new messages.
    close the channel when we are in stopping mode to reject all the unacked messages that we did't start to consume.

  Check in Peano how to use it.

  """
  @doc """
  Check if the application is in draining mode.
  """
  @callback draining? :: boolean

  @doc """
  Check if the application is in stopping mode.
  """
  @callback stopping? :: boolean
end
