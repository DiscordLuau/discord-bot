<div align="center" id="toc">
<p>
	<img align="right" src="https://raw.githubusercontent.com/DiscordLuau/docs/master/src/assets/vector.svg" width="256" alt="discord-luau"/>
</p>
<div align="left">
<ul style="list-style: none;">
    <summary>
      <h1>DiscordLuau</h1>
    </summary>
  </ul>
</div>
</div>

<a href="https://discord.gg/DpQwdD8zD3"><img alt="Discord" src="https://img.shields.io/discord/385151591524597761?style=plastic&logo=discord&color=%235865F2"></a>

The official support bot for the [discord-luau](https://github.com/DiscordLuau/discord-luau) Discord server.

## Running locally

Install [zune](https://github.com/Scythe-Technology/zune) and [pesde](https://github.com/pesde-pkg/pesde), then:

```sh
pesde install
touch .env.luau  # add your DISCORD_BOT_TOKEN
zune run src/init.luau
```

`.env.luau` must export a table with a `DISCORD_BOT_TOKEN` key:

```lua
return {
    DISCORD_BOT_TOKEN = "your_token_here"
}
```

## Docker

Build and run a one-off container:

```sh
docker build -t discord-bot .
docker run -e DISCORD_BOT_TOKEN=your_token -v ./bot.db:/app/bot.db discord-bot
```

`bot.db` is mounted as a volume so it persists across container restarts. If the file does not exist yet, create it first:

```sh
touch bot.db
```

## Docker Compose

Create a `.env` file in the same directory as this repository

```sh
touch .env
```

```env
DISCORD_BOT_TOKEN=your_token_here
```

Then start the bot:

```sh
docker compose up -d
```

To rebuild after a code change:

```sh
docker compose up --build -d
```

Logs:

```sh
docker compose logs -f
```