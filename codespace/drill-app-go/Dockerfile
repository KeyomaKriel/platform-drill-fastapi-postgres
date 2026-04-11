FROM golang:1.22-alpine AS builder

WORKDIR /build

COPY go.mod ./
COPY *.go ./
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o /inventory-api .

FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /opt/app

COPY --from=builder /inventory-api .

EXPOSE 9090

USER nobody:nobody

CMD ["./inventory-api"]
