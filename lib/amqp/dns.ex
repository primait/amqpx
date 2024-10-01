defmodule Amqpx.DNS do
  @moduledoc """
  Module to resolve a DNS record into an A record.
  """

  @doc """
  Resolves the IP addresses of a given hostname. If the hostname
  cannot be resolved, it returns the hostname itself.
  """
  @spec resolve_ips(charlist) :: [charlist]
  def resolve_ips(host) do
    case :inet.gethostbyname(host) do
      {:ok, {:hostent, _, _, _, _, ips}} ->
        ips |> Enum.map(&:inet.ntoa/1) |> Enum.dedup()

      _ ->
        [host]
    end
  end
end
