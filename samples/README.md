# samples

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/samples/README.pt-BR.md)

Usage examples for the images in three scenarios:

- local usage
- GitHub Actions
- GitLab CI

## Covered images

- ghcr.io/tooark/dockerx:latest
- ghcr.io/tooark/aws-cli:latest
- ghcr.io/tooark/gcloud-cli:latest
- ghcr.io/tooark/terraform:latest
- ghcr.io/tooark/terraform-aws:latest
- ghcr.io/tooark/terraform-gcloud:latest
- ghcr.io/tooark/terraform-aws-gcloud:latest
- ghcr.io/tooark/sonar-scanner:latest
- ghcr.io/tooark/trivy-hadolint:latest
- ghcr.io/tooark/security-scanner:latest

## Dedicated examples: security-scanner

Complete files for the `security-scanner` image:

- Full local usage: [security-scanner-local.sh](security-scanner-local.sh)
- Full GitHub Actions: [security-scanner-github-actions.yml](security-scanner-github-actions.yml)
- Full GitLab CI: [security-scanner-gitlab-ci.yml](security-scanner-gitlab-ci.yml)

These examples cover:

- All the main commands (`image-scan`, `filesystem-scan`, `config-scan`, `repo-scan`, `dockerfile-lint`, `secret-scan`, `full-scan`)
- Metadata flags (`--branch`, `--commit`, `--user`, `--repository|--repo`, `--tag`)
- Specific parameters (`--sbom`, `--sbom-format`, `--no-git`, `--baseline`, `--path`, `--dockerfiles`, `--scan-mode`, `--skip-*`)
- Environment variables for Trivy, Hadolint, Betterleaks, SBOM, Full-scan, and Webhook

## 1) Local usage (docker run)

### docker (dockerx)

```bash
docker run --rm ghcr.io/tooark/dockerx:latest docker --version
docker run --rm ghcr.io/tooark/dockerx:latest docker buildx version
```

### aws-cli

```bash
docker run --rm ghcr.io/tooark/aws-cli:latest aws --version
docker run --rm ghcr.io/tooark/aws-cli:latest kubectl version --client
docker run --rm ghcr.io/tooark/aws-cli:latest docker --version
docker run --rm ghcr.io/tooark/aws-cli:latest docker buildx version
```

### gcloud-cli

```bash
docker run --rm ghcr.io/tooark/gcloud-cli:latest gcloud --version
docker run --rm ghcr.io/tooark/gcloud-cli:latest kubectl version --client
docker run --rm ghcr.io/tooark/gcloud-cli:latest docker --version
docker run --rm ghcr.io/tooark/gcloud-cli:latest docker buildx version
```

### terraform

```bash
docker run --rm ghcr.io/tooark/terraform:latest terraform version
```

### terraform-aws

```bash
docker run --rm ghcr.io/tooark/terraform-aws:latest terraform version
docker run --rm ghcr.io/tooark/terraform-aws:latest aws --version
docker run --rm ghcr.io/tooark/terraform-aws:latest kubectl version --client
```

### terraform-gcloud

```bash
docker run --rm ghcr.io/tooark/terraform-gcloud:latest terraform version
docker run --rm ghcr.io/tooark/terraform-gcloud:latest gcloud --version
docker run --rm ghcr.io/tooark/terraform-gcloud:latest kubectl version --client
```

### terraform-aws-gcloud

```bash
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest terraform version
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest aws --version
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest gcloud --version
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest kubectl version --client
```

### sonar-scanner

```bash
docker run --rm ghcr.io/tooark/sonar-scanner:latest sonar-scanner --version
docker run --rm ghcr.io/tooark/sonar-scanner:latest java -version
```

### trivy-hadolint

```bash
docker run --rm ghcr.io/tooark/trivy-hadolint:latest version
docker run --rm \
  -v "$PWD/scan-reports":/reports \
  -e TRIVY_SEVERITY=HIGH,CRITICAL \
  -e TRIVY_SEVERITY_FAIL=HIGH,CRITICAL \
  ghcr.io/tooark/trivy-hadolint:latest \
  image-scan nginx:latest
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/scan-reports":/reports \
  ghcr.io/tooark/trivy-hadolint:latest \
  container nginx:latest \
    --path /workspace \
    --branch "$(git rev-parse --abbrev-ref HEAD)" \
    --commit "$(git rev-parse HEAD)" \
    --repository "tooark/base-images"
```

## 2) GitHub Actions

Complete example file for the 9 images:

- [github-actions-images.yml](github-actions-images.yml)

How to use:

1. Copy the file to .github/workflows/base-images-sample.yml
2. Adjust secrets and variables if you run authenticated commands (AWS/GCP)
3. Run it via push or workflow_dispatch

## 3) GitLab CI

Complete example file for the 9 images:

- [gitlab-ci-images.yml](gitlab-ci-images.yml)

How to use:

1. Copy the content into .gitlab-ci.yml (or include it as a template)
2. Adjust protected variables for AWS/GCP credentials
3. Run the pipeline

## Notes

- The examples use latest for simplicity. In production, prefer pinned tags.
- For authenticated commands, inject credentials via CI variables.
- The trivy-hadolint examples now show how to set severity/gate, persist reports, and pass metadata when the command runs via docker run.
- The trivy-hadolint example may download the vulnerability database on the first run.
