# OpenUSD Build Containers

Docker build images for compiling OpenUSD from source on AlmaLinux 9 and Rocky Linux 9.

## Quick Start

Build OpenUSD for AlmaLinux 9:

```bash
./scripts/build-openusd.sh --platform alma9 --version 25.05.1 --output ./artifacts
```

Build OpenUSD for Rocky 9:

```bash
./scripts/build-openusd.sh --platform rocky9 --version 25.05.1 --output ./artifacts
```

Show help:

```bash
./scripts/build-openusd.sh --help
```

## Overview

This project provides:

- **Unified build script** (`scripts/build-openusd.sh`) – Single orchestration point for all build environments
- **Docker images** – Pre-configured compilation environments with dependencies
- **CI/CD integration** – GitLab CI and GitHub Actions workflows using the shared build script
- **Rez packaging** – Relocatable Python and OpenUSD packages with platform variants

**Key components:**
- OpenUSD 25.05.1
- Python 3.10.14 (compiled from source)
- GCC 12.3.0 via gcc-toolset-12
- AlmaLinux 9 & Rocky 9 Linux

## Build Script

The unified build script (`scripts/build-openusd.sh`) automates the complete build process:

```bash
./scripts/build-openusd.sh \
  --platform alma9              # Required: alma9 or rocky9
  --version 25.05.1             # Required: YY.MM.patch format
  --output ./artifacts          # Required: output directory
  [--skip-image-build]          # Optional: reuse existing Docker image
  [--dry-run]                   # Optional: show commands without executing
```

### Artifacts

Each platform produces:

```
artifacts/
└── alma9/
    ├── OpenUSD_install_25.05.1_alma9.tar.gz      # Runtime + development
    ├── OpenUSD_build_25.05.1_alma9.tar.gz        # Build artifacts for debugging
    ├── OpenUSD_3rdparty_25.05.1_alma9.tar.gz     # Third-party dependencies
    ├── Python_3.10.14_alma9.tar.gz               # Python runtime
    ├── build.log                                  # Build output
    ├── manifest.json                              # Build metadata & checksums
    └── rez/
        ├── python/3.10.14/alma9/
        └── openusd/25.05.1/alma9/
```

| Artifact | Purpose |
|----------|---------|
| `OpenUSD_install_*` | Runtime and development files |
| `OpenUSD_build_*` | Intermediate build artifacts (debugging) |
| `OpenUSD_3rdparty_*` | Dependencies (TBB, Boost, OpenEXR, etc.) |
| `Python_*` | Python 3.10.14 runtime |
| `build.log` | OpenUSD build output |
| `manifest.json` | Build info, versions, SHA-256 checksums |
| `rez/` | Rez package structures |

## Build Environment

### Dockerfiles

- `docker/Dockerfile.alma9` – AlmaLinux 9.5 base with all dependencies
- `docker/Dockerfile.rocky9` – Rocky Linux 9.5 base with all dependencies

Both include:
- GCC 12.x via gcc-toolset-12
- Python 3.10.14 (compiled from source to `/pipeline/el9/software/Python/3.10.14-GCCcore-12.3.0/`)
- Build tools (cmake, ninja, git, pkgconfig)
- Core dependencies (TBB, Boost, OpenEXR, OpenImageIO, GL/X11, Mesa)
- Python packages (Jinja2, PySide6 6.5.2, PyOpenGL)

### OpenUSD Build Configuration

The build script uses these OpenUSD flags:

```bash
--build-variant release   # Optimized build
--python                  # Python bindings
--usdview                 # Interactive viewer
--no-tests                # Exclude tests
--no-examples             # Exclude examples
--no-tutorials            # Exclude tutorials
--no-docs                 # Exclude documentation
--no-python-docs          # Exclude Python documentation
```

## CI/CD Pipelines

### GitLab CI

GitLab CI invokes the build script for version branch pushes.

**Stages:**
1. **compile** – Parallel builds for alma9 and rocky9
2. **deploy** – Copies Rez packages to `/pipeline/el9/rez-packages`

**Trigger:** Version branches matching `^\d{2}\.\d{2}\.\d+$`

**Configuration:**
- Artifacts retained for 14 days
- Self-hosted Docker runner required
- Rez deployment to shared filesystem

### GitHub Actions

GitHub Actions invokes the build script for version branch pushes or manual trigger.

**Jobs:**
1. **compile-usd** – Parallel builds for alma9 and rocky9

**Triggers:**
- Push to version branch (e.g., `25.05.1`)
- Manual workflow dispatch

**Configuration:**
- Artifacts retained for 14 days (GitHub Actions storage)
- Self-hosted Linux runner required
- No external registry deployment

## Requirements

### Host System

- OS: Linux (AlmaLinux 9, Rocky 9, or compatible)
- Bash 4.0+
- Docker Engine (recent version)
- Disk: 100GB+ free
- Memory: 16GB minimum (8GB possible but slower)
- Network: Internet access for downloads

### Docker Access

```bash
# Verify Docker is accessible
docker ps   # Should succeed without sudo
```

If needed:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Docker not found" | Install: `curl https://get.docker.com \| bash` |
| "Docker daemon not running" | Start: `sudo systemctl start docker` |
| "Invalid version format" | Use `YY.MM.patch` (e.g., `25.05.1` not `v25.05.1`) |
| Build timeout | Increase `timeout-minutes` in CI config or upgrade hardware |
| Incomplete artifacts | Check: `cat artifacts/alma9/manifest.json \| jq` |

## Rez Package Management

The build script generates Rez packages for relocatable Python and OpenUSD installations.

### Package Structure

Rez packages support OS variants (alma9, rocky9):

```bash
# Request Python for current platform
rez env python-3.10.14

# Request OpenUSD with Python dependency
rez env openusd-25.05.1

# Request specific OS variant
rez env python-3.10.14 os-alma9
```

Both `rez/python/package.py` and `rez/openusd/package.py` are included in the artifacts and should be deployed alongside the platform-specific installations.

## File Structure

```
.
├── .github/workflows/build.yml     # GitHub Actions
├── .gitlab-ci.yml                  # GitLab CI
├── docker/Dockerfile.alma9         # AlmaLinux 9 image
├── docker/Dockerfile.rocky9        # Rocky Linux 9 image
├── rez/python/package.py           # Python Rez package
├── rez/openusd/package.py          # OpenUSD Rez package
├── scripts/build-openusd.sh        # Unified build script
├── README.md                        # This file
└── artifacts/                      # Generated at runtime
```

## Attribution

- **OpenUSD:** [Pixar Animation Studios](https://openusd.org)
- **Python:** [Python Software Foundation](https://python.org)
- **Base images:** [AlmaLinux](https://almalinux.org), [Rocky Linux](https://rockylinux.org)
