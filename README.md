# BoxHarbor - Radarr

[![Docker Pulls](https://img.shields.io/docker/pulls/gaetanddr/radarr)](https://hub.docker.com/r/gaetanddr/radarr)
[![GitHub](https://img.shields.io/github/license/boxharbor/radarr)](https://github.com/BoxHarbor/radarr)

A lightweight, rootless-compatible Radarr container based on BoxHarbor's Alpine base image.

## Features

- 🪶 **Lightweight**: Alpine-based
- 🔒 **Rootless Compatible**: Works with Podman and Docker rootless
- 📁 **Persistent Config**: Store configuration in `/var/lib/radarr`
- 🌍 **Multi-arch**: Supports amd64, arm64
- 🔧 **Easy Customization**: Simple configuration management

## Quick Start

### Docker

```bash
docker run -d \
  --name radarr \
  -p 7878:7878 \
  -v $(pwd)/config:/var/lib/radarr \
  -e PUID=1000 \
  -e PGID=1000 \
  ghcr.io/boxharbor/radarr:latest
```

### Podman (Rootless)

```bash
podman run -d \
  --name radarr \
  -p 7878:7878 \
  -v $(pwd)/config:/var/lib/radarr:Z \
  -e PUID=1000 \
  -e PGID=1000 \
  ghcr.io/boxharbor/radarr:latest
```

### Docker Compose

```yaml
version: '3.8'

services:
  radarr:
    image: ghcr.io/boxharbor/radarr:latest
    container_name: radarr
    ports:
      - "7878:7878"
    volumes:
      - ./config:/config
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    restart: unless-stopped
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `TZ` | `UTC` | Timezone |

## Volumes

| Path | Description |
|------|-------------|
| `/config` | Radarr configuration files |

## Ports

| Port | Description |
|------|-------------|
| `7878` | HTTP |

## Configuration

### First Run

On first run, default configuration files are created to `/var/lib/radarr`.

## Troubleshooting

### Permission Denied

Ensure PUID/PGID match your host user:

```bash
id -u  # Get your UID
id -g  # Get your GID
```

Set these in your docker run command or compose file.

### Port Already in Use

Change the host port:

```bash
docker run -d -p 9090:7878 ghcr.io/boxharbor/radarr:latest
```

### Configuration Errors

Check logs:

```bash
docker logs radarr
# or
podman logs radarr
```

## Building from Source

```bash
git clone https://github.com/BoxHarbor/radarr.git
cd radarr
docker build -t boxharbor/radarr:latest .
```

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting PRs.

## License

GPL-3.0 License - see [LICENSE](LICENSE) file for details.

## Support

- 💬 GitHub Issues: [Report bugs or request features](https://github.com/BoxHarbor/radarr/issues)
- 📖 Base Image: [BoxHarbor baseimage-alpine](https://github.com/BoxHarbor/baseimage-alpine)

---

Built with ❤️ by the BoxHarbor team