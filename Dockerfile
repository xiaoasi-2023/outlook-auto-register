ARG PYTHON_BASE_IMAGE=python:3.11-slim-bookworm
FROM ${PYTHON_BASE_IMAGE} AS app

ARG TARGETARCH
ARG MIHOMO_VERSION=1.19.12
ARG XRAY_DOWNLOAD_URL=
ARG MIHOMO_DOWNLOAD_URL=

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    DISPLAY=:98 \
    OUTLOOK_DASHBOARD_PORT=8765 \
    TZ=Asia/Shanghai

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      wget \
      unzip \
      gzip \
      git \
      jq \
      procps \
      iproute2 \
      net-tools \
      xvfb \
      x11-utils \
      chromium \
      fonts-liberation \
      fonts-noto-cjk \
      libnss3 \
      libatk-bridge2.0-0 \
      libdrm2 \
      libxkbcommon0 \
      libgbm1 \
      libxshmfence1 \
      libxcomposite1 \
      libxrandr2 \
      libxdamage1 \
      libpango-1.0-0 \
      libcairo2 \
      libatspi2.0-0 \
      libgtk-3-0 \
      libasound2; \
    rm -rf /var/lib/apt/lists/*

# Install xray-core and mihomo into /usr/local/bin. Runtime code stores configs
# under /app/邮箱注册/*_runtime, so bind mounts cannot affect host services.
RUN set -eux; \
    arch="${TARGETARCH:-amd64}"; \
    case "$arch" in \
      amd64) xray_arch="64"; mihomo_arch="amd64" ;; \
      arm64) xray_arch="arm64-v8a"; mihomo_arch="arm64" ;; \
      *) echo "Unsupported Docker TARGETARCH=$arch" >&2; exit 1 ;; \
    esac; \
    xray_url="${XRAY_DOWNLOAD_URL:-https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${xray_arch}.zip}"; \
    mihomo_url="${MIHOMO_DOWNLOAD_URL:-https://github.com/MetaCubeX/mihomo/releases/download/v${MIHOMO_VERSION}/mihomo-linux-${mihomo_arch}-v${MIHOMO_VERSION}.gz}"; \
    curl --retry 5 --retry-delay 3 -fsSL -o /tmp/xray.zip "$xray_url"; \
    unzip -j /tmp/xray.zip xray -d /usr/local/bin; \
    chmod +x /usr/local/bin/xray; \
    curl --retry 5 --retry-delay 3 -fsSL -o /tmp/mihomo.gz "$mihomo_url"; \
    gzip -dc /tmp/mihomo.gz > /usr/local/bin/mihomo; \
    chmod +x /usr/local/bin/mihomo; \
    rm -f /tmp/xray.zip /tmp/mihomo.gz

WORKDIR /app

COPY requirements.txt requirements_cdp.txt requirements.deploy.txt ./
RUN python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install --no-cache-dir -r requirements.deploy.txt

COPY docker/entrypoint.sh /usr/local/bin/outlook-docker-entrypoint
RUN chmod +x /usr/local/bin/outlook-docker-entrypoint

COPY . .

RUN mkdir -p \
      /app/runtime_outlook/logs \
      /app/runtime_outlook/rt_tokens \
      /app/runtime_outlook/rt_input \
      /app/runtime_outlook/fail_dumps \
      /app/邮箱注册/mihomo_runtime \
      /app/邮箱注册/xray_runtime \
      /app/云端注册邮箱

EXPOSE 8765

ENTRYPOINT ["outlook-docker-entrypoint"]
CMD ["dashboard"]
