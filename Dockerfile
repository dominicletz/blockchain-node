
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

#Extract Release archive to /rel for copying in next stage
RUN APP_NAME="blockchain_node"  \
    && RELEASE_DIR=`ls -d _build/prod/rel/$APP_NAME/releases/*/` \
    && mkdir /export \
    && tar -xf "$RELEASE_DIR/$APP_NAME.tar.gz" -C /export


#================
#Deployment Stage
#================
FROM elixir:latest

COPY --from=build /export/ .
COPY --from=build /cmd .

EXPOSE 4001
ENV REPLACE_OS_VARS=true PORT=4001

ENTRYPOINT ["/bin/blockchain_node"]
CMD ["foreground"]