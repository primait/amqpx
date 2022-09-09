defmodule Amqpx.Backoff.Exponential do
  @moduledoc """
  """

  def backoff(_, _) do
    nil
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
