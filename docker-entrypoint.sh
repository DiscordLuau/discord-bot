#!/bin/sh
set -e

if [ -z "$DISCORD_BOT_TOKEN" ]; then
    echo "ERROR: DISCORD_BOT_TOKEN environment variable is not set"
    exit 1
fi

printf 'return {\n\tDISCORD_BOT_TOKEN = "%s"\n}\n' "$DISCORD_BOT_TOKEN" > /app/.env.luau

# yt-dlp writes its cookie jar back when it exits, so it gets a writable copy of the read-only mount
if [ -e /run/youtube-cookies.txt ]; then
    export YOUTUBE_COOKIES_PATH=/tmp/youtube-cookies.txt
fi

if [ -f /run/youtube-cookies.txt ]; then
    install -m 600 /run/youtube-cookies.txt /tmp/youtube-cookies.txt
fi

exec zune run src/init.luau
