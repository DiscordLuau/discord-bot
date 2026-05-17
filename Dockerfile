FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    libdbus-1-3 \
    libopus0 \
    && rm -rf /var/lib/apt/lists/*

# Install zune (Luau runtime) - version pinned to match rokit.toml
RUN curl -fsSL "https://github.com/Scythe-Technology/zune/releases/download/v0.5.6/zune-0.5.6-linux-x86_64.zip" \
    -o /tmp/zune.zip \
    && unzip -j /tmp/zune.zip "zune" -d /usr/local/bin \
    && chmod +x /usr/local/bin/zune \
    && rm /tmp/zune.zip

# Install pesde (Luau package manager)
RUN curl -fsSL "https://github.com/pesde-pkg/pesde/releases/download/v0.7.3%2Bregistry.0.2.3/pesde-0.7.3-linux-x86_64.zip" \
    -o /tmp/pesde.zip \
    && unzip -j /tmp/pesde.zip "pesde" -d /usr/local/bin \
    && chmod +x /usr/local/bin/pesde \
    && rm /tmp/pesde.zip

RUN zune setup

WORKDIR /app

COPY .luaurc zune.yml ./
COPY .zune/ ./.zune/
COPY patches/ ./patches/
COPY pesde.toml pesde.lock ./
COPY luau_packages/ ./luau_packages/
COPY src/ ./src/

# The bundled libopus requires GLIBC_2.43 but Ubuntu 24.04 only has 2.39.
# Replace it with the system libopus which is compatible.
RUN ln -sf /usr/lib/x86_64-linux-gnu/libopus.so.0 \
    luau_packages/.pesde/discord_luau+opus/0.0.1/opus/binaries/Linux-X64/lib/libopus.so

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# bot.db lives at /app/bot.db - mount a volume here to persist it across restarts
# docker run: -v ./bot.db:/app/bot.db
# docker compose: see the volumes section below
VOLUME ["/app/bot.db"]

# Pass your bot token via: -e DISCORD_BOT_TOKEN=your_token
ENTRYPOINT ["docker-entrypoint.sh"]
