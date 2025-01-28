FROM alpine:edge AS stage

RUN \
  apk update && apk add curl make clang libevent-dev msgpack-c-dev musl-dev bsd-compat-headers jq && \
  LATEST=$(curl -SsL https://api.github.com/repos/nicolasff/webdis/tags | jq '.[] | .name' | head -1 | sed 's/"//g') && \
  curl -SsL https://github.com/nicolasff/webdis/archive/${LATEST}.tar.gz | tar -xz && \
  cd webdis-${LATEST} && CC=clang make -j$(nproc) && make install && make clean

# main image
FROM alpine:edge

RUN \
  apk update && apk add libevent valkey && \
  rm -f /var/cache/apk/* /usr/bin/valkey-check-aof /usr/bin/valkey-check-rdb /usr/bin/valkey-sentinel && \
  echo "daemonize yes" >> /etc/valkey/valkey.conf

COPY --from=stage /usr/local/bin/webdis /usr/local/bin/
COPY webdis.json /etc/webdis.json

CMD ["/bin/sh", "-c", "if [ -z \"${WEBDIS_AUTH}\" ]; then echo \"WEBDIS_AUTH is empty\"; exit 1; fi && sed -i \"s/BASICAUTH/${WEBDIS_AUTH}/g\" /etc/webdis.json && /usr/bin/valkey-server /etc/valkey/valkey.conf && /usr/local/bin/webdis /etc/webdis.json"]

EXPOSE 7379
