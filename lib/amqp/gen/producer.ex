defmodule Amqpx.Gen.Producer do
  @moduledoc """
  Generic implementation of amqp producer
  """
  require Logger
  use GenServer
  alias Amqpx.{Basic, Channel, Confirm, Helper, Backoff.Exponential}

  @type state() :: %__MODULE__{}

  @default_max_retries 0
  @default_retry_policy %{
    on_publish_rejected: false,
    on_publish_error: false,
    on_confirm_timeout: false
  }

  defstruct [
    :channel,
    :publisher_confirms,
    publish_timeout: 1_000,
    backoff: 5_000,
    exchanges: [],
    connection_name: Amqpx.Gen.ConnectionManager,
    publish_retry_options: []
  ]

  # Public API

  def start_link(opts) do
    name = Map.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    case validate_configuration(opts) do
      {:ok, state} ->
        Process.send(self(), :setup, [])
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @spec publish(
          exchange_name :: String.t(),
          routing_key :: String.t(),
          payload :: String.t(),
          options :: Keyword.t()
        ) ::
          :ok | :error
  def publish(exchange_name, routing_key, payload, options \\ []) do
    publish_by(__MODULE__, exchange_name, routing_key, payload, options)
  end

  @spec publish_by(
          producer_name :: GenServer.name(),
          exchange_name :: String.t(),
          routing_key :: String.t(),
          payload :: String.t(),
          options :: Keyword.t()
        ) ::
          :ok | :error
  def publish_by(producer_name, exchange_name, routing_key, payload, options \\ []) do
    case GenServer.call(producer_name, {:publish, {exchange_name, routing_key, payload, options}}) do
      :ok ->
        :ok

      reason ->
        Logger.error("Error during publish: #{inspect(reason)}")
        :error
    end
  end

  # Callbacks

  def handle_info(
        :setup,
        %{
          backoff: backoff,
          publisher_confirms: publisher_confirms,
          exchanges: exchanges,
          connection_name: connection_name
        } = state
      ) do
    case GenServer.call(connection_name, :get_connection) do
      nil ->
        :timer.sleep(backoff)
        {:stop, :not_ready, state}

      connection ->
        {:ok, channel} = Channel.open(connection, self())
        Process.monitor(channel.pid)
        state = %{state | channel: channel}

        declare_exchanges(exchanges, channel)

        if publisher_confirms do
          Confirm.select(channel)
        end

        {:noreply, state}
    end
  end

  def handle_info({_ref, {:ok, _port, _pid}}, state) do
    Logger.debug("Amqpx socket probably restarted by underlying library")
    {:noreply, state}
  end

  # Error handling

  def handle_info({_ref, {:error, :no_socket, _pid}}, state) do
    Logger.debug("Amqpx socket not found")
    {:noreply, state}
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    Logger.info("Monitored channel process crashed: #{inspect(reason)}. Restarting...")
    {:stop, :channel_exited, state}
  end

  def handle_info(message, state) do
    Logger.warn("Unknown message received #{inspect(message)}")
    {:noreply, state}
  end

  def terminate(_, %__MODULE__{channel: nil}), do: nil

  def terminate(_, %__MODULE__{channel: channel}) do
    if Process.alive?(channel.pid) do
      Channel.close(channel)
    end
  end

  def handle_call(_msg, _from, %{channel: nil}) do
    {:reply, {:error, :not_connected}}
  end

  def handle_call(
        {:publish, {exchange, routing_key, payload, options}},
        _from,
        %{
          channel: channel,
          publisher_confirms: publisher_confirms,
          publish_timeout: publish_timeout,
          publish_retry_options: publish_retry_options
        } = state
      ) do
    retry_policy = Keyword.get(publish_retry_options, :retry_policy, %{})
    max_retries = Keyword.get(publish_retry_options, :max_retries, @default_max_retries)

    publish_options = %{
      publisher_confirms: publisher_confirms,
      publish_timeout: publish_timeout,
      max_retries: max_retries,
      retry_policy: retry_policy
    }

    result =
      case retry_policy do
        [] ->
          do_publish(
            channel,
            exchange,
            routing_key,
            payload,
            publish_options,
            Keyword.merge([persistent: true], options)
          )

        _any ->
          do_retry_publish(
            channel,
            exchange,
            routing_key,
            payload,
            1,
            publish_options,
            Keyword.merge([persistent: true], options)
          )
      end

    handle_publish_result(result, state)
  end

  # Private functions
  defp handle_publish_result(result, state) do
    case result do
      {:confirm, true} ->
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error("cannot publish message to broker: #{inspect(reason)}")
        {:stop, reason, {:error, reason}, state}

      {:confirm, :timeout} ->
        Logger.error("cannot publish message to broker: publisher timeout")
        {:stop, "publisher timeout", {:error, :timeout}, state}

      {:confirm, false} ->
        Logger.error("cannot publish message to broker: broker nack")
        {:stop, "publisher error", {:error, :nack}, state}
    end
  end

  defp do_retry_publish(
         channel,
         exchange,
         routing_key,
         payload,
         attempt,
         %{max_retries: max_retries, retry_policy: retry_policy} = publish_options,
         options
       )
       when attempt < max_retries do
    retry_publish = fn ->
      Exponential.backoff(attempt, publish_options)

      do_retry_publish(
        channel,
        exchange,
        routing_key,
        payload,
        attempt + 1,
        publish_options,
        options
      )
    end

    case do_publish(channel, exchange, routing_key, payload, publish_options, options) do
      {:confirm, true} ->
        {:confirm, true}

      error ->
        case {error, retry_policy} do
          {{:confirm, :timeout}, %{on_confirm_timeout: true}} ->
            retry_publish.()

          {{:confirm, false}, %{on_publish_rejected: true}} ->
            retry_publish.()

          {{:error, _}, %{on_publish_error: true}} ->
            retry_publish.()

          _ ->
            error
        end
    end
  end

  defp do_retry_publish(
         channel,
         exchange,
         routing_key,
         payload,
         _attempt,
         publish_options,
         options
       ),
       do: do_publish(channel, exchange, routing_key, payload, publish_options, options)

  defp do_publish(
         channel,
         exchange,
         routing_key,
         payload,
         %{
           publisher_confirms: publisher_confirms,
           publish_timeout: publish_timeout
         },
         options
       ) do
    with :ok <-
           Basic.publish(
             channel,
             exchange,
             routing_key,
             payload,
             options
           ) do
      {:confirm, confirm_delivery(publisher_confirms, publish_timeout, channel)}
    end
  end

  @spec confirm_delivery(boolean(), integer(), Channel.t()) :: boolean() | :timeout
  defp confirm_delivery(false, _, _), do: true

  defp confirm_delivery(true, timeout, channel) do
    Confirm.wait_for_confirms(channel, timeout)
  end

  defp declare_exchanges(exchanges, channel) do
    Enum.each(exchanges, &Helper.setup_exchange(channel, &1))
  end

  # Configuration

  # Validates configuration and returns the genserver's state if successful, or error
  defp validate_configuration(%{} = opts) do
    publish_retry_options = Map.get(opts, :publish_retry_options, [])

    ok_or_validation_error = validate_retry_policy(publish_retry_options)

    if ok_or_validation_error == :ok do
      retry_policy_opts =
        publish_retry_options
        |> Keyword.get(:retry_policy, [])
        |> Enum.reduce(@default_retry_policy, fn policy, acc -> Map.put(acc, policy, true) end)

      configurations =
        opts
        |> Map.put(:publish_retry_options, publish_retry_options)
        |> put_in([:publish_retry_options, :retry_policy], retry_policy_opts)

      {:ok, struct(__MODULE__, configurations)}
    else
      ok_or_validation_error
    end
  end

  defp validate_retry_policy(publish_retry_options) do
    max_retries = Keyword.get(publish_retry_options, :max_retries, @default_max_retries)
    retry_policy = Keyword.get(publish_retry_options, :retry_policy, [])

    if not Enum.empty?(retry_policy) and max_retries == 0 do
      {:error, {:invalid_configuration, "when retry policy is configured, max_retries must be > 0"}}
    else
      :ok
    end
  end
end
