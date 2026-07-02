# tofu

Base image with `tofu` (OpenTofu CLI), ready to use in pipelines and ad-hoc container runs.

> This is the recommended image for new workflows. The `terraform` family is now legacy and will be kept for compatibility only.

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/terraform/README.pt-BR.md)

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

- **OpenTofu CLI** ready to run in CI/CD
- Minimal Debian base with a non-root user
- Compatible with linux/amd64 and linux/arm64
- Keeps the automation variables compatible with the Terraform workflow

---

## Image tags

| Tag                                       | Description   |
| ----------------------------------------- | ------------- |
| `ghcr.io/tooark/tofu:<MAJOR.MINOR.PATCH>` | Full version  |
| `ghcr.io/tooark/tofu:<MAJOR.MINOR>`       | Short version |
| `ghcr.io/tooark/tofu:<MAJOR>`             | Major track   |
| `ghcr.io/tooark/tofu:latest`              | Latest stable |

## Image contents

| Item              | Description               |
| ----------------- | ------------------------- |
| Base              | `debian:13-slim`          |
| OpenTofu CLI      | `/usr/local/bin/tofu`     |
| Runtime deps      | `ca-certificates`, `gosu` |
| Default user      | `app` (non-root)          |
| Family identifier | `ARK_IMAGE_FAMILY=tofu`   |

---

## Quick start

Check the OpenTofu version:

```bash
docker run --rm ghcr.io/tooark/tofu:latest tofu version
```

Initialize a working directory (mount your code):

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu:latest tofu init
```

Run a plan:

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu:latest tofu plan
```

> Tip: To cache providers between runs, mount a persistent directory at `/home/app/.terraform.d`.

---

## Pipelines

### GitHub Actions

#### Basic example (GH)

```yaml
name: OpenTofu

on:
  push:
    branches: [main]
  pull_request:

jobs:
  plan:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu:latest
    steps:
      - uses: actions/checkout@v4

      - name: OpenTofu Init
        run: tofu init

      - name: OpenTofu Plan
        run: tofu plan -out=tfplan

      - name: OpenTofu Apply
        if: github.ref == 'refs/heads/main'
        run: tofu apply tfplan
```

### GitLab CI

#### Basic example (GL)

```yaml
stages:
  - validate
  - deploy

opentofu_plan:
  stage: validate
  image: ghcr.io/tooark/tofu:latest
  script:
    - tofu init
    - tofu validate
    - tofu plan -out=tfplan
  artifacts:
    paths:
      - tfplan
  only:
    - merge_requests
    - main

opentofu_apply:
  stage: deploy
  image: ghcr.io/tooark/tofu:latest
  script:
    - tofu init
    - tofu apply tfplan
  dependencies:
    - opentofu_plan
  only:
    - main
  when: manual
```

---

## Local build

```bash
version="1.12.1"   # OpenTofu
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg OPENTOFU_VERSION=$version \
  -t tofu:$version \
  -t tofu:$short \
  -t tofu:latest \
  ./tofu
```

---

## Official documentation

- [OpenTofu](https://opentofu.org/docs/)
  - [Releases](https://github.com/opentofu/opentofu/releases)

---

## License

MIT - see the `LICENSE` file at the repository root.
