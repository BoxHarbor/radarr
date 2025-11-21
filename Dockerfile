# BoxHarbor Radarr Image - Multi-Architecture avec support RISC-V
FROM ghcr.io/boxharbor/baseimage-alpine:latest

# Build arguments
ARG BUILD_DATE
ARG VERSION
ARG VCS_REF
ARG RADARR_VERSION=6.0.4.10291
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Labels
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
  org.opencontainers.image.title="BoxHarbor Radarr" \
  org.opencontainers.image.description="Lightweight, rootless-compatible Radarr image" \
  org.opencontainers.image.url="https://github.com/BoxHarbor/radarr" \
  org.opencontainers.image.source="https://github.com/BoxHarbor/radarr" \
  org.opencontainers.image.version="${VERSION}" \
  org.opencontainers.image.revision="${VCS_REF}" \
  org.opencontainers.image.vendor="BoxHarbor" \
  org.opencontainers.image.licenses="GPL-3.0" \
  maintainer="BoxHarbor Team"

# Install runtime dependencies
RUN apk add --no-cache \
  bash \
  curl \
  sqlite \
  wget \
  tar \
  file \
  libstdc++ \
  libgcc \
  icu-libs \
  && rm -rf /var/cache/apk/* /tmp/*

# Copy installation script
COPY scripts/install-radarr.sh /tmp/install-radarr.sh
RUN chmod +x /tmp/install-radarr.sh

# Install Radarr using the script
RUN RADARR_VERSION="${RADARR_VERSION}" \
  TARGETPLATFORM="${TARGETPLATFORM}" \
  /tmp/install-radarr.sh && \
  rm -f /tmp/install-radarr.sh

# Copy default configurations
COPY rootfs/ /

# Expose non-privileged HTTP port
EXPOSE 7878

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl --fail http://localhost:7878/

# Use base image init
CMD []