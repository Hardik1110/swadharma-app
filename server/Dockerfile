# Swadharma backend: compiled to a small standalone binary.
#   docker build -t swadharma-api ./server
#   docker run -p 8080:8080 -e PORT=8080 -e AGORA_APP_ID=... swadharma-api

FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline \
 && dart compile exe bin/server.dart -o /app/server \
 && mkdir -p /out/data

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
COPY --from=build /app/public /app/public
# Writable folder for the JSON database (ephemeral on most free hosts).
COPY --from=build /out/data /app/data

ENV PUBLIC_DIR=/app/public \
    DATA_FILE=/app/data/db.json
# Hosts such as Render/Fly set PORT themselves; this is the local default.
ENV PORT=8080
EXPOSE 8080
CMD ["/app/server"]
