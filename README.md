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

By default, the container auto-detects the available memory (respecting Docker memory limits)
and reserves a dynamic amount for the OS/JVM non-heap overhead:

- **15% of container limit** when that falls between 512 MB and 1 GB
- **Minimum 512 MB** (for small containers; heap is also floor-clamped to 512 MB)
- **Maximum 1 GB** (for containers above ~7 GB)

You can override the reservation by explicitly setting `SYSTEM_RESERVED`.

| Environment Variable | Default | Description |
|-----------------------|--------|-------------|
| `MEMORY` | (auto) | Heap size, e.g. `4G`, `2048M`, or `75%` for percentage-based |
| `INIT_MEMORY` | `MEMORY` | Initial heap size (separate from max) |
| `MAX_MEMORY` | `MEMORY` | Maximum heap size (separate from init) |
| `SYSTEM_RESERVED` | dynamic | Memory reserved for OS/JVM non-heap. Only used when `MEMORY` is unset (auto-detect). Defaults to 15% of container limit, clamped to [512 MB, 1 GB]. Set explicitly to override. |
| `JVM_OPTS` | (none) | Extra JVM options (e.g. `-Dfml.queryResult=confirm`) |
| `JVM_XX_OPTS` | (none) | Extra `-XX` JVM options (e.g. `-XX:+UseLargePages`) |

| Container limit | Reserved (dynamic default) | Java heap |
|------------------|---------------------------|-----------|
| 1 GB | 512 MB | 512 MB |
| 2 GB | 512 MB | 1.5 GB |
| 3 GB | 512 MB | 2.5 GB |
| 4 GB | 614 MB | 3.4 GB |
| 6 GB | 921 MB | 5.1 GB |
| 8 GB | 1 GB | 7 GB |
| 16 GB | 1 GB | 15 GB |

**Examples:**

```bash
# Fixed 4 GB heap
-e MEMORY=4G

# Separate init and max heap
-e INIT_MEMORY=1G -e MAX_MEMORY=4G

# Percentage-based (75% of container memory limit)
-e MEMORY=75%

# Custom JVM options
-e JVM_OPTS="-Dfml.queryResult=confirm"
```

The container automatically tunes G1 GC flags (Aikar's flags) based on heap size
(standard variant for <12 GB, >12 GB variant for larger heaps).

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
