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

# Install yt-dlp and deno (yt-dlp solves YouTube's JavaScript challenges with deno on PATH), each checked by sha256
RUN curl -fsSL "https://github.com/yt-dlp/yt-dlp/releases/download/2026.10.21/yt-dlp_linux" \
    -o /usr/local/bin/yt-dlp \
    && echo "d8bd33fca9d5b23bd5b9952b3fca36db5c46331933fda9f598a3da14ce2c243f  /usr/local/bin/yt-dlp" | sha256sum -c - \
    && chmod +x /usr/local/bin/yt-dlp

RUN curl -fsSL "https://github.com/denoland/deno/releases/download/v2.9.8/deno-x86_64-unknown-linux-gnu.zip" \
    -o /tmp/deno.zip \
    && echo "e890975bc2549807bbcc0b584ffafda72cc7c93349dd99c80483dd784f6c4609  /tmp/deno.zip" | sha256sum -c - \
    && unzip -j /tmp/deno.zip "deno" -d /usr/local/bin \
    && chmod +x /usr/local/bin/deno \
    && rm /tmp/deno.zip

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

# discord-luau loads its voice libraries (libdave, libopus, libsodium) when it is first required, and audio loads
# libsymphonia on first use, downloading them into /root/.cache. Doing that here bakes them into the image, so the
# bot starts without reaching GitHub and a failed download or checksum stops the build instead of the bot.
RUN printf 'local _ = require("./luau_packages/discord")\nrequire("./luau_packages/audio").loadFileDecoder()\n' > preload.luau \
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
