# dast-scanner

Base image with **OWASP ZAP** and **Nuclei** for authorized dynamic application
security testing (DAST). It follows the repository's `security-scanner` image
conventions while keeping runtime web testing separate from source and image
scanning.

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/dast-scanner/README.pt-BR.md)

---

## Features

- **Nuclei** for technology discovery and template-based checks
- **OWASP ZAP** for web application crawling and passive/active testing
- Debian 13 slim runtime; non-root `app` user
- linux/amd64 and linux/arm64
- Pinned tool versions, with Nuclei release checksum verification
- `ark-report-tools` v1.4 envelopes with scanner-image identity and native report references
- No target is scanned when the container starts; Nuclei may fetch templates
  when an operator explicitly runs it, following Nuclei's default behavior

## Image contents

| Item | Description |
| ---- | ----------- |
| Base | `debian:13-slim` |
| OWASP ZAP | `zap` command |
| Nuclei | `nuclei` command |
| CLI | `/usr/local/bin/dast-tools` |
| Runtime dependencies | Java 21, `bash`, `curl`, `ca-certificates`, `gosu`, `jq`, `unzip` |
| Report schema | `/usr/local/share/dast-tools/ark-report-tools.schema.v1.4.json` |
| Default user | `app` (non-root) |
| `WORKDIR` | `/workspace` |
| Reports directory | `/reports` |

## Responsible use and scan modes

Use the tools only against systems you own or have explicit permission to test.
Confirm the authorized hosts, paths, test window, request rate, and data-handling
rules with the system owner before scanning. Prefer a staging environment with
test data.

Nuclei can support reconnaissance (for example, technology-tagged templates),
but it is also a vulnerability scanner; its impact depends on the templates
selected. ZAP's passive analysis observes proxied traffic, while active scans
send crafted requests and may change application data or affect availability.
Start with passive checks where possible and reserve active scans for approved
targets and windows.

The image does not start scans by itself. Running a command is an explicit
operator action. When Nuclei is invoked, its default behavior may fetch or
update templates; pin or pre-populate a reviewed template set when repeatable
results are required. A mounted report directory is writable by the non-root
user.

## Quick start

Build locally and check the tools without scanning a target:

```bash
bash ./script/build-and-run-local.sh build dast-scanner
docker run --rm ghcr.io/tooark/dast-scanner:latest help
docker run --rm ghcr.io/tooark/dast-scanner:latest version
```

For an authorized staging application, set the exact target and persist reports:

```bash
export DAST_TARGET="https://staging.example.test"
mkdir -p "$PWD/dast-reports"

docker run --rm \
  -v "$PWD/dast-reports:/reports" \
  ghcr.io/tooark/dast-scanner:latest \
  nuclei-scan "$DAST_TARGET" -tags tech
```

This writes the native Nuclei JSONL to `nuclei.jsonl` and a standardized
`nuclei-report.json` envelope. The envelope identifies the scanner image and
includes the native artifact's path, format, media type, SHA-256, and size.

An OWASP ZAP quick scan crawls the URL and performs **active** checks. The
explicit `--active` flag is required:

```bash
docker run --rm \
  -v "$PWD/dast-reports:/reports" \
  ghcr.io/tooark/dast-scanner:latest \
  zap-scan "$DAST_TARGET" --active
```

For both tools, use the combined command; its active ZAP step also requires
explicit authorization:

```bash
docker run --rm \
  -v "$PWD/dast-reports:/reports" \
  ghcr.io/tooark/dast-scanner:latest \
  dast-scan "$DAST_TARGET" --active -tags tech
```

Use only a target and scan profile approved by the application owner. Tune
Nuclei templates and scan rate to the scope; do not treat a scan as proof that an
application is secure.

The combined command preserves `nuclei.jsonl` and `zap-active.html`, emits
`nuclei-report.json` and `zap-report.json`, and writes
`dast-scan-report.json` containing both per-tool envelopes. The combined report
references both native files. The `nuclei` and `zap` commands remain direct
pass-throughs to the upstream CLIs and do not generate envelopes.

The export uses the same `ark-report-tools` v1.4 schema as `security-scanner`.
The shared schema file is [`schemas/ark-report-tools.schema.v1.4.json`](schemas/ark-report-tools.schema.v1.4.json)
and is also available in the image through `ARK_REPORT_SCHEMA`.

## Commands

```text
dast-tools help
dast-tools version
dast-tools nuclei [Nuclei options]
dast-tools zap [ZAP options]
dast-tools nuclei-scan <http(s)://target> [Nuclei options]
dast-tools zap-scan <http(s)://target> --active [ZAP options]
dast-tools dast-scan <http(s)://target> --active [Nuclei options]
```

`nuclei-scan` manages the target and JSONL output options; the native CLI
pass-through remains available as `nuclei`. Nuclei can update templates when
run; use a reviewed, pinned template set when repeatable results are required.
ZAP quick scans are active; the ZAP and combined scan commands require
`--active`.

## Versioning and local build

Tool and image versions are centralized in the repository's `versions.env`.
The image's `VERSION` file controls its release tags.

```bash
bash ./script/build-and-run-local.sh build dast-scanner
docker run --rm dast-scanner:latest version
```

## License

This image definition is MIT-licensed. OWASP ZAP and Nuclei retain their
respective upstream licenses.
