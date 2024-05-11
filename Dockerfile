FROM golang:alpine AS ginkgo
WORKDIR /keyval-resource
COPY go.mod go.sum ./
RUN go install -mod="mod" "github.com/onsi/ginkgo/v2/ginkgo@latest"



FROM ginkgo AS builder
ENV CGO_ENABLED 0

WORKDIR /keyval-resource

COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go version \
    && go build -o /assets/out   ./out \
    && go build -o /assets/in    ./in \
    && go build -o /assets/check ./check
RUN ACK_GINKGO_RC="true" ginkgo -r --show-node-events .



FROM alpine:latest AS resource
RUN apk add --no-cache bash tzdata
COPY --from=builder /assets /opt/resource
