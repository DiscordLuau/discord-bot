#!/bin/sh
set -e

if [ -z "$DISCORD_BOT_TOKEN" ]; then
    echo "ERROR: DISCORD_BOT_TOKEN environment variable is not set"
    exit 1
fi

printf 'return {\n\tDISCORD_BOT_TOKEN = "%s"\n}\n' "$DISCORD_BOT_TOKEN" > /app/.env.luau

exec zune run src/init.luau
