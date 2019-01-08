
#===========
#Build Stage
#===========
FROM elixir:latest as build
#RUN apk update && apk add --no-cache openssh git make autoconf automake wget yasm gmp libtool cmake clang build-base gcc abuild binutils linux-headers
COPY --chown=root .ssh/id_rsa /root/.ssh/id_rsa
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts
RUN apt-get update && apt-get install -y cmake doxygen


COPY . .

RUN rm -Rf _build \
    && mix local.rebar --force \
    && mix local.hex --force \
    && mix deps.get \
    && make release

RUN ./cmd genesis onboard

EXPOSE 4001
ENV REPLACE_OS_VARS=true PORT=4001

# COPY --from=build /export/ .

#USER default
ENTRYPOINT ["_build/prod/rel/blockchain_node/bin/blockchain_node"]
CMD ["foreground", ";", "genesis onboard"]