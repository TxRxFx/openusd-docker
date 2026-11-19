# OpenUSD Docker Images

Docker images used to provide consistent build and Rez environments for OpenUSD on Enterprise Linux 9.

This branch is focused on building and publishing the container images. OpenUSD compilation and artifact packaging are performed by downstream jobs that consume the published image; there is no local `build-openusd.sh` workflow in this branch.

## Images

The repository contains Dockerfiles for:

- `docker/Dockerfile.rocky9` - Rocky Linux 9.5 image, currently built by CI
- `docker/Dockerfile.alma9` - AlmaLinux 9.5 image, available for use but currently disabled in CI

Both Dockerfiles install the GCC 12 toolchain and the native dependencies used by OpenUSD builds, including CMake, Ninja, TBB, Boost, OpenEXR, OpenImageIO, Mesa, and X11 development libraries.

The Rocky Linux image also configures the shared Rez installation:

```text
REZ_ROOT=/opt/rez/current
REZ_CONFIG_FILE=/mnt/packages/.config/linux_rezconfig.py
```

It expects the Rez package mount at `/mnt/packages` when used by a build or test container.

## Building Locally

Build the Rocky Linux image from the repository root:

```bash
docker build \
  --build-arg PYTHON_VERSION=3.10.14 \
  -t openusd-rocky9 \
  -f docker/Dockerfile.rocky9 .
```

Build the AlmaLinux image instead:

```bash
docker build \
  --build-arg PYTHON_VERSION=3.10.14 \
  -t openusd-alma9 \
  -f docker/Dockerfile.alma9 .
```

The Dockerfiles accept build arguments for the OpenUSD version and related tool versions. The defaults currently target:

| Component | Version |
|-----------|---------|
| OpenUSD | `25.05.1` |
| Python | `3.10.14` |
| GCC toolset | `12` |
| Rez | `3.5.0` where configured by the image |

## GitLab CI

GitLab CI publishes the container image when changes are pushed to the `docker` branch and one of the Docker build inputs changes:

- `docker/Dockerfile.*`
- `.gitlab-ci.yml`

The job runs on a self-hosted Linux shell runner and uses Docker BuildKit. It authenticates to the GitLab container registry, pulls the previous image when available for layer caching, builds the image, pushes it, and then runs a smoke test against the shared package mount.

The current matrix enables Rocky Linux only:

```yaml
IMAGE_TAG: rocky9
DOCKERFILE: docker/Dockerfile.rocky9
```

The published image is tagged using this pattern:

```text
<registry-image>:<platform>-py<PYTHON_VERSION>-v<DOCKER_CONTAINER_VER>
```

With the current CI variables, the tag ends in `rocky9-py3.10.14-v2.2.0`.

The smoke test mounts `/mnt/packages` read-only, sets `REZ_RELEASE_PACKAGES_PATH=/opt/rez/packages`, and verifies that Rez can query a Python package:

```bash
rez-config packages_path
rez-search python-3
```

The pipeline is intentionally disabled on `gitlab.com`; it runs only on the project's own GitLab instance.

## Running the Published Image

After authenticating to the project's container registry, run the image with the package repository mounted:

```bash
docker run --rm -it \
  -v /mnt/packages:/mnt/packages:ro \
  -e REZ_RELEASE_PACKAGES_PATH=/opt/rez/packages \
  <published-image> \
  bash
```

Inside the container, `/opt/src` is the working directory and the configured Python and Rez tools are available to downstream build workflows.

## Repository Layout

```text
.
├── .gitlab-ci.yml              # Image build and publication pipeline
├── docker/
│   ├── Dockerfile.alma9       # AlmaLinux 9.5 image
│   └── Dockerfile.rocky9      # Rocky Linux 9.5 image
├── ARCHITECTURE.md             # Design and CI notes
└── README.md                   # This file
```

## Attribution

- **OpenUSD:** [Pixar Animation Studios](https://openusd.org)
- **Python:** [Python Software Foundation](https://python.org)
- **Base images:** [AlmaLinux](https://almalinux.org) and [Rocky Linux](https://rockylinux.org)
