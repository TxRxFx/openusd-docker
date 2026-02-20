# OpenUSD build containers

This repository provides AlmaLinux 9 and Rocky Linux 9 Docker build images for compiling OpenUSD 25.05.1 from source.

Source tarball used by CI smoke tests:

- [OpenUSD v25.05.01 tarball](https://github.com/PixarAnimationStudios/OpenUSD/archive/refs/tags/v25.05.01.tar.gz)

## What is included

- Toolchain and build tools (`Development Tools`, `cmake`, `ninja-build`, `git`, `pkgconfig`)
- Python runtime pinned to `3.10.14` (`/opt/python/3.10.14/bin/python3.10`)
- Python packages for USD tooling: `PySide6==6.5.2`, `PyOpenGL`
- Core USD dependencies (`tbb`, `boost`, `OpenEXR`, `OpenImageIO`, `zlib`, GL/X11 dev packages)
- No AppImage packaging dependencies

## Dockerfiles

- `docker/Dockerfile.alma9`
- `docker/Dockerfile.rocky9`

## Local usage

Build Alma 9 image:

```bash
docker build -t openusd:alma9 -f docker/Dockerfile.alma9 .
```

Build Rocky 9 image:

```bash
docker build -t openusd:rocky9 -f docker/Dockerfile.rocky9 .
```

Run build container and compile OpenUSD tarball:

```bash
docker run --rm -it openusd:alma9 bash -lc '
  set -e
  curl -L https://github.com/PixarAnimationStudios/OpenUSD/archive/refs/tags/v25.05.01.tar.gz -o /tmp/OpenUSD.tar.gz
  mkdir -p /opt/src/OpenUSD
  tar -xzf /tmp/OpenUSD.tar.gz --strip-components=1 -C /opt/src/OpenUSD
  cmake -S /opt/src/OpenUSD -B /opt/src/OpenUSD/build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DPXR_ENABLE_PYTHON_SUPPORT=ON
  cmake --build /opt/src/OpenUSD/build --parallel
'
```

## GitLab CI/CD

The pipeline in `.gitlab-ci.yml` performs:

1. Build and push `alma9` and `rocky9` images to `$CI_REGISTRY_IMAGE`
2. Run `build_scripts/build_usd.py` inside the Alma image using Python 3.10.4

This validates that each image is suitable for OpenUSD source builds and removes all previous SimpleScreenRecorder/AppImage packaging steps.
