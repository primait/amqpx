defmodule Amqpx.Backoff.Jittered do
  @moduledoc """
  Implements a jittered backoff strategy
  """

  @spec backoff(
          attempt :: number(),
          base_backoff_ms :: number(),
          max_backoff_ms :: number()
        ) :: pos_integer()
  def backoff(attempt, base_backoff_ms, max_backoff_ms) do
    (base_backoff_ms * :math.pow(2, attempt))
    |> min(max_backoff_ms)
    |> trunc
    |> :rand.uniform()
  end
end
