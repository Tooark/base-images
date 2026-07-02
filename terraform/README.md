# terraform

Base image with `terraform` (Terraform CLI), ready to use in pipelines and
ad-hoc container runs.

> This family is now legacy. For new workflows, use [tofu/README.md](../tofu/README.md).

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

- **Terraform CLI** ready to run in CI/CD
- Minimal Debian base with a non-root user
- Compatible with linux/amd64 and linux/arm64

---

## Image tags

| Tag                                            | Description   |
| ---------------------------------------------- | ------------- |
| `ghcr.io/tooark/terraform:<MAJOR.MINOR.PATCH>` | Full version  |
| `ghcr.io/tooark/terraform:<MAJOR.MINOR>`       | Short version |
| `ghcr.io/tooark/terraform:<MAJOR>`             | Major track   |
| `ghcr.io/tooark/terraform:latest`              | Latest stable |

## Image contents

| Item              | Description                  |
| ----------------- | ---------------------------- |
| Base              | `debian:13-slim`             |
| Terraform CLI     | `/usr/local/bin/terraform`   |
| Runtime deps      | `ca-certificates`, `gosu`    |
| Default user      | `app` (non-root)             |
| Family identifier | `ARK_IMAGE_FAMILY=terraform` |

---

## Quick start

Check the Terraform version:

```bash
docker run --rm ghcr.io/tooark/terraform:latest terraform version
```

Initialize a working directory (mount your code):

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/terraform:latest terraform init
```

Run plan and apply:

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/terraform:latest terraform plan
```

> Tip: To cache plugins/providers between runs, mount a persistent directory at `/home/app/.terraform.d`.

---

## Pipelines

### GitHub Actions

#### Basic example (GH)

```yaml
name: Terraform

on:
  push:
    branches: [main]
  pull_request:

jobs:
  plan:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/terraform:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_REGION: us-east-1
    steps:
      - uses: actions/checkout@v4

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply tfplan
```

### GitLab CI

#### Basic example (GL)

```yaml
stages:
  - validate
  - deploy

variables:
  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
  AWS_REGION: us-east-1

terraform_plan:
  stage: validate
  image: ghcr.io/tooark/terraform:latest
  script:
    - terraform init
    - terraform validate
    - terraform plan -out=tfplan
  artifacts:
    paths:
      - tfplan
  only:
    - merge_requests
    - main

terraform_apply:
  stage: deploy
  image: ghcr.io/tooark/terraform:latest
  script:
    - terraform init
    - terraform apply tfplan
  dependencies:
    - terraform_plan
  only:
    - main
  when: manual
```

---

## Local build

```bash
version="1.15.5"   # Terraform
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg TERRAFORM_VERSION=$version \
  -t terraform:$version \
  -t terraform:$short \
  -t terraform:latest \
  ./terraform
```

---

## Official documentation

- [Terraform](https://developer.hashicorp.com/terraform/install#linux)
  - [Release notes](https://github.com/hashicorp/terraform/releases)

---

## License

MIT - see the `LICENSE` file at the repository root.
