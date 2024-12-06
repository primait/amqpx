FROM public.ecr.aws/prima/elixir:1.14.2-5

WORKDIR /code

USER app

RUN mix local.hex --force && \
    mix local.rebar --force

