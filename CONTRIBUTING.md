# Contributing to base-images

First off, thank you for considering contributing to **Tooark base-images**! 🎉

This repository centralizes the Docker base images used in CI/CD pipelines and
infrastructure automation (AWS CLI, Google Cloud SDK, OpenTofu/Terraform,
security scanners, and more). This document explains how to propose changes,
report bugs, and submit code.

## Table of contents

- [Ways to contribute](#ways-to-contribute)
- [Repository layout](#repository-layout)
- [Development workflow](#development-workflow)
- [Versioning](#versioning)
- [Commit convention](#commit-convention)
- [Documentation standards](#documentation-standards)
- [Releasing](#releasing)
- [Pull Request checklist](#pull-request-checklist)
- [Community](#community)

---

## Ways to contribute

- 🐛 **Report bugs** — open an issue with the `bug` template.
- ✨ **Suggest improvements or new images** — open an issue with the `feature`
  template.
- 📖 **Improve documentation** — the READMEs (English and Portuguese) are
  first-class.
- 🔒 **Review security** — question a `.trivyignore` exception, suggest
  hardening for a Dockerfile.
- 💻 **Write code** — Dockerfiles, entrypoints, automation scripts, samples.

---

## Repository layout

Each image lives in its own folder and follows the same structure:

| File           | Purpose                                              |
| -------------- | ---------------------------------------------------- |
| `Dockerfile`   | Image definition (reproducible build)                |
| `VERSION`      | Version variables that drive the image tag           |
| `DESCRIPTION`  | Short functional summary (used in release notes)     |
| `README.md`    | Usage docs in English                                |
| `README.pt-BR.md` | Usage docs in Portuguese                          |
| `.trivyignore` | Accepted CVE exceptions for the image security scan  |

Shared, repo-wide files:

- [versions.env](versions.env) — centralized tool and image versions
- [script/](script/) — automation (`fetch-latest-stable-versions.py`,
  `update-versions.py`, `build-and-run-local.sh`)
- [samples/](samples/) — ready-made pipeline examples (GitHub Actions,
  GitLab CI, local)
- [.github/workflows/](.github/workflows/) — build, scan, sign, and release
  automation

---

## Development workflow

**Prerequisites:** Docker with Buildx, Bash, and Python 3 (only for the
version-update scripts).

1. **Fork** the repository and clone your fork.
2. Create a feature branch: `git checkout -b feat/short-description`.
3. Make your changes (Dockerfile, scripts, docs…).
4. **Build and scan locally** before pushing:

   ```bash
   # Build a single image (loads versions from versions.env)
   ./script/build-and-run-local.sh build aws-cli

   # Build + security scan (Trivy, Hadolint, BetterLeaks)
   ./script/build-and-run-local.sh all aws-cli
   ```

5. If you touched a Dockerfile, make sure the scan passes with the existing
   `.trivyignore`. New CVE exceptions must be justified in the PR description.
6. Update the image's `README.md` **and** `README.pt-BR.md` if behavior,
   variables, or contents changed.
7. Push and open a Pull Request against `main`.

> Note: CI rebuilds and fully scans every changed image (Trivy + Hadolint +
> BetterLeaks) before anything is published. A failing scan blocks the merge.

---

## Versioning

- Tool versions are **centralized** in [versions.env](versions.env) — never
  hardcode a new version only in a Dockerfile.
- Each image's `VERSION` file lists the variables that compose that image; the
  **first variable** defines the image tag.
- `script/update-versions.py` updates `versions.env` and **resets the
  `.trivyignore`** of every impacted image — exceptions are then re-added
  manually, one by one, after reviewing the new scan results.

---

## Commit convention

We use [**Conventional Commits**](https://www.conventionalcommits.org/).

Format:

```text
<type>(<scope>): <short summary>
```

Common types: `feat`, `fix`, `docs`, `refactor`, `build`, `ci`, `chore`.

Use the image or area as the scope when it applies:

```text
feat(security-scanner): add SARIF output to ark-tools
fix(gcloud-cli): correct kubectl checksum verification
chore(versions): bump AWS CLI and Google Cloud SDK
chore(trivy): add exception for CVE-2026-XXXX in aws-cli
```

---

## Documentation standards

- Every image ships a **bilingual README**: `README.md` in English and
  `README.pt-BR.md` in Portuguese, with the language selector at the top.
  **Keep both in sync** — a change in one requires the same change in the
  other.
- The `## Image contents` / `## Conteúdo da imagem` section is extracted
  automatically into the GitHub Release notes — keep its structure intact.

---

## Releasing

Releases are **per image** and fully automated by
[`.github/workflows/image-build.yml`](.github/workflows/image-build.yml):

1. Bump the relevant variable(s) in `versions.env` (or the image's `VERSION`
   file for composite images).
2. Merge to `main`. For each image whose computed tag does not exist yet, the
   workflow builds (amd64 + arm64), runs the full security scan, pushes to
   `ghcr.io/tooark/<image>`, signs the image with Cosign (keyless), creates the
   git tag `<image>-<version>`, and publishes a GitHub Release.

Do **not** hand-create tags or releases — the workflow derives them from the
version files.

---

## Pull Request checklist

Before opening a PR, confirm:

- [ ] Commits follow Conventional Commits
- [ ] The image builds locally (`./script/build-and-run-local.sh build <image>`)
- [ ] The local security scan passes (`./script/build-and-run-local.sh all <image>`)
- [ ] New `.trivyignore` entries are justified in the PR description
- [ ] Versions changed only through `versions.env` / `VERSION` files
- [ ] `README.md` and `README.pt-BR.md` are updated **and in sync**
- [ ] Linked to at least one issue (`Closes #123`) when applicable

---

## Community

- 🐛 [Issues](https://github.com/Tooark/base-images/issues)
- 🌐 [Tooark](https://tooark.com)

Thank you for making Tooark base-images better! 💙
