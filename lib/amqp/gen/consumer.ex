defmodule Amqpx.Gen.Consumer do
  @moduledoc """
  Generic implementation of amqp consumer
  """
  require Logger
  use GenServer
  import Amqpx.Core
  alias Amqpx.{Basic, Channel}

  defstruct [
    :channel,
    :handler_module,
    :handler_state,
    prefetch_count: 50,
    backoff: 5_000,
    connection_name: Amqpx.Gen.ConnectionManager,
    requeue_on_reject: true
  ]

  @type state() :: %__MODULE__{}

  @callback setup(Channel.t()) :: {:ok, map()} | {:error, any()}
  @callback handle_message(any(), map(), map()) :: {:ok, map()} | {:error, any()}
  @callback handle_message_rejection(message :: any(), error :: any()) :: :ok | {:error, any()}
  @optional_callbacks handle_message_rejection: 2

  @gen_server_opts [:name, :timeout, :debug, :spawn_opt, :hibernate_after]

  @spec start_link(opts :: map()) :: GenServer.server()
  def start_link(opts) do
    {gen_server_opts, opts} = Map.split(opts, @gen_server_opts)

    GenServer.start_link(__MODULE__, opts, Map.to_list(gen_server_opts))
  end

  def init(opts) do
    Process.flag(:trap_exit, true)

    state = struct(__MODULE__, opts)
    Process.send(self(), :setup, [])
    {:ok, state}
  end

  def handle_info(
        :setup,
        %{
          backoff: backoff,
          prefetch_count: prefetch_count,
          handler_module: handler_module,
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

        Basic.qos(channel, prefetch_count: prefetch_count)

        {:ok, handler_state} = handler_module.setup(channel)
        state = %{state | handler_state: handler_state}

        {:noreply, state}
    end
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:"basic.consume_ok", _consumer_tag}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled
  def handle_info({:server_cancel, {:"basic.cancel", _consumer_tag, _nowait}}, state) do
    {:stop, :basic_cancel, state}
  end

  # Received if we call Basic.cancel
  def handle_info({:"basic.cancel", _consumer_tag, _nowait}, state) do
    {:noreply, state, :hibernate}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:"basic.cancel_ok", _consumer_tag}, state) do
    {:stop, :basic_cancel_ok, state}
  end

  def handle_info(
        {basic_deliver(
           consumer_tag: consumer_tag,
           delivery_tag: delivery_tag,
           redelivered: redelivered,
           exchange: exchange,
           routing_key: routing_key
         ),
         amqp_msg(
           props:
             p_basic(
               content_type: content_type,
               content_encoding: content_encoding,
               headers: headers,
               delivery_mode: delivery_mode,
               priority: priority,
               correlation_id: correlation_id,
               reply_to: reply_to,
               expiration: expiration,
               message_id: message_id,
               timestamp: timestamp,
               type: type,
               user_id: user_id,
               app_id: app_id,
               cluster_id: cluster_id
             ),
           payload: payload
         )},
        state
      ) do
    meta = %{
      consumer_tag: consumer_tag,
      delivery_tag: delivery_tag,
      redelivered: redelivered,
      exchange: exchange,
      routing_key: routing_key,
      content_type: content_type,
      content_encoding: content_encoding,
      headers: headers,
      persistent: delivery_mode == 2,
      priority: priority,
      correlation_id: correlation_id,
      reply_to: reply_to,
      expiration: expiration,
      message_id: message_id,
      timestamp: timestamp,
      type: type,
      user_id: user_id,
      app_id: app_id,
      cluster_id: cluster_id
    }

    {:noreply, handle_message(payload, meta, state)}
  end

  def handle_info(
        {basic_consume(
           ticket: _ticket,
           queue: _queue,
           consumer_tag: _consumer_tag,
           no_local: _no_local,
           no_ack: _no_ack,
           exclusive: _exclusive,
           nowait: _nowait,
           arguments: _arguments
         ), _pid},
        state
      ) do
    {:noreply, state}
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
    state = %{state | channel: nil}
    {:stop, :channel_exited, state}
  end

  def handle_info({:EXIT, _, :normal}, state), do: {:noreply, state}

  def handle_info(message, state) do
    Logger.warn("Unknown message received #{inspect(message)}")
    {:noreply, state}
  end

  def terminate(_, %__MODULE__{channel: nil}), do: nil

  def terminate(reason, %__MODULE__{channel: channel}) do
    case reason do
      :normal -> close_channel(channel)
      :shutdown -> close_channel(channel)
      {:shutdown, _} -> close_channel(channel)
      _ -> :ok
    end
  end

  # Private functions

  defp close_channel(%{pid: pid} = channel) do
    if Process.alive?(pid) do
      Channel.close(channel)

      receive do
        {:DOWN, _, :process, ^pid, _reason} ->
          :ok
      end
    end
  end

  defp handle_message(
         message,
         %{delivery_tag: tag, redelivered: redelivered} = meta,
         %__MODULE__{
           handler_module: handler_module,
           handler_state: handler_state,
           backoff: backoff,
           requeue_on_reject: requeue_on_reject
         } = state
       ) do
    {:ok, handler_state} = handler_module.handle_message(message, meta, handler_state)
    Basic.ack(state.channel, tag)
    %{state | handler_state: handler_state}
  rescue
    e in _ ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))

      Task.start(fn ->
        :timer.sleep(backoff)

        is_message_to_reject =
          function_exported?(handler_module, :handle_message_rejection, 2) &&
            (!requeue_on_reject || (redelivered && requeue_on_reject))

        if is_message_to_reject do
          handler_module.handle_message_rejection(message, e)
        end

        Basic.reject(state.channel, tag, requeue: requeue_on_reject && !redelivered)
      end)

      state
  end
end
