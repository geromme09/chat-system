FROM golang:1.25 AS goose-builder

RUN go install github.com/pressly/goose/v3/cmd/goose@v3.24.1

FROM postgres:16

WORKDIR /app

COPY --from=goose-builder /go/bin/goose /usr/local/bin/goose
COPY migrations /app/migrations
COPY docker/migrate/goose.sh /app/goose.sh

RUN chmod +x /app/goose.sh

ENTRYPOINT ["/app/goose.sh"]
