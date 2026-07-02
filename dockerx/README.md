# dockerx

Base image with `docker` (Docker CLI) and `docker buildx`, ready to use in
pipelines and ad-hoc container runs.

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/dockerx/README.pt-BR.md)

---

## Table of contents

- [Features](#features)
- [Image tags](#image-tags)
- [Image contents](#image-contents)
- [Quick start](#quick-start)
- [Pipelines](#pipelines)
- [Local build](#local-build)
- [Official documentation](#official-documentation)
- [License](#license)

---

## Features

- **Docker CLI** and **Docker Buildx** ready to use in CI/CD
- Minimal Debian base with a non-root user
- Compatible with linux/amd64 and linux/arm64

---

## Image tags

| Tag                                          | Description   |
| -------------------------------------------- | ------------- |
| `ghcr.io/tooark/dockerx:<MAJOR.MINOR.PATCH>` | Full version  |
| `ghcr.io/tooark/dockerx:<MAJOR.MINOR>`       | Short version |
| `ghcr.io/tooark/dockerx:<MAJOR>`             | Major track   |
| `ghcr.io/tooark/dockerx:latest`              | Latest stable |

## Image contents

| Item              | Description                                           |
| ----------------- | ----------------------------------------------------- |
| Base              | `debian:13-slim`                                      |
| Docker CLI        | `/usr/local/bin/docker`                               |
| Docker Buildx     | `/usr/local/libexec/docker/cli-plugins/docker-buildx` |
| Runtime deps      | `ca-certificates`, `git`, `gosu`                      |
| Default user      | `app` (non-root)                                      |
| Family identifier | `ARK_IMAGE_FAMILY=dockerx`                            |

---

## Quick start

Check the Docker CLI and Buildx versions:

```bash
docker run --rm ghcr.io/tooark/dockerx:latest docker --version
docker run --rm ghcr.io/tooark/dockerx:latest docker buildx version
```

List builders (with access to the Linux host's Docker socket):

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/tooark/dockerx:latest docker buildx ls
```

The image's `docker-entrypoint.sh` automatically syncs the `/var/run/docker.sock`
GID and runs as the non-root user (`app`).

Multi-architecture build and push with Buildx:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD":/workspace \
  -w /workspace \
  -e DOCKER_BUILDKIT=1 \
  ghcr.io/tooark/dockerx:latest \
  sh -c 'docker buildx create --name ci-builder --driver docker-container --use --bootstrap || docker buildx use ci-builder; docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/org/app:latest --push .'
```

## Pipelines

### GitHub Actions

#### Basic example (GH)

```yaml
name: Docker Buildx

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/dockerx:latest
    steps:
      - uses: actions/checkout@v4

      - name: Show versions
        run: |
          docker --version
          docker buildx version
```

### GitLab CI

#### Basic example (GL)

```yaml
stages:
  - build

build_image:
  stage: build
  image: ghcr.io/tooark/dockerx:latest
  script:
    - docker --version
    - docker buildx version
```

---

## Local build

When building locally, publish equivalent tags for the same image (full version, short version, and `latest`).

```bash
version="29.1.1"       # DockerX
dockerVersion="29.5.2" # Docker CLI
buildxVersion="0.34.1" # Docker Buildx
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg DOCKERX_VERSION=$version \
  --build-arg DOCKER_VERSION=$dockerVersion \
  --build-arg DOCKER_BUILDX_VERSION=$buildxVersion \
  -t dockerx:$version \
  -t dockerx:$short \
  -t dockerx:latest \
  ./dockerx
```

---

## Official documentation

- [Docker CLI](https://docs.docker.com/reference/cli/docker/)
  - [Release notes](https://docs.docker.com/engine/release-notes/)
- [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/)
  - [Release notes](https://github.com/docker/buildx/releases/)

---

## License

MIT — see `LICENSE` at the repository root.
