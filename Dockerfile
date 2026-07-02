FROM public.ecr.aws/prima/elixir:1.17.3

WORKDIR /code

USER app

RUN mix local.hex --force && \
    mix local.rebar --force

