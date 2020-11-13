FROM 595659439703.dkr.ecr.eu-west-1.amazonaws.com/elixir:1.11.2-1

WORKDIR /code

# Serve per avere l'owner dei file scritti dal container uguale all'utente Linux sull'host
USER app

COPY ["entrypoint", "/entrypoint"]

ENTRYPOINT ["/entrypoint"]
