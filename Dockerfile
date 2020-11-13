FROM 595659439703.dkr.ecr.eu-west-1.amazonaws.com/elixir:1.11.2-1

WORKDIR /code

RUN groupadd -g 1000 app && \
    useradd -g 1000 -u 1000 --system --create-home app && \
    mix local.hex --force && \
    mix local.rebar --force && \
    cp -rp /root/.mix /home/app/ && \
    chown -R app:app /home/app/.mix

# Serve per avere l'owner dei file scritti dal container uguale all'utente Linux sull'host
USER app

COPY ["entrypoint", "/entrypoint"]

ENTRYPOINT ["/entrypoint"]
