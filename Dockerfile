FROM public.ecr.aws/prima/elixir:1.11.2-1

WORKDIR /code

USER app

COPY ["entrypoint", "/entrypoint"]

ENTRYPOINT ["/entrypoint"]
