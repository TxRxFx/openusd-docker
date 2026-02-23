# OpenUSD build containers

This repository provides AlmaLinux 9 and Rocky Linux 9 Docker build images for compiling OpenUSD 25.05.1 from source.

Source tarball used by CI smoke tests:

- [OpenUSD v25.05.01 tarball](https://github.com/PixarAnimationStudios/OpenUSD/archive/refs/tags/v25.05.01.tar.gz)

## What is included

- Toolchain and build tools (`Development Tools`, `cmake`, `ninja-build`, `git`, `pkgconfig`)
- Compiler toolchain pinned via `gcc-toolset-12` for GCC 12.x builds
- Python runtime pinned to `3.10.14` and compiled from source into `/pipeline/el9/software/Python/3.10.14-GCCcore-12.3.0`
- USD build Python executable path: `/pipeline/el9/software/Python/3.10.14-GCCcore-12.3.0/bin/python`
- Python packages for USD tooling: `PySide6==6.5.2`, `PyOpenGL`
- Core USD dependencies (`tbb`, `boost`, `OpenEXR`, `OpenImageIO`, `zlib`, GL/X11 dev packages)
- Hydra rendering support (OpenGL, X11 Toolkit, Mesa)
- USDview interactive viewer (Qt5/PySide6, PyOpenGL)
- No AppImage packaging dependencies

## Dockerfiles

- `docker/Dockerfile.alma9`
- `docker/Dockerfile.rocky9`

## Rez package definitions

- `rez/python/package.py`
- `rez/openusd/package.py`

Both package definitions support OS variants for `os-alma9` and `os-rocky9`.

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
2. Compile OpenUSD in both Alma 9 and Rocky 9 images using source-built Python at `/pipeline/el9/software/Python/3.10.14-GCCcore-12.3.0/bin/python`
3. Publish downloadable artifacts per OS, including compiled Python tarballs and OpenUSD install/build tarballs
4. Generate Rez package payloads for `python` and `openusd` with Alma/Rocky OS variant layout
5. Deploy Rez packages via a shell-runner deploy stage to `$REZ_DEPLOY_ROOT` (default `/pipeline/el9/rez-packages`)

This validates that each image is suitable for OpenUSD source builds and removes all previous SimpleScreenRecorder/AppImage packaging steps.

Note: Python 3.10.14 is intentionally compiled from source and installed in the fixed pipeline prefix so OpenUSD builds can reliably refer to a stable interpreter path across CI jobs.

## Artifact output layout

Compile jobs emit artifacts under `artifacts/alma9` and `artifacts/rocky9`:

- `Python_<version>_<os>.tar.gz`
- `OpenUSD_install_<version>_<os>.tar.gz`
- `OpenUSD_build_<version>_<os>.tar.gz`
- `rez/python/<python-version>/...`
- `rez/openusd/<usd-version>/...`

The deploy stage merges these into the Rez repository at `$REZ_DEPLOY_ROOT`.
