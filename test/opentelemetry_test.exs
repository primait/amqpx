defmodule Amqpx.Test.OpentelemetryTest do
  use ExUnit.Case

  alias Amqpx.Test.Support.Consumer1
  alias Amqpx.Test.Support.Producer1
  alias Amqpx.SignalHandler

  require Record
  @span_fields Record.extract(:span, from: "deps/opentelemetry/include/otel_span.hrl")
  Record.defrecordp(:span, @span_fields)

  @link_fields Record.extract(:link, from: "deps/opentelemetry/include/otel_span.hrl")
  Record.defrecordp(:link, @link_fields)

  import Mock

  @moduletag capture_log: true
  @start_supervised_timeout 20

  test "message consumer sets up opentelemetry spans" do
    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())

    start_connection1!()
    start_consumer_by_name!(Consumer1)
    start_producer!(:producer)

    payload = %{test: 1}

    with_mock(Consumer1, handle_message: fn _, _, s -> {:ok, s} end) do
      Producer1.send_payload(payload)
      :timer.sleep(50)
      assert_called(Consumer1.handle_message(Jason.encode!(payload), :_, :_))
    end

    assert_receive {:span, span(name: :"handle amqp message")},
                   5000
  end

  test "message publisher sets up opentelemetry spans" do
    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())

    start_connection1!()
    start_consumer_by_name!(Consumer1)
    start_producer!(:producer)

    payload = %{test: 1}

    with_mock(Consumer1, handle_message: fn _, _, s -> {:ok, s} end) do
      Producer1.send_payload(payload)
      :timer.sleep(50)
      assert_called(Consumer1.handle_message(Jason.encode!(payload), :_, :_))
    end

    assert_receive {:span, span(name: :"publish amqp message")},
                   5000
  end

  test "traces are propagated across rabbit" do
    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())

    start_connection1!()
    start_consumer_by_name!(Consumer1)
    start_producer!(:producer)

    payload = %{test: 1}

    with_mock(Consumer1, handle_message: fn _, _, s -> {:ok, s} end) do
      Producer1.send_payload(payload)
      :timer.sleep(50)
      assert_called(Consumer1.handle_message(Jason.encode!(payload), :_, :_))
    end

    assert_receive {:span,
                    span(
                      name: :"publish amqp message",
                      trace_id: parent_trace_id,
                      span_id: parent_span_id
                    )},
                   5000

    assert_receive {:span,
                    span(
                      name: :"handle amqp message",
                      links:
                        {_, _, _, _, _,
                         [
                           link(
                             trace_id: ^parent_trace_id,
                             span_id: ^parent_span_id
                           )
                         ]}
                    )},
                   5000
  end

  defp start_connection1!() do
    start_supervised!(%{
      id: :amqp_connection,
      start:
        {Amqpx.Gen.ConnectionManager, :start_link,
         [%{connection_params: Application.fetch_env!(:amqpx, :amqp_connection)}]}
    })

    :timer.sleep(@start_supervised_timeout)
  end

  defp start_producer!(name) when is_atom(name) do
    start_supervised!(%{
      id: name,
      start: {Amqpx.Gen.Producer, :start_link, [Application.fetch_env!(:amqpx, name)]}
    })

    :timer.sleep(@start_supervised_timeout)
  end

  defp start_consumer_by_name!(name) when is_atom(name) do
    opts =
      :amqpx
      |> Application.fetch_env!(:consumers)
      |> Enum.find(&(&1.handler_module == name))

    SignalHandler.start_link()

    if is_nil(opts) do
      raise "Consumer #{name} not found"
    end

    start_supervised!(%{
      id: name,
      start: {Amqpx.Gen.Consumer, :start_link, [opts]}
    })

    :timer.sleep(@start_supervised_timeout)
  end
end
