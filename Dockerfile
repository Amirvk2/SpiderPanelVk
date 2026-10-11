FROM rust:1-slim-bookworm AS telemt-builder

ARG TELEMT_VERSION=3.5.14
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git build-essential clang cmake pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/* \
    && git clone --depth 1 --branch "${TELEMT_VERSION}" https://github.com/telemt/telemt.git /src/telemt \
    && cd /src/telemt \
    && cargo build --locked --release --bin telemt

FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential git curl ca-certificates libssl-dev zlib1g-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/TelegramMessenger/MTProxy.git /tmp/MTProxy \
    && make -C /tmp/MTProxy \
    && install -m 0755 /tmp/MTProxy/objs/bin/mtproto-proxy /usr/local/bin/mtproto-proxy \
    && rm -rf /tmp/MTProxy

COPY --from=telemt-builder /src/telemt/target/release/telemt /usr/local/bin/telemt
COPY --from=telemt-builder /src/telemt/LICENSE /usr/share/licenses/telemt/LICENSE
RUN chmod 0755 /usr/local/bin/telemt

COPY requirements.txt ./
RUN pip install -r requirements.txt

COPY . .
RUN python -m py_compile main.py

# SpiderPanel panel port is fixed at 8080. Telemt binds privately on loopback.
EXPOSE 8080
EXPOSE 443

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--no-access-log"]
