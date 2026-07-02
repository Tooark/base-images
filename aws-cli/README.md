# aws-cli

Base image with `aws` (AWS CLI v2), `kubectl`, `docker`, and `docker buildx`,
ready to use in pipelines and ad-hoc container runs.

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/aws-cli/README.pt-BR.md)

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

- **AWS CLI v2**, **kubectl**, **Docker CLI**, and **Docker Buildx** in the same image
- Minimal Debian base with a non-root user
- Compatible with linux/amd64 and linux/arm64

---

## Image tags

| Tag                                          | Description   |
| -------------------------------------------- | ------------- |
| `ghcr.io/tooark/aws-cli:<MAJOR.MINOR.PATCH>` | Full version  |
| `ghcr.io/tooark/aws-cli:<MAJOR.MINOR>`       | Short version |
| `ghcr.io/tooark/aws-cli:<MAJOR>`             | Major track   |
| `ghcr.io/tooark/aws-cli:latest`              | Latest stable |

---

## Image contents

| Item              | Description                                                     |
| ----------------- | --------------------------------------------------------------- |
| Base              | `debian:13-slim`                                                |
| AWS CLI v2        | `/usr/local/aws-cli/v2/current/bin/aws`                         |
| kubectl           | `/usr/local/bin/kubectl`                                        |
| Docker CLI        | `/usr/local/bin/docker`                                         |
| Docker Buildx     | `/usr/local/libexec/docker/cli-plugins/docker-buildx`           |
| Symlink           | `/usr/local/bin/aws` -> `/usr/local/aws-cli/v2/current/bin/aws` |
| Runtime deps      | `ca-certificates`, `gosu`                                       |
| Default user      | `app` (non-root)                                                |
| Family identifier | `ARK_IMAGE_FAMILY=aws-cli`                                      |

---

## Quick start

Run `aws --version`:

```bash
docker run --rm ghcr.io/tooark/aws-cli:latest aws --version
```

Run an AWS CLI subcommand (e.g., `sts get-caller-identity`):

```bash
docker run --rm ghcr.io/tooark/aws-cli:latest aws sts get-caller-identity --no-cli-pager
```

Check the kubectl client version:

```bash
docker run --rm ghcr.io/tooark/aws-cli:latest kubectl version --client
```

Use `kubectl get` with a mounted kubeconfig (example):

```bash
docker run --rm \
  -v "$HOME/.kube/config:/home/app/.kube/config:ro" \
  ghcr.io/tooark/aws-cli:latest kubectl get nodes --request-timeout=10s
```

Check the Docker CLI version:

```bash
docker run --rm ghcr.io/tooark/aws-cli:latest docker --version
```

Check the Docker Buildx version:

```bash
docker run --rm ghcr.io/tooark/aws-cli:latest docker buildx version
```

### Passing credentials to the container

Via environment variables:

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  -e AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
  -e AWS_REGION=us-east-1 \
  ghcr.io/tooark/aws-cli:latest aws sts get-caller-identity --no-cli-pager
```

Mounting the host credentials directory (`~/.aws`):

```bash
# The image runs as the non-root user 'app'; mount into /home/app/.aws
docker run --rm \
  -v "$HOME/.aws:/home/app/.aws:ro" \
  ghcr.io/tooark/aws-cli:latest aws sts get-caller-identity --no-cli-pager
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
name: Deploy AWS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/aws-cli:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_REGION: us-east-1
    steps:
      - uses: actions/checkout@v4

      - name: Verify identity
        run: aws sts get-caller-identity --no-cli-pager

      - name: Deploy to S3
        run: aws s3 sync ./dist s3://${{ vars.BUCKET_NAME }} --delete
```

#### Example with kubectl (EKS) (GH)

```yaml
name: Deploy EKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/aws-cli:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_REGION: us-east-1
    steps:
      - uses: actions/checkout@v4

      - name: Configure kubeconfig via EKS
        run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER }} --no-cli-pager

      - name: Apply manifests
        run: kubectl apply -f k8s/

      - name: Check rollout
        run: kubectl rollout status deployment/${{ vars.APP_NAME }} --timeout=120s
```

### GitLab CI

#### Basic example (GL)

```yaml
stages:
  - deploy

deploy_s3:
  stage: deploy
  image: ghcr.io/tooark/aws-cli:latest
  variables:
    AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
    AWS_REGION: us-east-1
  script:
    - aws sts get-caller-identity --no-cli-pager
    - aws s3 sync ./dist s3://$BUCKET_NAME --delete
  only:
    - main
```

#### Example with kubectl (EKS) (GL)

```yaml
stages:
  - deploy

deploy_eks:
  stage: deploy
  image: ghcr.io/tooark/aws-cli:latest
  variables:
    AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
    AWS_REGION: us-east-1
  script:
    - aws eks update-kubeconfig --name $EKS_CLUSTER --no-cli-pager
    - kubectl apply -f k8s/
    - kubectl rollout status deployment/$APP_NAME --timeout=120s
  only:
    - main
```

---

## Local build

```bash
version="2.34.59"  # AWS CLI
kubectl="1.36.1"   # kubectl
docker="29.5.2"    # Docker CLI
buildx="0.34.1"    # Buildx
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg AWSCLI_VERSION=$version \
  --build-arg KUBECTL_VERSION=$kubectl \
  --build-arg DOCKER_VERSION=$docker \
  --build-arg DOCKER_BUILDX_VERSION=$buildx \
  -t aws-cli:$version \
  -t aws-cli:$short \
  -t aws-cli:latest \
  ./aws-cli
```

---

## Official documentation

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [Release notes](https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Release notes](https://kubernetes.io/releases/)
- [Docker CLI](https://docs.docker.com/reference/cli/docker/)
  - [Release notes](https://docs.docker.com/engine/release-notes/)
- [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/)
  - [Release notes](https://github.com/docker/buildx/releases/)

---

## License

MIT - see the `LICENSE` file at the repository root.
