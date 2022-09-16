defmodule Amqpx.Backoff.Exponential do
  @moduledoc """
  Implements an exponential backoff strategy
  """

  @spec backoff(
          attempts :: number(),
          base_backoff_ms :: number(),
          max_backoff_ms :: number()
        ) :: :ok
  def backoff(_, _, _) do
    :ok
  end

  #  defp backoff(attempt, %{
  #         base_backoff_in_ms: base_backoff_in_ms,
  #         max_backoff_in_ms: max_backoff_in_ms
  #  }) do
  #    (base_backoff_in_ms * :math.pow(2, attempt))
  #    |> min(max_backoff_in_ms)
  #    |> trunc
  #    |> :rand.uniform()
  #    |> :timer.sleep()
  #  end
end
