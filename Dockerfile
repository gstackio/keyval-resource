FROM golang:alpine as ginkgo
WORKDIR /keyval-resource
COPY go.mod go.sum ./
RUN go install -mod="mod" "github.com/onsi/ginkgo/v2/ginkgo@latest"



FROM ginkgo as builder
ENV CGO_ENABLED 0

WORKDIR /keyval-resource

COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o /assets/out ./out \
 && go build -o /assets/in ./in \
 && go build -o /assets/check ./check
# RUN set -e; for pkg in $(go list ./...); do \
# 		go test -o "/tests/$(basename $pkg).test" -c $pkg; \
# 	done
RUN ACK_GINKGO_RC="true" ginkgo -r --show-node-events .



FROM alpine:latest AS resource
RUN apk add --no-cache bash tzdata
COPY --from=builder /assets /opt/resource



FROM resource AS tests
# COPY --from=builder /tests /tests
# RUN set -e; for test in /tests/*.test; do \
# 		$test; \
# 	done



FROM resource
