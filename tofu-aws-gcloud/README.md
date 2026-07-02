# tofu-aws-gcloud

Base image with `tofu` (OpenTofu CLI), `aws` (AWS CLI v2), `gcloud`, `gsutil`, `bq`, and `kubectl`, ready to use in pipelines and ad-hoc container runs.

> This is the direct replacement for `terraform-aws-gcloud`. The `terraform-aws-gcloud` family is now legacy and should be avoided in new workflows.

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/tofu-aws-gcloud/README.pt-BR.md)

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

- **OpenTofu** with **AWS CLI**, **Google Cloud SDK**, and **kubectl** in the same image
- Minimal Debian base with a non-root user
- Compatible with linux/amd64 and linux/arm64

---

## Image tags

| Tag                                                  | Description   |
| ---------------------------------------------------- | ------------- |
| `ghcr.io/tooark/tofu-aws-gcloud:<MAJOR.MINOR.PATCH>` | Full version  |
| `ghcr.io/tooark/tofu-aws-gcloud:<MAJOR.MINOR>`       | Short version |
| `ghcr.io/tooark/tofu-aws-gcloud:<MAJOR>`             | Major track   |
| `ghcr.io/tooark/tofu-aws-gcloud:latest`              | Latest stable |

---

## Image contents

| Item              | Description                                                     |
| ----------------- | --------------------------------------------------------------- |
| Base              | `debian:13-slim`                                                |
| OpenTofu CLI      | `/usr/local/bin/tofu`                                           |
| AWS CLI v2        | `/usr/local/aws-cli/v2/current/bin/aws`                         |
| Google Cloud SDK  | `/opt/google-cloud-sdk`                                         |
| kubectl           | `/usr/local/bin/kubectl`                                        |
| Symlink           | `/usr/local/bin/aws` -> `/usr/local/aws-cli/v2/current/bin/aws` |
| Symlink           | `gcloud`, `gsutil`, `bq` -> `/opt/google-cloud-sdk/bin/gcloud`  |
| Runtime deps      | `ca-certificates`, `bash`, `python3`, `gosu`                    |
| Default user      | `app` (non-root)                                                |
| Family identifier | `ARK_IMAGE_FAMILY=tofu-aws-gcloud`                              |

---

## Quick start

Check the installed versions:

```bash
docker run --rm ghcr.io/tooark/tofu-aws-gcloud:latest tofu version
docker run --rm ghcr.io/tooark/tofu-aws-gcloud:latest aws --version
docker run --rm ghcr.io/tooark/tofu-aws-gcloud:latest gcloud --version
docker run --rm ghcr.io/tooark/tofu-aws-gcloud:latest kubectl version --client
```

Initialize an OpenTofu directory (mount your code):

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu-aws-gcloud:latest tofu init
```

Run a plan:

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu-aws-gcloud:latest tofu plan
```

List GCP projects (requires prior authentication):

```bash
docker run --rm \
  -v ${HOME}/.config/gcloud:/home/app/.config/gcloud:ro \
  ghcr.io/tooark/tofu-aws-gcloud:latest gcloud projects list --format="table(projectId,name)"
```

Use kubectl with a mounted kubeconfig:

```bash
docker run --rm \
  -v ${HOME}/.kube/config:/home/app/.kube/config:ro \
  ghcr.io/tooark/tofu-aws-gcloud:latest kubectl get nodes --request-timeout=10s
```

### Passing credentials to the container

Via environment variables:

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  -e AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
  -e AWS_REGION=us-east-1 \
  ghcr.io/tooark/tofu-aws-gcloud:latest aws sts get-caller-identity --no-cli-pager
```

In CI/CD environments, prefer service accounts. Two common approaches:

The `GOOGLE_APPLICATION_CREDENTIALS` variable pointing to a mounted JSON file:

```bash
docker run --rm \
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/app/key.json \
  -v "$HOME/tmp/sa.json:/home/app/key.json:ro" \
  ghcr.io/tooark/tofu-aws-gcloud:latest gcloud auth activate-service-account --key-file=/home/app/key.json
```

Setting project/region/zone via environment variables:

```bash
docker run --rm \
  -e CLOUDSDK_CORE_PROJECT=my-project \
  -e CLOUDSDK_COMPUTE_REGION=us-central1 \
  -e CLOUDSDK_COMPUTE_ZONE=us-central1-a \
  ghcr.io/tooark/tofu-aws-gcloud:latest gcloud config list
```

---

## Environment variables

### AWS CLI

| Variable                | Default     | Description        |
| ----------------------- | ----------- | ------------------ |
| `AWS_ACCESS_KEY_ID`     | -           | AWS access key     |
| `AWS_SECRET_ACCESS_KEY` | -           | AWS secret key     |
| `AWS_SESSION_TOKEN`     | -           | AWS session token  |
| `AWS_REGION`            | `us-east-1` | Default AWS region |

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
name: Tofu MultiCloud

on:
  push:
    branches: [main]
  pull_request:

jobs:
  tofu:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu-aws-gcloud:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Auth GCP
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

### Example with EKS and GKE deployment (GH)

```yaml
name: Deploy MultiCluster

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu-aws-gcloud:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Auth GCP
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

      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER }}
          kubectl apply -f k8s/

      - name: Deploy to GKE
        run: |
          gcloud container clusters get-credentials ${{ vars.GKE_CLUSTER }} --zone ${{ vars.GKE_ZONE }}
          kubectl apply -f k8s/
```

---

## Local build

```bash
version="1.0.0"   # tofu-aws-gcloud
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg TOFU_AWS_GCLOUD_VERSION=$version \
  --build-arg OPENTOFU_VERSION=1.12.1 \
  --build-arg AWSCLI_VERSION=2.34.60 \
  --build-arg GCLOUD_VERSION=571.0.0 \
  --build-arg KUBECTL_VERSION=1.36.1 \
  -t tofu-aws-gcloud:$version \
  -t tofu-aws-gcloud:$short \
  -t tofu-aws-gcloud:latest \
  ./tofu-aws-gcloud
```

---

## Official documentation

- [OpenTofu](https://opentofu.org/docs/)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)

---

## License

MIT - see the [LICENSE](../LICENSE) file at the repository root.

<!-- markdownlint-enable MD060 -->
