FROM public.ecr.aws/prima/elixir:1.12.0-1

WORKDIR /code

USER app

COPY ["entrypoint", "/entrypoint"]

ENTRYPOINT ["/entrypoint"]
