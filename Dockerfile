
#===========
#Build Stage
#===========
FROM elixir:latest as build
RUN apt-get update && apt-get install -y cmake doxygen 

COPY --chown=root .ssh/id_rsa /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts
RUN echo "StrictHostKeyChecking no " >> /root/.ssh/config

COPY . .

RUN rm -Rf _build \
    && rm -Rf deps \
    && mix local.rebar --force \
    && mix local.hex --force \
    && mix deps.get \
    && make release

# RUN ./cmd start
# RUN ./cmd genesis onboard
# RUN ./cmd stop

EXPOSE 4001
ENV REPLACE_OS_VARS=true PORT=4001

ENTRYPOINT ["_build/prod/rel/blockchain_node/bin/blockchain_node"]
CMD ["foreground"]