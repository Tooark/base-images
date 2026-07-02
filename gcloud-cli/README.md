# gcloud-cli

Base image with `gcloud` (Google Cloud SDK), `gsutil`, `bq`, `kubectl`, `docker`,
and `docker buildx`, ready to use in pipelines and ad-hoc container runs.

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/gcloud-cli/README.pt-BR.md)

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

- **Google Cloud SDK**, **kubectl**, **Docker CLI**, and **Buildx** in the same image
- Minimal Debian base with a non-root user
- Compatible with linux/amd64 and linux/arm64

---

## Image tags

| Tag                                             | Description   |
| ----------------------------------------------- | ------------- |
| `ghcr.io/tooark/gcloud-cli:<MAJOR.MINOR.PATCH>` | Full version  |
| `ghcr.io/tooark/gcloud-cli:<MAJOR.MINOR>`       | Short version |
| `ghcr.io/tooark/gcloud-cli:<MAJOR>`             | Major track   |
| `ghcr.io/tooark/gcloud-cli:latest`              | Latest stable |

---

## Image contents

| Item              | Description                                                    |
| ----------------- | -------------------------------------------------------------- |
| Base              | `debian:13-slim`                                               |
| Google Cloud SDK  | `/opt/google-cloud-sdk`                                        |
| kubectl           | `/usr/local/bin/kubectl`                                       |
| Docker CLI        | `/usr/local/bin/docker`                                        |
| Docker Buildx     | `/usr/local/libexec/docker/cli-plugins/docker-buildx`          |
| Symlink           | `gcloud`, `gsutil`, `bq` -> `/opt/google-cloud-sdk/bin/gcloud` |
| Runtime deps      | `ca-certificates`, `bash`, `python3`, `gosu`                   |
| Default user      | `app` (non-root)                                               |
| Family identifier | `ARK_IMAGE_FAMILY=gcloud-cli`                                  |

---

## Quick start

Run `gcloud --version`:

```bash
docker run --rm ghcr.io/tooark/gcloud-cli:latest gcloud --version
```

List current configuration information (without authenticating):

```bash
docker run --rm ghcr.io/tooark/gcloud-cli:latest gcloud info
```

Check the kubectl client version:

```bash
docker run --rm ghcr.io/tooark/gcloud-cli:latest kubectl version --client
```

### Authentication and credentials

In CI/CD environments, prefer service accounts. Two common approaches:

The `GOOGLE_APPLICATION_CREDENTIALS` variable pointing to a mounted JSON file:

```bash
docker run --rm \
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/app/key.json \
  -v "$HOME/tmp/sa.json:/home/app/key.json:ro" \
  ghcr.io/tooark/gcloud-cli:latest gcloud auth activate-service-account --key-file=/home/app/key.json
```

Setting project/region/zone via environment variables:

```bash
docker run --rm \
  -e CLOUDSDK_CORE_PROJECT=my-project \
  -e CLOUDSDK_COMPUTE_REGION=us-central1 \
  -e CLOUDSDK_COMPUTE_ZONE=us-central1-a \
  ghcr.io/tooark/gcloud-cli:latest gcloud config list
```

Use `kubectl get` with a mounted kubeconfig:

```bash
docker run --rm \
  -v "$HOME/.kube/config:/home/app/.kube/config:ro" \
  ghcr.io/tooark/gcloud-cli:latest kubectl get nodes --request-timeout=10s
```

To use `kubectl`, you can also mount a kubeconfig at `/home/app/.kube/config`.

---

## Environment variables

### GCLOUD CLI

| Variable                         | Default | Description                           |
| -------------------------------- | ------- | ------------------------------------- |
| `GOOGLE_APPLICATION_CREDENTIALS` | -       | Path to the service account JSON file |
| `CLOUDSDK_CORE_PROJECT`          | -       | Default GCP project                   |
| `CLOUDSDK_COMPUTE_REGION`        | -       | Default GCP region                    |
| `CLOUDSDK_COMPUTE_ZONE`          | -       | Default GCP zone                      |

---

## Pipelines

### GitHub Actions

#### Basic example (GH)

```yaml
name: Deploy GCP

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/gcloud-cli:latest
    steps:
      - uses: actions/checkout@v4

      - name: Authenticate with service account
        env:
          GCP_SA_KEY: ${{ secrets.GCP_SA_KEY }}
        run: |
          echo "$GCP_SA_KEY" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud config set project ${{ vars.GCP_PROJECT }}

      - name: Deploy to Cloud Storage
        run: gsutil -m rsync -r ./dist gs://${{ vars.GCS_BUCKET }}
```

#### Example with kubectl (GKE) (GH)

```yaml
name: Deploy GKE

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/gcloud-cli:latest
    steps:
      - uses: actions/checkout@v4

      - name: Authenticate and configure cluster
        env:
          GCP_SA_KEY: ${{ secrets.GCP_SA_KEY }}
        run: |
          echo "$GCP_SA_KEY" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud container clusters get-credentials ${{ vars.GKE_CLUSTER }} \
            --zone ${{ vars.GKE_ZONE }} \
            --project ${{ vars.GCP_PROJECT }}

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

deploy_gcs:
  stage: deploy
  image: ghcr.io/tooark/gcloud-cli:latest
  script:
    - echo "$GCP_SA_KEY" > /tmp/sa.json
    - gcloud auth activate-service-account --key-file=/tmp/sa.json
    - gcloud config set project $GCP_PROJECT
    - gsutil -m rsync -r ./dist gs://$GCS_BUCKET
  only:
    - main
```

#### Example with kubectl (GKE) (GL)

```yaml
stages:
  - deploy

deploy_gke:
  stage: deploy
  image: ghcr.io/tooark/gcloud-cli:latest
  script:
    - echo "$GCP_SA_KEY" > /tmp/sa.json
    - gcloud auth activate-service-account --key-file=/tmp/sa.json
    - gcloud container clusters get-credentials $GKE_CLUSTER --zone $GKE_ZONE --project $GCP_PROJECT
    - kubectl apply -f k8s/
    - kubectl rollout status deployment/$APP_NAME --timeout=120s
  only:
    - main
```

---

## Local build

When building locally, publish equivalent tags for the same image (full version, short version, and `latest`).

```bash
version="571.0.0"  # Google Cloud SDK
kubectl="1.36.1"   # kubectl
docker="29.5.2"    # Docker CLI
buildx="0.34.1"    # Buildx
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg GCLOUD_VERSION="$version" \
  --build-arg KUBECTL_VERSION="$kubectl" \
  --build-arg DOCKER_VERSION="$docker" \
  --build-arg DOCKER_BUILDX_VERSION="$buildx" \
  -t "gcloud-cli:$version" \
  -t "gcloud-cli:$short" \
  -t gcloud-cli:latest \
  ./gcloud-cli
```

---

## Official documentation

- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install)
  - [Release notes](https://cloud.google.com/sdk/docs/release-notes)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Release notes](https://kubernetes.io/releases/)
- [Docker CLI](https://docs.docker.com/reference/cli/docker/)
  - [Release notes](https://docs.docker.com/engine/release-notes/)
- [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/)
  - [Release notes](https://github.com/docker/buildx/releases/)

---

## License

MIT - see the `LICENSE` file at the repository root.
