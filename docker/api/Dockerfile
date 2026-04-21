FROM golang:1.25 AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY cmd ./cmd
COPY docs/swagger ./docs/swagger
COPY internal ./internal

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/api ./cmd/api

FROM gcr.io/distroless/base-debian12

WORKDIR /app

COPY --from=builder /out/api /app/api

EXPOSE 8080

ENTRYPOINT ["/app/api"]
