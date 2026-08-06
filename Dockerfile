FROM 279066465364.dkr.ecr.eu-west-1.amazonaws.com/prima-elixir:1.16.3

WORKDIR /code

USER app

RUN mix local.hex --force && \
    mix local.rebar --force

