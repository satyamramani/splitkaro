FROM alpine:latest

ARG PB_VERSION=0.40.5

RUN apk add --no-cache \
    unzip \
    ca-certificates \
    wget

# Automatically detect architecture (amd64 vs arm64)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then PB_ARCH="amd64"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then PB_ARCH="arm64"; \
    else PB_ARCH="amd64"; fi && \
    wget https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_${PB_ARCH}.zip -O /tmp/pb.zip && \
    mkdir -p /pb && \
    unzip /tmp/pb.zip -d /pb && \
    rm /tmp/pb.zip && \
    chmod +x /pb/pocketbase

WORKDIR /pb

# Include migrations in image
COPY ./pb_migrations /pb/pb_migrations

EXPOSE 18090

VOLUME /pb/pb_data

CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:18090", "--dir=/pb/pb_data", "--migrationsDir=/pb/pb_migrations"]
