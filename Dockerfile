FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    libdbus-1-3 \
    && rm -rf /var/lib/apt/lists/*

# Install zune (Luau runtime) - version pinned to match rokit.toml
RUN curl -fsSL "https://github.com/Scythe-Technology/zune/releases/download/v0.5.9/zune-0.5.9-linux-x86_64.zip" \
    -o /tmp/zune.zip \
    && unzip -j /tmp/zune.zip "zune" -d /usr/local/bin \
    && chmod +x /usr/local/bin/zune \
    && rm /tmp/zune.zip

# Install pesde (Luau package manager)
RUN curl -fsSL "https://github.com/pesde-pkg/pesde/releases/download/v0.7.4%2Bregistry.0.2.3/pesde-0.7.4-linux-x86_64.zip" \
    -o /tmp/pesde.zip \
    && unzip -j /tmp/pesde.zip "pesde" -d /usr/local/bin \
    && chmod +x /usr/local/bin/pesde \
    && rm /tmp/pesde.zip

RUN zune setup

RUN git config --global user.email "docker@build" && \
    git config --global user.name "Docker"

WORKDIR /app

COPY .luaurc zune.yml ./
COPY .zune/ ./.zune/
COPY patches/ ./patches/
COPY pesde.toml pesde.lock ./
COPY src/ ./src/
RUN pesde install

# discord-luau loads its voice libraries (libdave, libopus, libsodium) when it is first required, downloading
# them into /root/.cache. Doing that here bakes them into the image, so the bot starts without reaching GitHub
# and a failed download or checksum stops the build instead of the bot.
RUN printf 'local _ = require("./luau_packages/discord")\n' > preload.luau \
    && zune run preload.luau \
    && rm preload.luau

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# bot.db lives at /app/bot.db - mount a volume here to persist it across restarts
# docker run: -v ./bot.db:/app/bot.db
# docker compose: see the volumes section below
VOLUME ["/app/bot.db"]

# Pass your bot token via: -e DISCORD_BOT_TOKEN=your_token
ENTRYPOINT ["docker-entrypoint.sh"]
