defmodule Amqpx.OpenTelemetry do
  # internal helpers for opentelemetry that turn functions into noops if opentelemetry is not available
  @moduledoc false

  if Code.ensure_loaded?(OpenTelemetry) and Code.ensure_loaded?(OpenTelemetry.SemConv) do
    require OpenTelemetry.Tracer, as: Tracer

    defmacro with_span(name, trace_propagation_carrier \\ quote(do: []), start_opts \\ quote(do: %{}), do: block) do
      quote do
        require OpenTelemetry.Tracer, as: Tracer

        links =
          OpenTelemetry.Ctx.new()
          |> :otel_propagator_text_map.extract_to(unquote(trace_propagation_carrier))
          |> OpenTelemetry.Tracer.current_span_ctx()
          |> OpenTelemetry.link()
          |> List.wrap()

        start_opts = unquote(start_opts) |> Map.new() |> Map.put(:links, links)
        Tracer.with_span(unquote(name), start_opts, do: unquote(block))
      end
    end

    def start_task(fun) do
      span_ctx = Tracer.start_span(:child)
      ctx = OpenTelemetry.Ctx.get_current()

      Task.start(fn ->
        OpenTelemetry.Ctx.attach(ctx)
        OpenTelemetry.Tracer.set_current_span(span_ctx)

        ret = fun.()

        OpenTelemetry.Tracer.end_span(span_ctx)

        ret
      end)
    end

    def inject_trace_propagation_headers(carrier) do
      :otel_propagator_text_map.inject(carrier)
    end
  else
    defmacro with_span(_, _ \\ quote(do: []), _ \\ quote(do: %{}), do: block), do: block

    def start_task(fun) do
      Task.start(fun)
    end

    def inject_trace_propagation_headers(carrier) do
      carrier
    end
  end
end
