# Minecraft Docker Server (Fabric)

A Docker image for running a Fabric Minecraft server.

## Usage

```bash
docker build -t minecraft-fabric .

mkdir -p ./mods   # drop your Fabric mod .jar files here

docker run -d \
  --name minecraft \
  -p 25565:25565 \
  -v minecraft-data:/usr/local/minecraft \
  -v ./mods:/usr/local/minecraft/mods \
  -e EULA=TRUE \
  minecraft-fabric
```

> [!IMPORTANT]
> Always mount a volume at `/usr/local/minecraft` (`-v` flag above). Without it, your world saves, configs, and player data will be lost when the container is restarted or removed.

## Mods

Place your Fabric mod `.jar` files in a local `./mods/` directory and bind-mount it with `-v ./mods:/usr/local/minecraft/mods` at runtime (as shown above). Add or remove mods on the host and restart the container to apply changes.

## Issues

Found a bug or have a suggestion? Please [open an issue](https://github.com/shyrack/minecraft-docker-server-fabric/issues).

## Security

The Fabric server JAR is downloaded at container startup from `meta.fabricmc.net`
over HTTPS. No checksum or signature verification is performed on the download.
If you require stronger integrity guarantees, consider building the image with a
pre-downloaded JAR and verifying its hash against a known-good source.

## Disclaimer

This project is not affiliated with, endorsed by, or sponsored by Mojang AB,
Microsoft Corporation, or the FabricMC project. "Minecraft" is a registered
trademark of Mojang AB.

## Privacy / DSGVO

Running a Minecraft server processes personal data (IP addresses, usernames,
chat messages, etc.). As the server operator, you are the data controller
(Art. 4 Nr. 7 DSGVO) and should:

- Inform players about what data you collect and why
- Establish a legal basis for processing (Art. 6 DSGVO)
- Respect data subject rights (access, deletion, rectification)
- Consider minimizing log retention

This project does not collect or process any user data itself.
