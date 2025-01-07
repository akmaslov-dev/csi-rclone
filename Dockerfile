#################
## Build stage ##
#################
FROM --platform=$BUILDPLATFORM golang:1.23.0-bookworm AS build

# Build arguments provided by Docker Buildx:
#   TARGETPLATFORM - e.g., "linux/amd64" or "linux/arm64"
#   TARGETOS       - e.g., "linux"
#   TARGETARCH     - e.g., "amd64" or "arm64"
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH

ARG RCLONE_VERSION=v1.68.2

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY cmd/ ./cmd/
COPY pkg/ ./pkg/

# Build the Go binary for the right OS/ARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o /csi-rclone ./cmd/csi-rclone-plugin/main.go

# Download and extract the rclone binary matching the OS/ARCH
RUN apt-get update && apt-get install -y unzip && \
        curl -sSL https://downloads.rclone.org/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-${TARGETOS}-${TARGETARCH}.zip -o /tmp/rclone.zip && \
        unzip /tmp/rclone.zip -d /tmp/rclone-unzip && \
        chmod a+x /tmp/rclone-unzip/*/rclone && \
        mv /tmp/rclone-unzip/*/rclone /rclone && \
        rm -rf /tmp/rclone.zip /tmp/rclone-unzip

#################
## Final stage ##
#################
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends fuse3 ca-certificates && \
        rm -rf /var/lib/apt/lists/*

COPY --from=build /csi-rclone /csi-rclone
COPY --from=build /rclone /usr/bin/rclone

ENTRYPOINT ["/csi-rclone"]
