FROM hexpm/elixir:1.17.3-erlang-27.1.2-ubuntu-jammy-20240808 AS build

RUN apt-get update && apt-get install -y --no-install-recommends build-essential git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs ./
RUN mix deps.get --only prod && mix deps.compile

COPY config config
COPY lib lib
COPY src src
COPY priv priv
COPY rel rel
RUN mix release ecall

FROM ubuntu:22.04 AS app

RUN apt-get update && apt-get install -y --no-install-recommends openssl libstdc++6 ncurses-bin ca-certificates locales curl \
  && rm -rf /var/lib/apt/lists/*

RUN locale-gen C.UTF-8 || true

WORKDIR /app
COPY --from=build /app/_build/prod/rel/ecall ./

ENV HOME=/app
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV ELIXIR_ERL_OPTIONS="+fnu"
ENV RELEASE_DISTRIBUTION=name
CMD ["/app/bin/ecall", "start"]
