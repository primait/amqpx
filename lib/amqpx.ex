defmodule Amqpx do
  @moduledoc """
  This module provides Amqpx-related types.
  """

  @type argument_type() ::
          :longstr
          | :signedint
          | :decimal
          | :timestamp
          | :table
          | :byte
          | :double
          | :float
          | :long
          | :short
          | :bool
          | :binary
          | :void
          | :array

  @type arguments() :: [{String.t(), argument_type(), term()}]

  defmacro __using__(_opts) do
    quote do
      alias Amqpx.Connection
      alias Amqpx.Channel
      alias Amqpx.Exchange
      alias Amqpx.Queue
      alias Amqpx.Basic
      alias Amqpx.Confirm
    end
  end
end
