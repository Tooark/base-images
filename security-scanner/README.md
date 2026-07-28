# security-scanner

Security base image of the **ark-\*** family, integrating **Trivy**, **Hadolint**,
and **Betterleaks** into a single CLI wrapper (`ark-tools`).

Focus: **vulnerability** scanning (Trivy), **Dockerfile linting** (Hadolint),
and **secret detection** (Betterleaks) — ideal for the "build/test" phase of
any repository.

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/security-scanner/README.pt-BR.md)

---

## Table of contents

- [Features](#features)
- [Image tags](#image-tags)
- [Image contents](#image-contents)
- [Quick start](#quick-start)
- [Available commands](#available-commands)
- [Aliases](#aliases)
- [Environment variables](#environment-variables)
- [SCM / CI metadata](#scm--ci-metadata)
- [Metadata flags](#metadata-flags-cli)
- [`.trivyignore`](#trivyignore)
- [SBOM](#sbom)
- [Failure gates](#failure-gates)
- [Webhook](#report-delivery-webhook)
- [Recommended mounts](#recommended-mounts)
- [Examples](#practical-examples)
- [Pipelines](#pipelines)
- [Examples in Samples](#examples-in-samples)
- [JSON Schema](#json-schema-ark-report-tools)
- [Tests](#tests)
- [Local build](#local-build)
- [License](#license)

---

## Features

- **Trivy** (image, filesystem, config, repository, secrets via scanner)
- **Hadolint** (Dockerfile lint)
- **Betterleaks** (git/dir secrets detection with optional history)
- Minimal Debian base with a non-root user
- Compatible with linux/amd64 and linux/arm64
- Consolidated `full-scan` command (Trivy + Hadolint + Betterleaks)
- Optional SBOM generation (CycloneDX/SPDX)
- Full package inventory (`--list-all-pkgs`)
- CI/SCM auto-detection (GitLab/GitHub/Azure/Bitbucket/Jenkins)
- Standardized webhook envelope (`ark-report-tools v1.2`)
- Trivy Server + local fallback
- Failure gates configurable per severity

---

## Image tags

| Tag                                                   | Description   |
| ----------------------------------------------------- | ------------- |
| `ghcr.io/tooark/security-scanner:<MAJOR.MINOR.PATCH>` | Full version  |
| `ghcr.io/tooark/security-scanner:<MAJOR.MINOR>`       | Short version |
| `ghcr.io/tooark/security-scanner:<MAJOR>`             | Major track   |
| `ghcr.io/tooark/security-scanner:latest`              | Latest stable |

---

## Image contents

| Item              | Description                                                    |
| ----------------- | -------------------------------------------------------------- |
| Base              | `debian:13-slim`                                               |
| Trivy             | `/usr/local/bin/trivy`                                         |
| Hadolint          | `/usr/local/bin/hadolint`                                      |
| Betterleaks       | `/usr/local/bin/betterleaks`                                   |
| CLI wrapper       | `/usr/local/bin/ark-tools`                                     |
| JSON Schema       | `/usr/local/share/ark-tools/ark-report-tools.schema.v1.2.json` |
| Runtime deps      | `bash`, `curl`, `jq`, `git`, `ca-certificates`, `gosu`         |
| Default user      | `app` (non-root)                                               |
| `WORKDIR`         | `/workspace`                                                   |
| Trivy cache       | `TRIVY_CACHE_DIR=/home/app/.cache/trivy`                       |
| Reports directory | `REPORT_DIR=/reports`                                          |
| Family identifier | `ARK_IMAGE_FAMILY=security-scanner`                            |

---

## Quick start

Run `help` and `version`:

```bash
docker run --rm ghcr.io/tooark/security-scanner:latest help
docker run --rm ghcr.io/tooark/security-scanner:latest version
```

Full scan (image + source + secrets + Dockerfile):

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/scan-reports":/reports \
  ghcr.io/tooark/security-scanner:latest \
  full-scan myapp:latest --path /workspace
```

---

## Available commands

```text
ark-tools help                                                                    # Help
ark-tools version                                                                 # Versions

ark-tools image-scan [--sbom[=fmt]] <image> [-- <extras>]                         # Trivy image
ark-tools filesystem-scan [--sbom[=fmt]] [path] [-- <extras>]                     # Trivy fs
ark-tools config-scan [path] [-- <extras>]                                        # Trivy IaC config
ark-tools repo-scan [path|url] [-- <extras>]                                      # Trivy repo
ark-tools dockerfile-lint [file] [-- <extras>]                                    # Hadolint
ark-tools secret-scan [--no-git] [--baseline <file>] [path] [-- <extras>]         # Betterleaks
ark-tools full-scan [opts] <image> [-- <extras>]                                  # Combo
ark-tools send-report <file>                                                      # Manual webhook
```

Metadata flags applicable to **all** scan commands:
`--branch`, `--commit`, `--user`, `--repository|--repo`, `--tag`.

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
| `secret-scan`     | `sec-scan`, `ss`  |
| `full-scan`       | `all`             |
| `send-report`     | `send`            |

---

## Environment variables

### Trivy (general)

| Variable                    | Default                            | Description                                                          |
| --------------------------- | ---------------------------------- | -------------------------------------------------------------------- |
| `TRIVY_SEVERITY`            | `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL` | Severities included in the report                                    |
| `TRIVY_IGNORE_UNFIXED`      | `false`                            | Drops vulnerabilities without a fix from the **report**              |
| `TRIVY_SEVERITY_FAIL`       | `HIGH,CRITICAL`                    | Severities that trigger the gate                                     |
| `TRIVY_IGNORE_UNFIXED_FAIL` | `true`                             | Gate blocks only on vulnerabilities that have a fix                  |
| `TRIVY_EXIT_CODE`           | `1`                                | `0` disables the gate                                                |
| `TRIVY_FORMAT`              | `json`                             | `json`, `sarif`, `table`, `cyclonedx`, `spdx-json`                   |
| `TRIVY_OUTPUT`              | per command                        | Output path                                                          |
| `TRIVY_TIMEOUT`             | `10m`                              | Timeout                                                              |
| `TRIVY_SCANNERS`            | Trivy default                      | E.g., `vuln,secret,misconfig,license`                                |
| `TRIVY_ALL_PACKAGES`        | `true`                             | Adds `--list-all-pkgs` (auto-disabled on `config-scan` and non-JSON) |
| `TRIVY_IGNOREFILE`          | auto-detect                        | Path to `.trivyignore`                                               |

### Trivy Server (optional)

| Variable                | Default | Description                   |
| ----------------------- | ------- | ----------------------------- |
| `TRIVY_SERVER`          | empty   | Trivy Server endpoint         |
| `TRIVY_TOKEN`           | empty   | Token (read natively)         |
| `TRIVY_SERVER_REQUIRED` | `false` | No local fallback when `true` |
| `TRIVY_TOKEN_AS_FLAG`   | `false` | Sends token via `--token`     |

### Hadolint

| Variable                    | Default     | Description                                             |
| --------------------------- | ----------- | ------------------------------------------------------- |
| `HADOLINT_CONFIG`           | empty       | `.hadolint.yaml`                                        |
| `HADOLINT_FORMAT`           | `json`      | `json`, `tty`, `sarif`                                  |
| `HADOLINT_FAILURE_LEVEL`    | `error`     | Gate level: `error`, `warning`, `info`, `style`, `none` |
| `HADOLINT_OUTPUT`           | per command | Output                                                  |
| `HADOLINT_LOG_MAX_FINDINGS` | `20`        | Max findings itemized in the log                        |

> **Report/gate split (like Trivy):** with JSON format the report always contains **all** levels (`error`, `warning`, `info`, `style`);  
> `HADOLINT_FAILURE_LEVEL` only controls which levels block the pipeline (default: only `error`). The log always prints a per-level summary  
> (`error: N, warning: N, ...`) plus an itemized list (`code [level] file:line message`). With non-JSON formats the gate falls back to  
> hadolint's own exit code (`--failure-threshold`).

### Betterleaks

| Variable                       | Default     | Description                                                            |
| ------------------------------ | ----------- | ---------------------------------------------------------------------- |
| `BETTERLEAKS_CONFIG`           | empty       | Path to `.betterleaks.toml`                                            |
| `BETTERLEAKS_BASELINE`         | empty       | Path to `betterleaks-baseline.json`                                    |
| `BETTERLEAKS_FORMAT`           | `json`      | `json`, `csv`, `junit`, `sarif`, `template`                            |
| `BETTERLEAKS_OUTPUT`           | per command | Output                                                                 |
| `BETTERLEAKS_NO_GIT`           | `false`     | Forces a local scan with `dir`                                         |
| `BETTERLEAKS_EXIT_CODE`        | `1`         | Exit code when secrets are found                                       |
| `BETTERLEAKS_FAIL_ON_FINDINGS` | `true`      | Fails the pipeline if secrets are found                                |
| `BETTERLEAKS_REDACT`           | `100`       | Percent of the secret masked in the report (`0-100`); `0` = clear text |
| `BETTERLEAKS_LOG_MAX_FINDINGS` | `20`        | Max findings itemized in the log                                       |

> **Safe log summary:** when secrets are found, the log prints one line per finding with rule, file, line and short commit  
> — never the secret content:
>
> ```text
> [ark-tools] Betterleaks: 2 potential secret(s) detected (see /reports/betterleaks.json)
>   - aws-access-key-id  deploy/config.sh:14  commit a1b2c3d
>   - generic-api-key    src/settings.py:88   commit 9f8e7d6
> ```
>
> The report itself has `Secret`/`Match` fully redacted by default (`BETTERLEAKS_REDACT=100`). Each finding keeps its `Fingerprint`,  
> which uniquely identifies the secret even fully redacted. Use e.g. `BETTERLEAKS_REDACT=80` to keep 20% of the secret visible for  
> triage, or `BETTERLEAKS_REDACT=0` to write it in clear (not recommended). Invalid values fall back to `100` (fail-safe).

### SBOM (optional)

| Variable      | Default     | Description              |
| ------------- | ----------- | ------------------------ |
| `SBOM_FORMAT` | `cyclonedx` | `cyclonedx`, `spdx-json` |
| `SBOM_OUTPUT` | per command | Output file              |

### Full-scan (combined)

| Variable                 | Default      | Description            |
| ------------------------ | ------------ | ---------------------- |
| `FULL_SCAN_PATH`         | auto-detect  | Project directory      |
| `FULL_SCAN_DOCKERFILES`  | `Dockerfile` | Comma-separated list   |
| `FULL_SCAN_MODE`         | `fs`         | `fs` or `repo` (Trivy) |
| `FULL_SCAN_SKIP_IMAGE`   | `false`      | Skip image scan        |
| `FULL_SCAN_SKIP_LINT`    | `false`      | Skip Dockerfile lint   |
| `FULL_SCAN_SKIP_SECRETS` | `false`      | Skip Betterleaks       |

### Webhook

| Variable                | Default    | Description                        |
| ----------------------- | ---------- | ---------------------------------- |
| `REPORT_URL`            | empty      | Comma-separated URLs               |
| `REPORT_TOKEN`          | empty      | Bearer                             |
| `REPORT_HEADERS`        | empty      | Extra headers (line by line)       |
| `REPORT_METHOD`         | `POST`     | HTTP method                        |
| `REPORT_FAIL_ON_ERROR`  | `false`    | Fails the pipeline if upload fails |
| `REPORT_SEND_EACH_SCAN` | `false`    | Sends after each individual scan   |
| `REPORT_DIR`            | `/reports` | Reports directory                  |

### Webhook SBOM (override)

| Variable                    | Fallback               |
| --------------------------- | ---------------------- |
| `REPORT_SBOM_URL`           | `REPORT_URL`           |
| `REPORT_SBOM_TOKEN`         | `REPORT_TOKEN`         |
| `REPORT_SBOM_HEADERS`       | `REPORT_HEADERS`       |
| `REPORT_SBOM_METHOD`        | `REPORT_METHOD`        |
| `REPORT_SBOM_FAIL_ON_ERROR` | `REPORT_FAIL_ON_ERROR` |

---

## SCM / CI metadata

Every report includes a `metadata` object with:

```json
{
  "metadata": {
    "scm": { "branch", "commit", "commit_short", "repository", "tag" },
    "ci":  { "platform", "user", "pipeline_id", "job_id", "url" }
  }
}
```

### Precedence

```plaintext
CLI flag > explicit env (CI_BRANCH, ...) > native CI env > git fallback > null
```

### Auto-detect

| Platform            | Detection                |
| ------------------- | ------------------------ |
| GitLab CI           | `GITLAB_CI`              |
| GitHub Actions      | `GITHUB_ACTIONS`         |
| Azure DevOps        | `TF_BUILD`               |
| Bitbucket Pipelines | `BITBUCKET_BUILD_NUMBER` |
| Jenkins             | `JENKINS_URL`            |

---

## Metadata flags (CLI)

```text
--branch <name>
--commit <sha>
--user <name>
--repository <name>   (alias: --repo)
--tag <name>
```

---

## `.trivyignore`

Auto-resolved in:

1. `TRIVY_IGNOREFILE` (env)
2. `/.trivyignore` (container mount)
3. `$PWD/.trivyignore`

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/.trivyignore":/.trivyignore:ro \
  ghcr.io/tooark/security-scanner:latest \
  filesystem-scan
```

---

## SBOM

```bash
# CycloneDX
ark-tools image-scan --sbom nginx:latest

# SPDX-JSON
ark-tools image-scan --sbom-format spdx-json nginx:latest

# Full-scan + SBOM
ark-tools full-scan --sbom myapp:latest --path /workspace
```

> For a full inventory without an extra SBOM, prefer `TRIVY_ALL_PACKAGES=true`
> (default). It is cheaper.

---

## Failure gates

| Gate        | Condition                                     | Control variable                              |
| ----------- | --------------------------------------------- | --------------------------------------------- |
| Trivy       | Severity in `TRIVY_SEVERITY_FAIL` with a fix  | `TRIVY_EXIT_CODE=1` (default)                 |
| Hadolint    | Findings at `HADOLINT_FAILURE_LEVEL` or above | `HADOLINT_FAILURE_LEVEL=error` (default)      |
| Betterleaks | Any secret detected                           | `BETTERLEAKS_FAIL_ON_FINDINGS=true` (default) |

The Trivy gate blocks only on vulnerabilities that have a fix by default (`TRIVY_IGNORE_UNFIXED_FAIL=true`);  
set it to `false` to also block on unfixed ones. The report itself keeps everything (`TRIVY_IGNORE_UNFIXED=false`).

The Hadolint gate follows the same report/gate split: warnings and lower levels always show up in the report and  
in the log summary, but only findings at `HADOLINT_FAILURE_LEVEL` or above (default: `error`) fail the pipeline.  
Set it to `warning` to also block on warnings, or `none` to disable the gate. The same gate is applied consistently  
by `dockerfile-lint` and `full-scan`.

When a gate is triggered, the log always prints a summary of what was found — per severity/level for Trivy and  
Hadolint, and per finding (rule, file, line, commit — never the secret content) for Betterleaks.

---

## Report delivery webhook

When `REPORT_URL` is set, `ark-tools` sends the envelope automatically:

```bash
-e REPORT_URL="https://hook1/api,https://hook2/api"
```

The SBOM can go to a separate endpoint via `REPORT_SBOM_*`.

---

## Recommended mounts

| Mount                                            | Purpose                                                    |
| ------------------------------------------------ | ---------------------------------------------------------- |
| `-v "$PWD":/workspace:ro`                        | Repository in the container                                |
| `-v "$PWD/.git":/workspace/.git:ro`              | (optional) git fallback for metadata + Betterleaks history |
| `-v "$PWD/.trivyignore":/.trivyignore:ro`        | Auto-detected `.trivyignore`                               |
| `-v "$HOME/.cache/trivy":/home/app/.cache/trivy` | Persistent Trivy DB cache                                  |
| `-v "$PWD/scan-reports":/reports`                | Local report persistence                                   |
| `-v /var/run/docker.sock:/var/run/docker.sock`   | Image scan of local images (entrypoint adjusts permission) |

> ⚠️ For Betterleaks to scan git history, mount `.git` **without** `:ro`
> when using it with a baseline or commands that need to write a cache.

---

## Practical examples

### Local image scan (via docker.sock)

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/tooark/security-scanner:latest \
  image-scan mylocalimage:tag
```

> The `docker-entrypoint.sh` automatically syncs the socket GID and runs
> the process as the non-root user (`app`).

### Secret scan without git history (faster)

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  ghcr.io/tooark/security-scanner:latest \
  secret-scan --no-git /workspace
```

### Secret scan with baseline

```bash
docker run --rm \
  -v "$PWD":/workspace \
  ghcr.io/tooark/security-scanner:latest \
  secret-scan --baseline /workspace/.betterleaks-baseline.json /workspace
```

### Full scan with webhook

```bash
docker run --rm \
  -v "$PWD":/workspace \
  -v "$PWD/scan-reports":/reports \
  -e TRIVY_SERVER=http://trivy-server.internal:4954 \
  -e TRIVY_TOKEN="$TRIVY_TOKEN" \
  -e TRIVY_SEVERITY=CRITICAL,HIGH \
  -e HADOLINT_FAILURE_LEVEL=warning \
  -e BETTERLEAKS_FAIL_ON_FINDINGS=true \
  -e REPORT_URL="https://security-hub/api/reports" \
  -e REPORT_TOKEN="$REPORT_TOKEN" \
  -e REPORT_FAIL_ON_ERROR=true \
  ghcr.io/tooark/security-scanner:latest \
  full-scan myapp:latest --path /workspace
```

### Full scan skipping Betterleaks

```bash
docker run --rm -v "$PWD":/workspace \
  ghcr.io/tooark/security-scanner:latest \
  full-scan myapp:latest --path /workspace --skip-secrets
```

---

## Pipelines

### GitHub Actions

```yaml
name: Security Scan
on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Betterleaks needs full history
      - uses: actions/cache@v4
        with:
          path: ~/.cache/trivy
          key: trivy-cache-${{ runner.os }}
      - name: Full security scan
        env:
          REPORT_URL: ${{ secrets.REPORT_URL }}
          REPORT_TOKEN: ${{ secrets.REPORT_TOKEN }}
        run: |
          docker run --rm \
            -v "${{ github.workspace }}:/workspace" \
            -v "$HOME/.cache/trivy:/home/app/.cache/trivy" \
            -v "$PWD/scan-reports:/reports" \
            -e GITHUB_ACTIONS -e GITHUB_REF_NAME -e GITHUB_SHA \
            -e GITHUB_REPOSITORY -e GITHUB_ACTOR \
            -e GITHUB_RUN_ID -e GITHUB_JOB -e GITHUB_SERVER_URL \
            -e REPORT_URL -e REPORT_TOKEN \
            -e REPORT_FAIL_ON_ERROR=true \
            ghcr.io/tooark/security-scanner:latest \
            full-scan myapp:${{ github.sha }} --path /workspace
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: security-reports
          path: scan-reports/
```

### GitLab CI

```yaml
stages: [security]

variables:
  TRIVY_SEVERITY: "CRITICAL,HIGH"
  HADOLINT_FAILURE_LEVEL: "warning"
  BETTERLEAKS_FAIL_ON_FINDINGS: "true"
  REPORT_FAIL_ON_ERROR: "true"
  GIT_DEPTH: "0" # Betterleaks needs full history

security_scan:
  stage: security
  image: ghcr.io/tooark/security-scanner:latest
  cache:
    key: trivy-db
    paths:
      - .cache/trivy
  variables:
    TRIVY_CACHE_DIR: "$CI_PROJECT_DIR/.cache/trivy"
    REPORT_DIR: "$CI_PROJECT_DIR/scan-reports"
  script:
    - ark-tools full-scan "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA" --path "$CI_PROJECT_DIR"
  artifacts:
    when: always
    paths:
      - scan-reports/
    expire_in: 7 days
  allow_failure: true
```

---

## Examples in Samples

For easier reuse, there are complete examples in [samples/README.md](../samples/README.md):

- Local: [samples/security-scanner-local.sh](../samples/security-scanner-local.sh)
- GitHub Actions: [samples/security-scanner-github-actions.yml](../samples/security-scanner-github-actions.yml)
- GitLab CI: [samples/security-scanner-gitlab-ci.yml](../samples/security-scanner-gitlab-ci.yml)

These examples cover a broad set of commands, flags, and environment variables of the `security-scanner` image.

---

## JSON Schema (`ark-report-tools`)

Every report follows the **`ark-report-tools v1.2`** envelope,
formalized in [`schemas/ark-report-tools.schema.v1.2.json`](schemas/ark-report-tools.schema.v1.2.json).

Inside the image, it is also available at
`/usr/local/share/ark-tools/ark-report-tools.schema.v1.2.json`
(accessible via `ARK_REPORT_SCHEMA`).

### Structure

```json
{
  "schema": "ark-report-tools",
  "version": "1.2",
  "image_family": "security-scanner",
  "timestamp": "2026-05-31T18:00:00Z",
  "command": "full-scan",
  "target": "myapp:latest",
  "tool": "trivy+hadolint+betterleaks",
  "sbom_enabled": false,
  "list_all_pkgs": true,
  "metadata": { "scm": {...}, "ci": {...}, "scan_context": {...} },
  "report": { /* raw payload */ },
  "results": {
    "image_scan":       { /* trivy */ },
    "source_scan":      { /* trivy */ },
    "secret_scan":      [ /* betterleaks */ ],
    "dockerfile_lints": [ { "file": "Dockerfile", "report": [...] } ]
  }
}
```

### `image_family` field

Enables routing/analytics across **trivy-hadolint**, **security-scanner**,
and **iac-scanner** in a single ingestion backend.

### Validation

```bash
# Node.js
npm install ajv ajv-formats
node -e "
  const fs = require('fs');
  const Ajv = require('ajv/dist/2020.js');
  const addFormats = require('ajv-formats');
  const schema = JSON.parse(fs.readFileSync('schemas/ark-report-tools.schema.v1.2.json'));
  const report = JSON.parse(fs.readFileSync('full-scan-report.json'));
  const ajv = new Ajv({ strict: false }); addFormats(ajv);
  const validate = ajv.compile(schema);
  if (!validate(report)) { console.error(validate.errors); process.exit(1); }
  console.log('OK');
"

# Python
pip install jsonschema
python -c "
import json
from jsonschema import Draft202012Validator
s = json.load(open('schemas/ark-report-tools.schema.v1.2.json'))
r = json.load(open('full-scan-report.json'))
Draft202012Validator(s).validate(r)
print('OK')
"
```

---

## Tests

```bash
./tests/run-tests.sh
VERBOSE=1 ./tests/run-tests.sh
```

The suite covers:

- `is_true()`, `detect_ci_platform()`, `_first_nonempty()`
- `collect_metadata()` (auto-detect, precedence, null normalization)
- `parse_metadata_flags()` (including the parent-shell bugfix with `REMAINING_ARGS`)
- `wrap_ark_report()` (v1.2 envelope + `image_family`)
- `_report_file_or_null()`
- `should_use_list_all_pkgs()` and `trivy_list_all_pkgs_flag()` (config does NOT receive it)
- `resolve_trivy_ignorefile()`
- `trivy_failure_gate()`
- `betterleaks_failure_gate()` (including the safe summary that never leaks the secret)
- `hadolint_failure_gate()` (report/gate split per level)

---

## Local build

```bash
version="1.0.0"      # Security Scanner
trivy="0.71.0"       # Trivy
hadolint="2.14.0"    # Hadolint
betterleaks="1.3.1"  # Betterleaks
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg TRIVY_VERSION=$trivy \
  --build-arg HADOLINT_VERSION=$hadolint \
  --build-arg BETTERLEAKS_VERSION=$betterleaks \
  --build-arg SECURITY_SCANNER_VERSION=$version \
  -t "security-scanner:$version" \
  -t "security-scanner:$short" \
  -t security-scanner:latest \
  ./security-scanner
```

---

## Official documentation

- [Trivy](https://trivy.dev/docs/latest/guide/)
  - [Release notes](https://github.com/aquasecurity/trivy/releases)
- [Hadolint](https://github.com/hadolint/hadolint)
  - [Release notes](https://github.com/hadolint/hadolint/releases)
- [Betterleaks](https://github.com/betterleaks/betterleaks)
  - [Release notes](https://github.com/betterleaks/betterleaks/releases)

---

## License

MIT — see `LICENSE` at the repository root.
