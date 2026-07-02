# sonar-scanner

Base image with `sonar-scanner` (SonarQube Scanner CLI), ready to use in CI/CD pipelines with SonarQube, aimed at languages such as Go, PHP, and others that use the scanner CLI directly.

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/sonar-scanner/README.pt-BR.md)

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

- **Sonar Scanner CLI** ready to use in CI/CD
- Minimal Debian base with a non-root user
- Compatible with linux/amd64 and linux/arm64

---

## Image tags

| Tag                                                | Description   |
| -------------------------------------------------- | ------------- |
| `ghcr.io/tooark/sonar-scanner:<MAJOR.MINOR.PATCH>` | Full version  |
| `ghcr.io/tooark/sonar-scanner:<MAJOR.MINOR>`       | Short version |
| `ghcr.io/tooark/sonar-scanner:<MAJOR>`             | Major track   |
| `ghcr.io/tooark/sonar-scanner:latest`              | Latest stable |

---

## Image contents

| Item              | Description                                                |
| ----------------- | ---------------------------------------------------------- |
| Base              | `debian:13-slim`                                           |
| Sonar Scanner CLI | `/opt/sonar-scanner`                                       |
| Runtime deps      | `ca-certificates`, `bash`, `git`, `openjdk-21-jre`, `gosu` |
| Default user      | `app` (non-root)                                           |
| Family identifier | `ARK_IMAGE_FAMILY=sonar-scanner`                           |

---

## Quick start

Check the scanner version:

```bash
docker run --rm ghcr.io/tooark/sonar-scanner:latest sonar-scanner --version
```

Run a scan on a project (mounting the working directory):

```bash
docker run --rm \
  -e SONAR_HOST_URL="https://sonarqube.example.com" \
  -e SONAR_TOKEN="your-token" \
  -v $(pwd):/usr/src \
  -w /usr/src \
  ghcr.io/tooark/sonar-scanner:latest \
  sonar-scanner -Dsonar.projectKey="my-project"
```

---

## Environment variables

### SONAR SCANNER CLI

| Variable         | Default | Description                    |
| ---------------- | ------- | ------------------------------ |
| `SONAR_HOST_URL` | -       | SonarQube server URL           |
| `SONAR_TOKEN`    | -       | SonarQube authentication token |

---

## Pipelines

### GitHub Actions

#### Basic example (GH)

```yaml
name: SonarQube Scan

on:
  push:
    branches: [main]
  pull_request:

jobs:
  sonar:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/sonar-scanner:latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run SonarQube analysis
        env:
          SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        run: |
          sonar-scanner \
            -Dsonar.projectKey=${{ vars.SONAR_PROJECT_KEY }} \
            -Dsonar.projectName=${{ vars.SONAR_PROJECT_NAME }} \
            -Dsonar.sources=. \
            -Dsonar.qualitygate.wait=true
```

### GitLab CI

#### Basic example (GL)

```yaml
stages:
  - analysis

sonarqube_scan:
  stage: analysis
  image: ghcr.io/tooark/sonar-scanner:latest
  variables:
    GIT_DEPTH: "0"
  script:
    - sonar-scanner -Dsonar.projectKey="$SONAR_PROJECT_KEY" -Dsonar.projectName="$SONAR_PROJECT_NAME" -Dsonar.sources=. -Dsonar.qualitygate.wait=true
  rules:
    - if: '$CI_COMMIT_BRANCH == "main" || $CI_PIPELINE_SOURCE == "merge_request_event"'
```

Configure in GitLab (Settings > CI/CD > Variables):

- `SONAR_HOST_URL`
- `SONAR_TOKEN`
- `SONAR_PROJECT_KEY`
- `SONAR_PROJECT_NAME`

---

## Local build

When building locally, publish equivalent tags for the same image (full version, short version, and `latest`).

```bash
version="8.1.0.6389"  # Sonar Scanner CLI
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg SONAR_CLI_VERSION="$version" \
  -t "sonar-scanner:$version" \
  -t "sonar-scanner:$short" \
  -t sonar-scanner:latest \
  ./sonar-scanner
```

---

## Official documentation

- [SonarScanner CLI](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/scanners/sonarscanner)
  - [Release notes](https://github.com/SonarSource/sonar-scanner-cli/releases)

---

## License

MIT - see the `LICENSE` file at the repository root.
