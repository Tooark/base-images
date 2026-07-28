# base-images

Repository of base images for CI/CD and infrastructure automation.

Each subproject has its own Dockerfile, versioning, and documentation.

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/README.pt-BR.md)

---

## Table of contents

- [Overview](#overview)
- [Image documentation](#image-documentation)
- [Ready-made examples](#ready-made-examples)
- [Repository structure](#repository-structure)
- [Versioning and automation](#versioning-and-automation)
- [Recommended workflow](#recommended-workflow)
- [Community](#community)
- [License](#license)

---

## Overview

This repository centralizes Docker images used in pipelines and infrastructure automation.

Each image keeps:

- a Dockerfile with a reproducible build
- a VERSION file for release control
- a DESCRIPTION with a functional summary
- a README with the image contents, quick start, pipeline examples, and local build

All images share the same base (`debian:13-slim`), run as the non-root user (`app`), and use the same `docker-entrypoint.sh`, which adjusts the `docker.sock` GID and drops privileges via `gosu` at runtime.

---

## Image documentation

| Subproject             | What it contains                                                            | Documentation                                                    |
| ---------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `aws-cli`              | AWS CLI v2 + kubectl + Docker CLI + Buildx                                  | [aws-cli/README.md](aws-cli/README.md)                           |
| `dockerx`              | Docker CLI + Buildx plugin for multi-architecture builds                    | [dockerx/README.md](dockerx/README.md)                           |
| `gcloud-cli`           | Google Cloud SDK (`gcloud`, `gsutil`, `bq`) + kubectl + Docker CLI + Buildx | [gcloud-cli/README.md](gcloud-cli/README.md)                     |
| `tofu`                 | OpenTofu CLI                                                                | [tofu/README.md](tofu/README.md)                                 |
| `tofu-aws`             | OpenTofu + AWS CLI v2 + kubectl                                             | [tofu-aws/README.md](tofu-aws/README.md)                         |
| `tofu-gcloud`          | OpenTofu + Google Cloud SDK + kubectl                                       | [tofu-gcloud/README.md](tofu-gcloud/README.md)                   |
| `tofu-aws-gcloud`      | OpenTofu + AWS CLI v2 + Google Cloud SDK + kubectl                          | [tofu-aws-gcloud/README.md](tofu-aws-gcloud/README.md)           |
| `security-scanner`     | Trivy + Hadolint + BetterLeaks + `ark-tools` wrapper for scans and reports  | [security-scanner/README.md](security-scanner/README.md)         |
| `sonar-scanner`        | Sonar Scanner CLI for analysis in CI/CD pipelines                           | [sonar-scanner/README.md](sonar-scanner/README.md)               |
| `terraform`            | Terraform CLI (deprecated)                                                  | [terraform/README.md](terraform/README.md)                       |
| `terraform-aws`        | Terraform + AWS CLI v2 + kubectl (deprecated)                               | [terraform-aws/README.md](terraform-aws/README.md)               |
| `terraform-gcloud`     | Terraform + Google Cloud SDK + kubectl (deprecated)                         | [terraform-gcloud/README.md](terraform-gcloud/README.md)         |
| `terraform-aws-gcloud` | Terraform + AWS CLI v2 + Google Cloud SDK + kubectl (deprecated)            | [terraform-aws-gcloud/README.md](terraform-aws-gcloud/README.md) |
| `trivy-hadolint`       | Trivy + Hadolint + `ark-tools` wrapper for scans and reports                | [trivy-hadolint/README.md](trivy-hadolint/README.md)             |

---

## Ready-made examples

Use these files as a starting point for local validation and pipelines:

- Guide with local examples and usage instructions: [samples/README.md](samples/README.md)
- Build/publish pipeline for GitHub Actions: [samples/github-actions-images.yml](samples/github-actions-images.yml)
- Build/publish pipeline for GitLab CI: [samples/gitlab-ci-images.yml](samples/gitlab-ci-images.yml)

Dedicated examples for security-scanner:

- Full local run: [samples/security-scanner-local.sh](samples/security-scanner-local.sh)
- Full GitHub Actions pipeline: [samples/security-scanner-github-actions.yml](samples/security-scanner-github-actions.yml)
- Full GitLab CI pipeline: [samples/security-scanner-gitlab-ci.yml](samples/security-scanner-gitlab-ci.yml)

---

## Repository structure

- Each subproject folder contains:
  - `Dockerfile`: image definition
  - `VERSION`: subproject version
  - `DESCRIPTION`: short image summary
  - `README.md`: usage, variables, and examples (English)
  - `README.pt-BR.md`: the same documentation in Portuguese (kept in sync)
  - `.trivyignore`: accepted CVE exceptions for the image security scan

---

## Versioning and automation

The [versions.env](versions.env) file centralizes the versions of all tools and images.

The `script/` folder contains the automation scripts:

| Script                            | Purpose                                                     |
| --------------------------------- | ----------------------------------------------------------- |
| `fetch-latest-stable-versions.py` | Fetches the latest stable versions of each tool             |
| `update-versions.py`              | Updates `versions.env` and manages the `.trivyignore` files |

### Automation workflows

Two GitHub Actions workflows drive the release cycle:

| Workflow                                                               | Purpose                                                                                                                                                                     |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [update-tool-versions.yml](.github/workflows/update-tool-versions.yml) | Runs weekly: fetches the latest stable tool versions, updates `versions.env`, resets the impacted `.trivyignore` files, and triggers the image build                        |
| [image-build.yml](.github/workflows/image-build.yml)                   | Builds each new image (amd64 + arm64), runs the full security scan, pushes to `ghcr.io/tooark`, signs with **Cosign (keyless)**, and creates the git tag and GitHub Release |

All published images are signed with [Cosign](https://docs.sigstore.dev/cosign/verifying/verify/) via GitHub Actions OIDC — consumers can verify the signature before use.

### Automatic .trivyignore management

When the `update-versions.py` script detects a new tool version, it:

1. **Clears and reinitializes** the `.trivyignore` of **all images impacted** by the changed version.
2. **Does not rebuild or automatically inherit** exceptions across images.
3. Recreates the file with a standard header and an automatic review date, so the maintainer can manually add only the CVEs accepted for that version.

> Example: if `GCLOUD_VERSION` changes, the script clears and recreates the `.trivyignore` of `gcloud-cli/`, `tofu-gcloud/`, `terraform-gcloud/`, and `terraform-aws-gcloud/`. None of these files receive CVEs automatically.

---

## Recommended workflow

1. Choose the image from the catalog in [Image documentation](#image-documentation).
2. Follow the quick start and the variables in the chosen image's README.
3. Use the examples in [samples/README.md](samples/README.md) and the dedicated security-scanner files for initial integration.
4. For releases and version updates, use the scripts in the [script/](script/) folder.

---

## Community

- 🤝 [Contributing guide](CONTRIBUTING.md) — how to propose changes, build and scan locally
- 📜 [Code of Conduct](CODE_OF_CONDUCT.md)
- 🔒 [Security policy](SECURITY.md) — **report vulnerabilities privately**, never via public issues
- 🙋 [Support](SUPPORT.md) — where to ask questions and get help

---

## License

MIT - see the [LICENSE](LICENSE) file at the repository root.
