# Minecraft Docker Server

A Docker image for running Minecraft servers. Supports multiple server types: **Fabric**, **Paper**, **Spigot**, **NeoForge**, **Forge**, and **Vanilla**.

The image is automatically built and published to the GitHub Container Registry whenever a new stable Minecraft version is released.

## Quick Start

1. **Create a directory** for persistent server data:

   ```bash
   mkdir -p ./minecraft-data/mods
   ```

2. **Place your mod/plugin `.jar` files** into `./minecraft-data/mods/` (or `./minecraft-data/plugins/` for Paper/Spigot).

3. **Run the container**:

   ```bash
   docker run -d \
     --name minecraft-server \
     -p 25565:25565 \
     -v ./minecraft-data:/usr/local/minecraft \
     -e EULA=TRUE \
     -e SERVER_TYPE=paper \
     ghcr.io/shyrack/minecraft-docker-server-fabric:latest
   ```

> [!IMPORTANT]
> Always mount a volume at `/usr/local/minecraft`. Without it, your world saves, configs, and player data will be lost when the container is stopped or removed.

## Server Types

Set the `SERVER_TYPE` environment variable to choose your server:

| Value | Server | Data Directory |
|-------|--------|----------------|
| `fabric` | Fabric | `mods/` |
| `paper` | Paper | `plugins/` |
| `spigot` | Spigot | `plugins/` |
| `neoforge` | NeoForge | `mods/` |
| `forge` | Forge | `mods/` |
| `vanilla` | Vanilla | none |

Default: `fabric`

### Provider-Specific Configuration

#### Fabric

| Variable | Default | Description |
|---|---|---|
| `MINECRAFT_VERSION` | `latest` | Minecraft game version |
| `FABRIC_LOADER` | `latest` | Fabric Loader version |
| `FABRIC_INSTALLER` | `latest` | Fabric Installer version |

#### Paper

| Variable | Default | Description |
|---|---|---|
| `MINECRAFT_VERSION` | `latest` | Minecraft game version |
| `PAPER_BUILD` | `latest` | Paper build number |

#### Spigot

| Variable | Default | Description |
|---|---|---|
| `MINECRAFT_VERSION` | `latest` | Minecraft game version |

#### NeoForge

| Variable | Default | Description |
|---|---|---|
| `NEOFORGE_VERSION` | `latest` | NeoForge version (e.g. `1.21.4-3.0.16`) |
| `MINECRAFT_VERSION` | `latest` | Minecraft version (extracted from `NEOFORGE_VERSION` when `latest`) |

#### Forge

| Variable | Default | Description |
|---|---|---|
| `MINECRAFT_VERSION` | `latest` | Minecraft game version |
| `FORGE_VERSION` | `latest` | Forge version (e.g. `54.0.0`) |

#### Vanilla

| Variable | Default | Description |
|---|---|---|
| `MINECRAFT_VERSION` | `latest` | Minecraft game version |

## Image Tags

| Tag | Description |
|-----|-------------|
| `latest` | Latest stable Minecraft version |
| `main` | Latest commit on the `main` branch |
| `<mc>` | Specific Minecraft version, e.g. `1.21.4` |

## Persistent Data

Mount a host directory to `/usr/local/minecraft` to persist all server files:

```
minecraft-data/
├── mods/           # Fabric/Forge/NeoForge mod .jar files
├── plugins/        # Paper/Spigot plugin .jar files
├── config/         # Mod and server configs
├── world/          # World save data
├── eula.txt        # EULA acceptance
├── server.properties
├── ops.json
├── whitelist.json
└── ...
```

## Configuration

### Memory

By default, the container auto-detects the available memory (respecting Docker memory limits) and reserves 1 GB for the operating system. You can control this with:

| Environment Variable | Default | Description |
|-----------------------|--------|-------------|
| `MEMORY` | (auto) | Heap size in Java format, e.g. `4G` or `2048M` |
| `SYSTEM_RESERVED` | `1G` | Memory reserved for the OS when `MEMORY` is unset |

### EULA

Set `EULA=TRUE` to accept the [Minecraft EULA](https://aka.ms/MinecraftEULA). The server will refuse to start without it.

## Building Locally

```bash
bash build.sh
```

Or manually:

```bash
docker build -t minecraft-server:latest .
```

## Tests

```bash
bash tests/test_entrypoint.sh
bash tests/test_providers.sh
```

## Healthcheck

The image includes a `HEALTHCHECK` with sensible defaults. To override them, use the `--health-*` flags at container run time:

| Flag | Default | Description |
|------|---------|-------------|
| `--health-interval` | `30s` | Interval between health checks |
| `--health-timeout` | `10s` | Health check command timeout |
| `--health-start-period` | `300s` | Grace period before first check |
| `--health-retries` | `3` | Consecutive failures before unhealthy |

Example:
```bash
docker run -d … --health-start-period=600s --health-interval=60s …
```

## Security

Server JARs are downloaded at container startup over HTTPS. Downloaded files are checked for basic integrity (non-empty, valid ZIP header). If you require stronger integrity guarantees, consider building the image with a pre-downloaded JAR and verifying its hash against a known-good source.

## Issues

Found a bug or have a suggestion? Please [open an issue](https://github.com/shyrack/minecraft-docker-server-fabric/issues).

## Disclaimer

This project is not affiliated with, endorsed by, or sponsored by Mojang AB, Microsoft Corporation, or any of the server projects. "Minecraft" is a registered trademark of Mojang AB.
