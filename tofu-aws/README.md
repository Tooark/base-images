# tofu-aws

Base image with `tofu` (OpenTofu CLI), `aws` (AWS CLI v2), and `kubectl`, ready to use in pipelines and ad-hoc container runs.

> This is the direct replacement for `terraform-aws`. The `terraform-aws` family is now legacy and should be avoided in new workflows.

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/tofu-aws/README.pt-BR.md)

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

- **OpenTofu**, **AWS CLI v2**, and **kubectl** in the same image
- Minimal Debian base with a non-root user
- Compatible with linux/amd64 and linux/arm64

---

## Image tags

| Tag                                           | Description   |
| --------------------------------------------- | ------------- |
| `ghcr.io/tooark/tofu-aws:<MAJOR.MINOR.PATCH>` | Full version  |
| `ghcr.io/tooark/tofu-aws:<MAJOR.MINOR>`       | Short version |
| `ghcr.io/tooark/tofu-aws:<MAJOR>`             | Major track   |
| `ghcr.io/tooark/tofu-aws:latest`              | Latest stable |

---

## Image contents

| Item              | Description                                                     |
| ----------------- | --------------------------------------------------------------- |
| Base              | `debian:13-slim`                                                |
| OpenTofu CLI      | `/usr/local/bin/tofu`                                           |
| AWS CLI v2        | `/usr/local/aws-cli/v2/current/bin/aws`                         |
| kubectl           | `/usr/local/bin/kubectl`                                        |
| Symlink           | `/usr/local/bin/aws` -> `/usr/local/aws-cli/v2/current/bin/aws` |
| Runtime deps      | `ca-certificates`, `gosu`                                       |
| Default user      | `app` (non-root)                                                |
| Family identifier | `ARK_IMAGE_FAMILY=tofu-aws`                                     |

---

## Quick start

Check the installed versions:

```bash
docker run --rm ghcr.io/tooark/tofu-aws:latest tofu version
docker run --rm ghcr.io/tooark/tofu-aws:latest aws --version
docker run --rm ghcr.io/tooark/tofu-aws:latest kubectl version --client
```

Initialize an OpenTofu directory (mount your code):

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu-aws:latest tofu init
```

Run a plan:

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu-aws:latest tofu plan
```

### Passing credentials to the container

Via environment variables:

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  -e AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
  -e AWS_REGION=us-east-1 \
  ghcr.io/tooark/tofu-aws:latest aws sts get-caller-identity --no-cli-pager
```

Use `kubectl get` with a mounted kubeconfig:

```bash
docker run --rm \
  -v "$HOME/.kube/config:/home/app/.kube/config:ro" \
  ghcr.io/tooark/tofu-aws:latest kubectl get nodes --request-timeout=10s
```

To use `kubectl`, you can also mount a kubeconfig at `/home/app/.kube/config`.

---

## Environment variables

### AWS CLI

| Variable                | Default     | Description        |
| ----------------------- | ----------- | ------------------ |
| `AWS_ACCESS_KEY_ID`     | -           | AWS access key     |
| `AWS_SECRET_ACCESS_KEY` | -           | AWS secret key     |
| `AWS_SESSION_TOKEN`     | -           | AWS session token  |
| `AWS_REGION`            | `us-east-1` | Default AWS region |

---

## Pipelines

### GitHub Actions

#### Basic example (GH)

```yaml
name: Tofu Deploy

on:
  push:
    branches: [main]
  pull_request:

jobs:
  tofu:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu-aws:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_REGION: us-east-1
    steps:
      - uses: actions/checkout@v4

      - name: Tofu Init
        run: tofu init

      - name: Tofu Plan
        run: tofu plan -out=tfplan

      - name: Tofu Apply
        if: github.ref == 'refs/heads/main'
        run: tofu apply tfplan
```

#### Example with EKS deployment (GH)

```yaml
name: Deploy to EKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu-aws:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_REGION: us-east-1
    steps:
      - uses: actions/checkout@v4

      - name: Tofu Init
        run: tofu init

      - name: Tofu Plan
        run: tofu plan -out=tfplan

      - name: Tofu Apply
        if: github.ref == 'refs/heads/main'
        run: tofu apply tfplan

      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER }}
          kubectl apply -f k8s/

      - name: Verify deployment
        run: kubectl rollout status deployment/${{ vars.APP_NAME }} --timeout=120s
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

tofu_plan:
  stage: validate
  image: ghcr.io/tooark/tofu-aws:latest
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

tofu_apply:
  stage: deploy
  image: ghcr.io/tooark/tofu-aws:latest
  script:
    - tofu init
    - tofu apply tfplan
  dependencies:
    - tofu_plan
  only:
    - main
  when: manual
```

---

## Local build

```bash
version="1.0.0"   # tofu-aws
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg TOFU_AWS_VERSION=$version \
  --build-arg OPENTOFU_VERSION=1.12.1 \
  --build-arg AWSCLI_VERSION=2.34.60 \
  --build-arg KUBECTL_VERSION=1.36.1 \
  -t tofu-aws:$version \
  -t tofu-aws:$short \
  -t tofu-aws:latest \
  ./tofu-aws
```

---

## Official documentation

- [OpenTofu](https://opentofu.org/docs/)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)

---

## License

MIT - see the [LICENSE](../LICENSE) file at the repository root.

<!-- markdownlint-enable MD060 -->
