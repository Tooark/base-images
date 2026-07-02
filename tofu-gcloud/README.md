# tofu-gcloud

Base image with `tofu` (OpenTofu CLI), `gcloud`, `gsutil`, `bq`, and `kubectl`, ready to use in pipelines and ad-hoc container runs.

> This is the direct replacement for `terraform-gcloud`. The `terraform-gcloud` family is now legacy and should be avoided in new workflows.

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/tofu-gcloud/README.pt-BR.md)

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

- **OpenTofu**, **Google Cloud SDK**, and **kubectl** in the same image
- Minimal Debian base with a non-root user
- Compatible with linux/amd64 and linux/arm64

---

## Image tags

| Tag                                              | Description   |
| ------------------------------------------------ | ------------- |
| `ghcr.io/tooark/tofu-gcloud:<MAJOR.MINOR.PATCH>` | Full version  |
| `ghcr.io/tooark/tofu-gcloud:<MAJOR.MINOR>`       | Short version |
| `ghcr.io/tooark/tofu-gcloud:<MAJOR>`             | Major track   |
| `ghcr.io/tooark/tofu-gcloud:latest`              | Latest stable |

---

## Image contents

| Item              | Description                                                    |
| ----------------- | -------------------------------------------------------------- |
| Base              | `debian:13-slim`                                               |
| OpenTofu CLI      | `/usr/local/bin/tofu`                                          |
| Google Cloud SDK  | `/opt/google-cloud-sdk`                                        |
| kubectl           | `/usr/local/bin/kubectl`                                       |
| Symlink           | `gcloud`, `gsutil`, `bq` -> `/opt/google-cloud-sdk/bin/gcloud` |
| Runtime deps      | `ca-certificates`, `bash`, `python3`, `gosu`                   |
| Default user      | `app` (non-root)                                               |
| Family identifier | `ARK_IMAGE_FAMILY=tofu-gcloud`                                 |

---

## Quick start

Check the installed versions:

```bash
docker run --rm ghcr.io/tooark/tofu-gcloud:latest tofu version
docker run --rm ghcr.io/tooark/tofu-gcloud:latest gcloud --version
docker run --rm ghcr.io/tooark/tofu-gcloud:latest kubectl version --client
```

Initialize an OpenTofu directory (mount your code):

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu-gcloud:latest tofu init
```

Run an OpenTofu plan:

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu-gcloud:latest tofu plan
```

List GCP projects (requires prior authentication):

```bash
docker run --rm \
  -v ${HOME}/.config/gcloud:/home/app/.config/gcloud:ro \
  ghcr.io/tooark/tofu-gcloud:latest gcloud projects list --format="table(projectId,name)"
```

Use kubectl with a mounted kubeconfig:

```bash
docker run --rm \
  -v ${HOME}/.kube/config:/home/app/.kube/config:ro \
  ghcr.io/tooark/tofu-gcloud:latest kubectl get nodes --request-timeout=10s
```

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
name: Tofu GCP

on:
  push:
    branches: [main]
  pull_request:

jobs:
  tofu:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu-gcloud:latest
    env:
      GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to GCP
        run: |
          echo "$GOOGLE_CREDENTIALS" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud config set project ${{ vars.GCP_PROJECT }}

      - name: Tofu Init
        run: tofu init

      - name: Tofu Plan
        run: tofu plan -out=tfplan

      - name: Tofu Apply
        if: github.ref == 'refs/heads/main'
        run: tofu apply tfplan
```

#### Example with GKE deployment (GH)

```yaml
name: Deploy to GKE

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu-gcloud:latest
    env:
      GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Auth + OpenTofu
        run: |
          echo "$GOOGLE_CREDENTIALS" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud config set project ${{ vars.GCP_PROJECT }}
          tofu init
          tofu apply -auto-approve

      - name: Configure kubectl and deploy
        run: |
          gcloud container clusters get-credentials ${{ vars.GKE_CLUSTER }} --zone ${{ vars.GKE_ZONE }}
          kubectl apply -f k8s/
```

---

## Local build

```bash
version="1.0.0"   # tofu-gcloud
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg TOFU_GCLOUD_VERSION=$version \
  --build-arg OPENTOFU_VERSION=1.12.1 \
  --build-arg GCLOUD_VERSION=571.0.0 \
  --build-arg KUBECTL_VERSION=1.36.1 \
  -t tofu-gcloud:$version \
  -t tofu-gcloud:$short \
  -t tofu-gcloud:latest \
  ./tofu-gcloud
```

---

## Official documentation

- [OpenTofu](https://opentofu.org/docs/)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)

---

## License

MIT - see the [LICENSE](../LICENSE) file at the repository root.

<!-- markdownlint-enable MD060 -->
