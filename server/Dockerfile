FROM dart:3.13.4 AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY packages/sync_protocol/ packages/sync_protocol/
COPY server/pubspec.yaml server/pubspec.lock server/
WORKDIR /src/server
RUN dart pub get
COPY server/ ./
RUN dart pub get --offline \
 && dart build cli --target bin/relay.dart --output /out

FROM debian:trixie-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends tini curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /out/bundle/ /app/
COPY --from=build /src/server/migrations/ /app/migrations/
ENV RELAY_DATABASE=/var/lib/relay/relay.sqlite3 \
    RELAY_MEDIA_DIR=/srv/relay-media \
    RELAY_PORT=8080
USER 1000:1000
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS -o /dev/null http://127.0.0.1:8080/health || exit 1
ENTRYPOINT ["/usr/bin/tini", "--", "/app/bin/relay"]
