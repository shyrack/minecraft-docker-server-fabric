# Minecraft Docker Server (Fabric)

A Docker image for running a Fabric Minecraft server. The image is automatically built and published to the GitHub Container Registry whenever a new stable Minecraft or Fabric Loader version is released.

## Quick Start

1. **Create a directory** for persistent server data (worlds, configs, mods, etc.):

   ```bash
   mkdir -p ./minecraft-data/mods
   ```

2. **Place your Fabric mod `.jar` files** into `./minecraft-data/mods/`.

3. **Accept the Minecraft EULA** by setting the `EULA` environment variable to `TRUE`.

4. **Run the container** using the pre-built image from `ghcr.io`:

   ```bash
   docker run -d \
     --name minecraft-fabric \
     -p 25565:25565 \
     -v ./minecraft-data:/usr/local/minecraft \
     -e EULA=TRUE \
     ghcr.io/shyrack/minecraft-docker-server-fabric:latest
   ```

> [!IMPORTANT]
> Always mount a volume at `/usr/local/minecraft` (`-v` flag above). Without it, your world saves, configs, and player data will be lost when the container is stopped or removed.

## Image Tags

| Tag           | Description                                                  |
|---------------|--------------------------------------------------------------|
| `latest`      | Latest stable Minecraft + latest stable Fabric Loader        |
| `main`        | Latest commit on the `main` branch                           |
| `<mc>-fabric-<loader>` | Specific combination, e.g. `1.21.4-fabric-0.16.10` |

Find all available tags on the [package page](https://github.com/shyrack/minecraft-docker-server-fabric/pkgs/container/minecraft-docker-server-fabric).

## Persistent Data

Mount a host directory to `/usr/local/minecraft` to persist all server files:

```
minecraft-data/
├── mods/           # Fabric mod .jar files
├── config/         # Mod and server configs
├── world/          # World save data
├── eula.txt        # EULA acceptance
├── server.properties
├── ops.json
├── whitelist.json
└── ...
```

## Mods

Place your Fabric mod `.jar` files in the `mods/` subdirectory of your mounted data folder (e.g. `./minecraft-data/mods/`). Add or remove mods on the host and restart the container to apply changes:

```bash
docker restart minecraft-fabric
```

## Configuration

### Memory

By default, the container auto-detects the available memory (respecting Docker memory limits) and reserves 1 GB for the operating system. You can control this with:

| Environment Variable | Default | Description                                      |
|-----------------------|--------|--------------------------------------------------|
| `MEMORY`             | (auto)  | Heap size in Java format, e.g. `4G` or `2048M`   |
| `SYSTEM_RESERVED`    | `1G`    | Memory reserved for the OS when `MEMORY` is unset |

### EULA

Set `EULA=TRUE` to accept the [Minecraft EULA](https://aka.ms/MinecraftEULA). The server will refuse to start without it.

### Version Pinning

Override the Minecraft and Fabric versions at runtime (the JAR is downloaded on first start):

| Environment Variable   | Default   | Description                  |
|------------------------|-----------|------------------------------|
| `MINECRAFT_VERSION`    | `latest`  | Target Minecraft game version |
| `FABRIC_LOADER`        | `latest`  | Fabric Loader version         |
| `INSTALLER_VERSION`    | `latest`  | Fabric Installer version      |

## Building Locally

If you prefer to build the image yourself:

```bash
bash build.sh
```

Or manually:

```bash
docker build \
  --build-arg MINECRAFT_VERSION=latest \
  --build-arg FABRIC_LOADER=latest \
  -t minecraft-fabric:latest \
  .
```

## Tests

```bash
bash tests/test_entrypoint.sh
```

## Issues

Found a bug or have a suggestion? Please [open an issue](https://github.com/shyrack/minecraft-docker-server-fabric/issues).

### Healthcheck

Tune the container healthcheck via build-time arguments. These apply at build time only.

| Build Argument     | Default  | Description                          |
|--------------------|----------|--------------------------------------|
| `HC_INTERVAL`      | `30s`    | Interval between health checks       |
| `HC_TIMEOUT`       | `10s`    | Health check command timeout         |
| `HC_START_PERIOD`  | `300s`   | Grace period before first check      |
| `HC_RETRIES`       | `3`      | Consecutive failures before unhealthy |

Example:
```bash
docker build --build-arg HC_START_PERIOD=600s --build-arg HC_INTERVAL=60s …
```

## Security

The Fabric server JAR is downloaded at container startup from `meta.fabricmc.net` over HTTPS. The downloaded file is checked for basic integrity (non-empty, valid ZIP header). If you require stronger integrity guarantees, consider building the image with a pre-downloaded JAR and verifying its hash against a known-good source.

## Disclaimer

This project is not affiliated with, endorsed by, or sponsored by Mojang AB, Microsoft Corporation, or the FabricMC project. "Minecraft" is a registered trademark of Mojang AB.
