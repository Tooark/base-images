# trivy-hadolint

Base image with **Trivy** and **Hadolint** integrated, focused on standardizing
security scans in CI/CD pipelines.

The image exposes a CLI wrapper called **`ark-tools`** that covers the main
analysis scenarios (image, filesystem, IaC, repository, and Dockerfile) and
consolidates the results into a standardized JSON envelope: the
[**ark-report-tools**](#json-schema-ark-report-tools).

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/trivy-hadolint/README.pt-BR.md)

---

## Table of contents

- [Features](#features)
- [Image tags](#image-tags)
- [Image contents](#image-contents)
- [Quick start](#quick-start)
- [Available commands](#available-commands)
- [Aliases](#aliases)
- [Environment variables](#environment-variables)
- [SCM / CI metadata (auto-detect)](#scm--ci-metadata-auto-detect)
- [Metadata flags](#metadata-flags-cli)
- [`.trivyignore`](#trivyignore)
- [SBOM generation](#sbom-generation)
- [Failure gate](#failure-gate)
- [Report delivery webhook](#report-delivery-webhook)
- [Recommended mounts](#recommended-mounts)
- [Practical examples](#practical-examples)
- [Pipelines](#pipelines)
- [JSON Schema (ark-report-tools)](#json-schema-ark-report-tools)
- [Report validation](#report-validation)
- [Wrapper tests](#wrapper-tests)
- [Local build](#local-build)
- [Common pitfalls](#common-pitfalls)
- [License](#license)

---

## Features

- Scanning of **image**, **filesystem**, **IaC (config)**, **repository**, and
  **Dockerfile** linting in a single CLI (`ark-tools`)
- Reports in **JSON, SARIF, TABLE, CycloneDX, SPDX-JSON**
- **SBOM** generation (CycloneDX/SPDX) on demand
- Inclusion of a **full package inventory** (`--list-all-pkgs`, optional)
- Optional integration with **Trivy Server** + local fallback
- Auto-resolution of **`.trivyignore`** (env, `/.trivyignore`, `$PWD/.trivyignore`)
- **Auto-detection** of CI variables (GitLab, GitHub, Azure, Bitbucket, Jenkins)
- **Standardized envelope** (`ark-report-tools v1.1`) with SCM/CI metadata
- Report delivery via **webhook** (1+ URLs)
- **Failure gate** by configurable severity
- `WORKDIR /workspace` by default to avoid accidentally scanning the container
- Automated **test suite** for the wrapper (`tests/run-tests.sh`)

---

## Image tags

| Tag                                                 | Description   |
| --------------------------------------------------- | ------------- |
| `ghcr.io/tooark/trivy-hadolint:<MAJOR.MINOR.PATCH>` | Full version  |
| `ghcr.io/tooark/trivy-hadolint:<MAJOR.MINOR>`       | Short version |
| `ghcr.io/tooark/trivy-hadolint:<MAJOR>`             | Major track   |
| `ghcr.io/tooark/trivy-hadolint:latest`              | Latest stable |

---

## Image contents

| Item                | Description                                                    |
| ------------------- | -------------------------------------------------------------- |
| Base                | `debian:13-slim` (configurable via `BASE_IMAGE`)               |
| Trivy               | `/usr/local/bin/trivy`                                         |
| Hadolint            | `/usr/local/bin/hadolint`                                      |
| CLI wrapper         | `/usr/local/bin/ark-tools` (entrypoint)                        |
| JSON Schema         | `/usr/local/share/ark-tools/ark-report-tools.schema.v1.1.json` |
| Registered versions | `/etc/ark-tools-versions`                                      |
| Runtime deps        | `bash`, `curl`, `jq`, `git`, `ca-certificates`, `gosu`         |
| Default user        | `app` (non-root)                                               |
| `WORKDIR`           | `/workspace`                                                   |
| Trivy cache         | `TRIVY_CACHE_DIR=/home/app/.cache/trivy`                       |
| Reports directory   | `REPORT_DIR=/reports`                                          |

---

## Quick start

```bash
# Help
docker run --rm ghcr.io/tooark/trivy-hadolint:latest help

# Versions
docker run --rm ghcr.io/tooark/trivy-hadolint:latest version

# Scan a registry image
docker run --rm ghcr.io/tooark/trivy-hadolint:latest image-scan nginx:latest

# Filesystem scan (repo mounted at /workspace)
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/scan-reports":/reports \
  ghcr.io/tooark/trivy-hadolint:latest \
  filesystem-scan
```

---

## Available commands

```text
help                                                                       # General help
version                                                                    # Versions
image-scan [--sbom[=fmt]|--sbom-format <fmt>] <image> [-- <extras>]        # Image scan
filesystem-scan [--sbom[=fmt]|--sbom-format <fmt>] [path] [-- <extras>]    # Filesystem scan
config-scan [path] [-- <extras>]                                           # IaC scan
repo-scan [path|url] [-- <extras>]                                         # Repository scan
dockerfile-lint [Dockerfile] [-- <extras>]                                 # Dockerfile lint
container [options] <image> [-- <extras>]                                  # Combined (image + source + lint)
send-report <file>                                                         # Manual webhook delivery
```

All scan commands also accept the
[metadata flags](#metadata-flags-cli) (`--branch`, `--commit`, etc.).

---

## Aliases

| Command           | Aliases           |
| ----------------- | ----------------- |
| `help`            | `-h`, `--help`    |
| `version`         | `-v`, `--version` |
| `image-scan`      | `img-scan`, `is`  |
| `filesystem-scan` | `fs-scan`, `fs`   |
| `config-scan`     | `cfg-scan`, `cs`  |
| `repo-scan`       | `rp-scan`, `rs`   |
| `dockerfile-lint` | `hadolint`, `dl`  |
| `container`       | `ctr`             |
| `send-report`     | `send`            |

---

## Environment variables

### Trivy (general)

| Variable               | Default                            | Description                                                                                              |
| ---------------------- | ---------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `TRIVY_SEVERITY`       | `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL` | Severities **included in the report**                                                                    |
| `TRIVY_SEVERITY_FAIL`  | `HIGH,CRITICAL`                    | Severities that **trigger the failure gate**                                                             |
| `TRIVY_EXIT_CODE`      | `1`                                | `0` disables the gate; `1` fails the pipeline when issues are found                                      |
| `TRIVY_IGNORE_UNFIXED` | `true`                             | Ignore vulnerabilities without a fix                                                                     |
| `TRIVY_FORMAT`         | `json`                             | `json`, `sarif`, `table`, `cyclonedx`, `spdx-json`                                                       |
| `TRIVY_OUTPUT`         | per command                        | Output path (for single commands)                                                                        |
| `TRIVY_TIMEOUT`        | `10m`                              | Scan timeout                                                                                             |
| `TRIVY_SCANNERS`       | Trivy default                      | E.g., `vuln,secret,misconfig,license`                                                                    |
| `TRIVY_ALL_PACKAGES`   | `true`                             | Includes full inventory (`--list-all-pkgs`). Auto-disabled if `TRIVY_FORMAT != json` or on `config-scan` |
| `TRIVY_IGNOREFILE`     | auto-detect                        | Explicit `.trivyignore` path                                                                             |

### Trivy Server (optional)

| Variable                | Default | Description                                                  |
| ----------------------- | ------- | ------------------------------------------------------------ |
| `TRIVY_SERVER`          | empty   | Trivy Server endpoint (e.g., `http://trivy-server:4954`)     |
| `TRIVY_TOKEN`           | empty   | Authentication token (read natively by Trivy)                |
| `TRIVY_SERVER_REQUIRED` | `false` | If `true`, does not try local fallback when the server fails |
| `TRIVY_TOKEN_AS_FLAG`   | `false` | If `true`, sends the token via the `--token` flag            |

### SBOM

| Variable      | Default     | Description                            |
| ------------- | ----------- | -------------------------------------- |
| `SBOM_FORMAT` | `cyclonedx` | SBOM format (`cyclonedx`, `spdx-json`) |
| `SBOM_OUTPUT` | per command | Output file in SBOM mode               |

### Hadolint

| Variable                 | Default     | Description                                |
| ------------------------ | ----------- | ------------------------------------------ |
| `HADOLINT_CONFIG`        | empty       | Path to `.hadolint.yaml`                   |
| `HADOLINT_FORMAT`        | `json`      | Output format: `json`, `tty`, `sarif`      |
| `HADOLINT_FAILURE_LEVEL` | empty       | Minimum level to fail (`warning`, `error`) |
| `HADOLINT_OUTPUT`        | per command | Lint output file                           |

### Container (`container` command)

| Variable                | Default               | Description             |
| ----------------------- | --------------------- | ----------------------- |
| `CONTAINER_PATH`        | auto-detect or `$PWD` | Project directory       |
| `CONTAINER_DOCKERFILES` | `Dockerfile`          | Comma-separated list    |
| `CONTAINER_SCAN_MODE`   | `fs`                  | Options: `fs` or `repo` |
| `CONTAINER_SKIP_IMAGE`  | `false`               | Skip image scan         |
| `CONTAINER_SKIP_LINT`   | `false`               | Skip Dockerfile lint    |

### Webhook (report delivery)

| Variable                | Default    | Description                                |
| ----------------------- | ---------- | ------------------------------------------ |
| `REPORT_URL`            | empty      | Comma-separated URLs                       |
| `REPORT_TOKEN`          | empty      | Bearer token                               |
| `REPORT_HEADERS`        | empty      | Extra headers, one per line (`Key: Value`) |
| `REPORT_METHOD`         | `POST`     | HTTP method                                |
| `REPORT_FAIL_ON_ERROR`  | `false`    | Fails the pipeline if any upload fails     |
| `REPORT_SEND_EACH_SCAN` | `false`    | Sends after each individual scan           |
| `REPORT_DIR`            | `/reports` | Reports directory                          |

### Webhook SBOM (override for a separate endpoint)

| Variable                    | Fallback               |
| --------------------------- | ---------------------- |
| `REPORT_SBOM_URL`           | `REPORT_URL`           |
| `REPORT_SBOM_TOKEN`         | `REPORT_TOKEN`         |
| `REPORT_SBOM_HEADERS`       | `REPORT_HEADERS`       |
| `REPORT_SBOM_METHOD`        | `REPORT_METHOD`        |
| `REPORT_SBOM_FAIL_ON_ERROR` | `REPORT_FAIL_ON_ERROR` |

---

## SCM / CI metadata (auto-detect)

Starting with the `ark-report-tools v1.1` envelope, every report includes a
`metadata` object with **SCM** (version control) and **CI** (pipeline)
information, useful for traceability across builds, security dashboards,
and regression analysis.

### Structure

```json
{
  "metadata": {
    "scm": {
      "branch": "main",
      "commit": "abc123def456...",
      "commit_short": "abc123d",
      "repository": "Tooark/myapp",
      "tag": "v1.2.3"
    },
    "ci": {
      "platform": "github",
      "user": "paulo.junior",
      "pipeline_id": "12345",
      "job_id": "build",
      "url": "https://github.com/.../actions/runs/12345"
    }
  }
}
```

Fields that are not detected remain `null`.

### Detected platforms

`ark-tools` automatically identifies the environment from sentinel
variables:

| Platform            | Detecting variable       |
| ------------------- | ------------------------ |
| GitLab CI           | `GITLAB_CI`              |
| GitHub Actions      | `GITHUB_ACTIONS`         |
| Azure DevOps        | `TF_BUILD`               |
| Bitbucket Pipelines | `BITBUCKET_BUILD_NUMBER` |
| Jenkins             | `JENKINS_URL`            |

### Mapping per platform

| Field        | GitLab CI                      | GitHub Actions                      | Azure DevOps             | Bitbucket                       | Jenkins                    |
| ------------ | ------------------------------ | ----------------------------------- | ------------------------ | ------------------------------- | -------------------------- |
| **branch**   | `CI_COMMIT_REF_NAME`           | `GITHUB_REF_NAME`/`GITHUB_HEAD_REF` | `BUILD_SOURCEBRANCHNAME` | `BITBUCKET_BRANCH`              | `BRANCH_NAME`/`GIT_BRANCH` |
| **commit**   | `CI_COMMIT_SHA`                | `GITHUB_SHA`                        | `BUILD_SOURCEVERSION`    | `BITBUCKET_COMMIT`              | `GIT_COMMIT`               |
| **repo**     | `CI_PROJECT_PATH`              | `GITHUB_REPOSITORY`                 | `BUILD_REPOSITORY_NAME`  | `BITBUCKET_REPO_FULL_NAME`      | `JOB_NAME`                 |
| **tag**      | `CI_COMMIT_TAG`                | —                                   | —                        | `BITBUCKET_TAG`                 | —                          |
| **user**     | `GITLAB_USER_LOGIN`            | `GITHUB_ACTOR`                      | `BUILD_REQUESTEDFOR`     | `BITBUCKET_STEP_TRIGGERER_UUID` | `BUILD_USER_ID`            |
| **pipeline** | `CI_PIPELINE_ID`               | `GITHUB_RUN_ID`                     | `BUILD_BUILDID`          | `BITBUCKET_BUILD_NUMBER`        | `BUILD_NUMBER`             |
| **job**      | `CI_JOB_ID`                    | `GITHUB_JOB`                        | `SYSTEM_JOBID`           | `BITBUCKET_STEP_UUID`           | `JOB_NAME`                 |
| **url**      | `CI_PIPELINE_URL`/`CI_JOB_URL` | computed from `GITHUB_*`            | `BUILD_BUILDURI`         | —                               | `BUILD_URL`                |

> 💡 When `ark-tools` runs inside another container via `docker run`,
> the native variables need to be passed with `-e GITHUB_*`, `-e CI_*`, etc.,
> or via `--env-file`.

### Precedence (highest to lowest)

1. **CLI flag** (`--branch`, `--commit`, `--user`, `--repository`, `--tag`)
2. **Generic env** (`CI_BRANCH`, `CI_COMMIT`, `CI_USER`, `CI_REPOSITORY`, `CI_TAG`)
3. **Native CI env** (auto-detected as per the table above)
4. **Git** (best-effort, if `.git` is accessible)
5. Null field (`null`)

---

## Metadata flags (CLI)

Accepted on **all** scan commands:

```text
--branch <name>      SCM branch
--commit <sha>       SCM commit SHA
--user <name>        CI user / triggerer
--repository <name>  SCM repository (owner/repo)   (alias: --repo)
--tag <name>         SCM tag
```

Example:

```bash
docker run --rm -v "$PWD":/workspace:ro \
  ghcr.io/tooark/trivy-hadolint:latest \
  filesystem-scan \
    --branch feature/auth \
    --commit "$(git rev-parse HEAD)" \
    --user paulo.junior \
    --repository Tooark/myapp \
    --tag v1.2.3
```

---

## `.trivyignore`

The wrapper automatically resolves `.trivyignore` in the following order:

1. `TRIVY_IGNOREFILE` (explicit env)
2. `/.trivyignore` (container mount)
3. `$PWD/.trivyignore`

If none exists, the `--ignorefile` flag is **not passed** to Trivy.

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/.trivyignore":/.trivyignore:ro \
  ghcr.io/tooark/trivy-hadolint:latest \
  filesystem-scan
```

---

## SBOM generation

Available for `image-scan`, `filesystem-scan`, and `container`:

```bash
# CycloneDX (default)
ark-tools image-scan --sbom nginx:latest

# SPDX JSON
ark-tools image-scan --sbom-format spdx-json nginx:latest

# Container scan + SBOM
ark-tools container --sbom myapp:latest --path /workspace
```

> ℹ️ SBOM generation is an **additional scan** (it does not replace the
> vulnerability scan). If you only need the full package inventory along with
> the CVEs, prefer `TRIVY_ALL_PACKAGES=true` (default) — it is cheaper.

---

## Failure gate

- The **report** is always generated with **all severities** defined in
  `TRIVY_SEVERITY`, regardless of the gate.
- When `TRIVY_EXIT_CODE=1` (default), the wrapper parses the JSON and checks
  whether there are findings with a severity in `TRIVY_SEVERITY_FAIL`. If so, the pipeline fails.
- When `TRIVY_FORMAT != json`, the gate is **ignored** (with a warning).
- The gate analyzes `Vulnerabilities`, `Misconfigurations`, `Secrets`, and `Licenses`.

---

## Report delivery webhook

When `REPORT_URL` is set, `ark-tools` automatically sends the
`ark-report-tools` envelope via HTTP. It accepts one or multiple URLs:

```bash
-e REPORT_URL="https://hook1/api,https://hook2/api"
```

The **SBOM** can be sent to a different endpoint via `REPORT_SBOM_*`.

Delivery modes:

- **Per scan** (`REPORT_SEND_EACH_SCAN=true`): each individual command sends
  its own envelope.
- **Consolidated** (default in `container`): sends the `container-report.json`
  with all sub-results.

---

## Recommended mounts

| Mount                                            | Purpose                                                  |
| ------------------------------------------------ | -------------------------------------------------------- |
| `-v "$PWD":/workspace:ro`                        | Repository inside the container                          |
| `-v "$PWD/.git":/workspace/.git:ro`              | (optional) git fallback for SCM metadata                 |
| `-v "$PWD/.trivyignore":/.trivyignore:ro`        | Auto-detected `.trivyignore`                             |
| `-v "$HOME/.cache/trivy":/home/app/.cache/trivy` | Persistent Trivy DB cache                                |
| `-v "$PWD/scan-reports":/reports`                | Local report persistence                                 |
| `-v /var/run/docker.sock:/var/run/docker.sock`   | Scan of **local images** (entrypoint adjusts permission) |

---

## Practical examples

### **Local** image scan (via docker.sock)

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/tooark/trivy-hadolint:latest \
  image-scan mylocalimage:tag
```

> The `docker-entrypoint.sh` automatically syncs the socket GID and runs
> the process as the non-root user (`app`).

### Filesystem with persistent cache

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/.git":/workspace/.git:ro \
  -v "$HOME/.cache/trivy":/home/app/.cache/trivy \
  ghcr.io/tooark/trivy-hadolint:latest \
  filesystem-scan
```

### Full container scan with Trivy Server and webhook

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/scan-reports":/reports \
  -e TRIVY_SERVER=http://trivy-server.internal:4954 \
  -e TRIVY_TOKEN="$TRIVY_TOKEN" \
  -e TRIVY_SERVER_REQUIRED=false \
  -e TRIVY_SEVERITY=CRITICAL,HIGH \
  -e TRIVY_EXIT_CODE=1 \
  -e TRIVY_IGNORE_UNFIXED=true \
  -e HADOLINT_FAILURE_LEVEL=warning \
  -e REPORT_URL=https://example.internal/security/report \
  -e REPORT_TOKEN="$REPORT_TOKEN" \
  -e REPORT_FAIL_ON_ERROR=true \
  ghcr.io/tooark/trivy-hadolint:latest \
  container myapp:latest --path /workspace
```

### Container with multiple Dockerfiles

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  ghcr.io/tooark/trivy-hadolint:latest \
  container myapp:latest \
  --path /workspace \
  --dockerfiles "Dockerfile,docker/Dockerfile.worker,docker/Dockerfile.nginx"
```

### Passing extra flags to Trivy / Hadolint

Use `--` to forward arguments:

```bash
# Trivy
ark-tools image-scan myapp:tag -- --ignore-policy /policies/trivy.rego

# Hadolint
ark-tools dockerfile-lint /workspace/Dockerfile -- --ignore DL3008
```

> In the `container` command, flags after `--` are forwarded **only** to Trivy.

---

## Pipelines

### GitHub Actions

```yaml
name: Security Container Scan

on:
  push:
  pull_request:

jobs:
  container-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v4
        with:
          path: ~/.cache/trivy
          key: trivy-cache-${{ runner.os }}
      - name: Container scan
        env:
          TRIVY_SERVER: ${{ secrets.TRIVY_SERVER }}
          TRIVY_TOKEN: ${{ secrets.TRIVY_TOKEN }}
          REPORT_URL: ${{ secrets.REPORT_URL }}
          REPORT_TOKEN: ${{ secrets.REPORT_TOKEN }}
        run: |
          docker run --rm \
            -v "${{ github.workspace }}:/workspace:ro" \
            -v "$HOME/.cache/trivy:/home/app/.cache/trivy" \
            -v "$PWD/scan-reports:/reports" \
            -e GITHUB_ACTIONS -e GITHUB_REF_NAME -e GITHUB_SHA \
            -e GITHUB_REPOSITORY -e GITHUB_ACTOR \
            -e GITHUB_RUN_ID -e GITHUB_JOB -e GITHUB_SERVER_URL \
            -e TRIVY_SERVER -e TRIVY_TOKEN \
            -e TRIVY_SEVERITY=CRITICAL,HIGH \
            -e TRIVY_EXIT_CODE=1 \
            -e HADOLINT_FAILURE_LEVEL=warning \
            -e REPORT_URL -e REPORT_TOKEN \
            -e REPORT_FAIL_ON_ERROR=true \
            ghcr.io/tooark/trivy-hadolint:latest \
            container myapp:${{ github.sha }} --path /workspace
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: security-reports
          path: scan-reports/
```

### GitLab CI

```yaml
stages: [scan]

variables:
  TRIVY_SEVERITY: "CRITICAL,HIGH"
  TRIVY_EXIT_CODE: "1"
  TRIVY_IGNORE_UNFIXED: "true"
  HADOLINT_FAILURE_LEVEL: "warning"
  REPORT_FAIL_ON_ERROR: "true"

security_container_scan:
  stage: scan
  image: ghcr.io/tooark/trivy-hadolint:latest
  cache:
    key: trivy-db
    paths:
      - .cache/trivy
  variables:
    TRIVY_CACHE_DIR: "$CI_PROJECT_DIR/.cache/trivy"
    REPORT_DIR: "$CI_PROJECT_DIR/scan-reports"
  script:
    # The CI_*, GITLAB_USER_LOGIN, etc. variables are auto-detected
    - ark-tools container "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA" \
      --path "$CI_PROJECT_DIR"
  artifacts:
    when: always
    paths:
      - scan-reports/
    expire_in: 7 days
  allow_failure: true
```

---

## JSON Schema (`ark-report-tools`)

Every report generated by `ark-tools` follows the
**`ark-report-tools` v1.1** envelope, formalized in
[`schemas/ark-report-tools.schema.v1.1.json`](schemas/ark-report-tools.schema.v1.1.json).

Inside the image, the schema is also available at:

```bash
/usr/local/share/ark-tools/ark-report-tools.schema.v1.1.json
```

Path accessible via `ARK_REPORT_SCHEMA`.

### Envelope structure

```json
{
  "schema": "ark-report-tools",
  "version": "1.1",
  "timestamp": "2026-05-22T18:00:00Z",
  "command": "container",
  "target": "myapp:abc123",
  "tool": "trivy+hadolint",
  "sbom_enabled": false,
  "list_all_pkgs": true,
  "metadata": {
    "scm": {
      "branch": "...",
      "commit": "...",
      "commit_short": "...",
      "repository": "...",
      "tag": "..."
    },
    "ci": {
      "platform": "github",
      "user": "...",
      "pipeline_id": "...",
      "job_id": "...",
      "url": "..."
    },
    "scan_context": {
      "scan_path": "/workspace",
      "scan_mode": "fs",
      "dockerfiles": "Dockerfile"
    }
  },
  "report": {
    /* raw Trivy/Hadolint payload */
  },
  "results": {
    "image_scan": {
      /* ... */
    },
    "source_scan": {
      /* ... */
    },
    "dockerfile_lints": [
      {
        "file": "Dockerfile",
        "report": [
          /* ... */
        ]
      }
    ]
  }
}
```

### Envelope fields

| Field           | Type              | Required         | Description                                                                                           |
| --------------- | ----------------- | ---------------- | ----------------------------------------------------------------------------------------------------- |
| `schema`        | string (const)    | yes              | Always `"ark-report-tools"`                                                                           |
| `version`       | string            | yes              | Envelope version (`"1.1"`)                                                                            |
| `timestamp`     | string (ISO)      | yes              | Generation moment (UTC)                                                                               |
| `command`       | string (enum)     | yes              | `image-scan` \| `filesystem-scan` \| `config-scan` \| `repo-scan` \| `dockerfile-lint` \| `container` |
| `target`        | string            | yes              | Target image, path, or URL                                                                            |
| `tool`          | string            | yes              | `trivy`, `hadolint`, or `trivy+hadolint`                                                              |
| `sbom_enabled`  | boolean           | no               | Indicates whether an SBOM was generated                                                               |
| `list_all_pkgs` | boolean           | no               | Indicates whether the full inventory was included (`--list-all-pkgs`)                                 |
| `metadata`      | object            | no               | `scm{}` + `ci{}` + optionally `scan_context{}`                                                        |
| `report`        | object/array/null | yes              | Raw tool payload                                                                                      |
| `results`       | object/null       | `container` only | Consolidated sub-reports                                                                              |

> The **raw payload** (`report`) is kept flexible because the structure of the
> Trivy/Hadolint JSON varies between versions. The schema guarantees the
> stability of the **envelope**, not of the internal content.

### About `$schema` and `$id`

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:tooark:schemas:ark-report-tools:1.1"
}
```

- **`$schema`** indicates the **JSON Schema dialect** used (Draft 2020-12), not
  the path of your schema.
- **`$id`** is the **unique identifier** of the schema. Since `tooark.com` is
  static, the identifier is a **URN** (it does not need to be an accessible URL).

### About `allOf`

`allOf` performs **composition** (logical AND). In our schema, it is used to
apply a **conditional rule**: when `command == "container"`, the `results`
field becomes required.

---

## Report validation

### Node.js (AJV)

```bash
npm install ajv ajv-formats
```

```js
import fs from "node:fs";
import Ajv from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const schema = JSON.parse(
  fs.readFileSync("ark-report-tools.schema.v1.1.json", "utf8"),
);
const report = JSON.parse(fs.readFileSync("ark-report.json", "utf8"));

const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);

const validate = ajv.compile(schema);
if (!validate(report)) {
  console.error(validate.errors);
  process.exit(1);
}
console.log("✅ Valid report");
```

### Python (jsonschema)

```bash
pip install jsonschema
```

```python
import json
from jsonschema import Draft202012Validator

schema = json.load(open("ark-report-tools.schema.v1.1.json"))
report = json.load(open("ark-report.json"))

Draft202012Validator(schema).validate(report)
print("✅ Valid report")
```

### Inside the image (no dependencies)

The image ships the schema embedded. You can read it:

```bash
docker run --rm \
  --entrypoint cat \
  ghcr.io/tooark/trivy-hadolint:latest \
  /usr/local/share/ark-tools/ark-report-tools.schema.v1.1.json
```

---

## Wrapper tests

The project includes an automated test suite in `tests/run-tests.sh`,
covering the main functions of `ark-tools.sh` (flag parsing,
CI auto-detection, envelope, failure gate, etc.).

### Prerequisites

- `bash >= 4`
- `jq`
- `coreutils`

### Running

```bash
./tests/run-tests.sh

# Verbose mode (shows diffs on failures)
VERBOSE=1 ./tests/run-tests.sh
```

The tests load `ark-tools.sh` in **library mode** (without triggering the
dispatcher), via the `ARK_TOOLS_LIBRARY_MODE=1` variable. This allows
testing unit functions without side effects.

### Current coverage

- ✅ `is_true()` — boolean parser
- ✅ `should_use_list_all_pkgs()` — activation rules
- ✅ `trivy_list_all_pkgs_flag()` — per-command control (config does not receive it)
- ✅ `detect_ci_platform()` — all 5 platforms
- ✅ `_first_nonempty()` — value precedence
- ✅ `collect_metadata()` — auto-detect, CLI > env precedence, null normalization
- ✅ `parse_metadata_flags()` — all flags + `--flag=value` variants
- ✅ `resolve_trivy_ignorefile()` — fallback chain
- ✅ `default_fs_target()` — `/workspace` vs `$PWD`
- ✅ `wrap_ark_report()` — full envelope + default `{}`
- ✅ `trivy_failure_gate()` — clean/dirty/non-json report
- ✅ `_report_file_or_null()` — fallback to a `null.json` file

---

## Local build

```bash
version="1.72.0"    # Trivy + Hadolint image
trivy="0.71.0"      # Trivy
hadolint="2.14.0"   # Hadolint
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg TRIVY_VERSION=$trivy \
  --build-arg HADOLINT_VERSION=$hadolint \
  --build-arg TRIVY_HADOLINT_VERSION=$version \
  -t trivy-hadolint:$version \
  -t trivy-hadolint:$short \
  -t trivy-hadolint:latest \
  ./trivy-hadolint
```

---

## Common pitfalls

- **Strange base-OS CVEs in the report** → you forgot to mount the repo.
  Use `-v "$PWD":/workspace:ro` or run `filesystem-scan /explicit/path`.

- **`.trivyignore` not applied** → check the precedence (`TRIVY_IGNOREFILE` >
  `/.trivyignore` > `$PWD/.trivyignore`). In a container, the simplest is
  `-v "$PWD/.trivyignore":/.trivyignore:ro`.

- **Huge JSON report** → set `TRIVY_ALL_PACKAGES=false` if you only
  need the CVEs.

- **`metadata.scm.branch` is `null`** → you are outside a known CI and
  `.git` is not mounted. Use the `--branch/--commit/...` flags or mount
  `.git` at `/workspace/.git`.

- **GitHub Actions/Docker does not auto-detect** → you need to pass the variables with
  `-e GITHUB_*` in `docker run` (or use `--env-file`).

- **Local image scan fails due to permission** → mount
  `/var/run/docker.sock`; the entrypoint adjusts the GID/group automatically.

---

## License

MIT – see the `LICENSE` file at the repository root.
