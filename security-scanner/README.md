# security-scanner

Imagem base de segurança da família **ark-\***, integrando **Trivy**, **Hadolint**
e **Betterleaks** em um único wrapper CLI (`ark-tools`).

Foco: scan de **vulnerabilidades** (Trivy), **Dockerfile linting** (Hadolint)
e **detecção de secrets** (Betterleaks) — ideal para a fase de "build/test" de
qualquer repositório.

---

## Sumário

- [Recursos](#recursos)
- [Tags da imagem](#tags-da-imagem)
- [Conteúdo da imagem](#conteúdo-da-imagem)
- [Início rápido](#início-rápido)
- [Comandos disponíveis](#comandos-disponíveis)
- [Aliases](#aliases)
- [Variáveis de ambiente](#variáveis-de-ambiente)
- [Metadados SCM / CI](#metadados-scm--ci)
- [Flags de metadata](#flags-de-metadata-cli)
- [`.trivyignore`](#trivyignore)
- [SBOM](#sbom)
- [Failure gates](#failure-gates)
- [Webhook](#webhook-de-envio-de-relatórios)
- [Mounts recomendados](#mounts-recomendados)
- [Exemplos](#exemplos-práticos)
- [Pipelines](#pipelines)
- [Exemplos Em Samples](#exemplos-em-samples)
- [JSON Schema](#json-schema-ark-report-tools)
- [Testes](#testes)
- [Build local](#build-local)
- [Licença](#licença)

---

## Recursos

- **Trivy** (image, filesystem, config, repository, secrets via scanner)
- **Hadolint** (Dockerfile lint)
- **Betterleaks** (git/dir secrets detection com history opcional)
- Base Debian minimalista com usuário não-root
- Compatível com linux/amd64 e linux/arm64
- Comando consolidado `full-scan` (Trivy + Hadolint + Betterleaks)
- Geração de SBOM (CycloneDX/SPDX) opcional
- Inventário completo de pacotes (`--list-all-pkgs`)
- Auto-detect de CI/SCM (GitLab/GitHub/Azure/Bitbucket/Jenkins)
- Webhook envelope padronizado (`ark-report-tools v1.2`)
- Trivy Server + fallback local
- Failure gates configuráveis por severidade

---

## Tags da imagem

| Tag                                                   | Descrição       |
| ----------------------------------------------------- | --------------- |
| `ghcr.io/tooark/security-scanner:<MAJOR.MINOR.PATCH>` | Versão completa |
| `ghcr.io/tooark/security-scanner:<MAJOR.MINOR>`       | Versão curta    |
| `ghcr.io/tooark/security-scanner:<MAJOR>`             | Major track     |
| `ghcr.io/tooark/security-scanner:latest`              | Última estável  |

---

## Conteúdo da imagem

| Item                  | Descrição                                                      |
| --------------------- | -------------------------------------------------------------- |
| Base                  | `debian:12-slim`                                               |
| Trivy                 | `/usr/local/bin/trivy`                                         |
| Hadolint              | `/usr/local/bin/hadolint`                                      |
| Betterleaks           | `/usr/local/bin/betterleaks`                                   |
| Wrapper CLI           | `/usr/local/bin/ark-tools`                                     |
| JSON Schema           | `/usr/local/share/ark-tools/ark-report-tools.schema.v1.2.json` |
| Runtime deps          | `bash`, `curl`, `jq`, `git`, `ca-certificates`                 |
| Usuário padrão        | `app` (não-root)                                               |
| `WORKDIR`             | `/workspace`                                                   |
| Cache Trivy           | `TRIVY_CACHE_DIR=/home/app/.cache/trivy`                       |
| Diretório de reports  | `REPORT_DIR=/reports`                                          |
| Identificador família | `ARK_IMAGE_FAMILY=security-scanner`                            |

---

## Início rápido

Executar `help` e `version`:

```bash
docker run --rm ghcr.io/tooark/security-scanner:latest help
docker run --rm ghcr.io/tooark/security-scanner:latest version
```

Scan completo (image + source + secrets + Dockerfile):

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/scan-reports":/reports \
  ghcr.io/tooark/security-scanner:latest \
  full-scan myapp:latest --path /workspace
```

---

## Comandos disponíveis

```text
ark-tools help                                                                    # Ajuda
ark-tools version                                                                 # Versões

ark-tools image-scan [--sbom[=fmt]] <image> [-- <extras>]                         # Trivy image
ark-tools filesystem-scan [--sbom[=fmt]] [path] [-- <extras>]                     # Trivy fs
ark-tools config-scan [path] [-- <extras>]                                        # Trivy IaC config
ark-tools repo-scan [path|url] [-- <extras>]                                      # Trivy repo
ark-tools dockerfile-lint [file] [-- <extras>]                                    # Hadolint
ark-tools secret-scan [--no-git] [--baseline <file>] [path] [-- <extras>]         # Betterleaks
ark-tools full-scan [opts] <image> [-- <extras>]                                  # Combo
ark-tools send-report <file>                                                      # Webhook manual
```

Flags de metadata aplicáveis a **todos** os comandos de scan:
`--branch`, `--commit`, `--user`, `--repository|--repo`, `--tag`.

---

## Aliases

| Comando           | Aliases           |
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

## Variáveis de ambiente

### Trivy (gerais)

| Variável               | Default                            | Descrição                                                           |
| ---------------------- | ---------------------------------- | ------------------------------------------------------------------- |
| `TRIVY_SEVERITY`       | `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL` | Severidades incluídas no relatório                                  |
| `TRIVY_SEVERITY_FAIL`  | `HIGH,CRITICAL`                    | Severidades que disparam o gate                                     |
| `TRIVY_EXIT_CODE`      | `1`                                | `0` desativa o gate                                                 |
| `TRIVY_IGNORE_UNFIXED` | `true`                             | Ignora vulnerabilidades sem fix                                     |
| `TRIVY_FORMAT`         | `json`                             | `json`, `sarif`, `table`, `cyclonedx`, `spdx-json`                  |
| `TRIVY_OUTPUT`         | por comando                        | Caminho de saída                                                    |
| `TRIVY_TIMEOUT`        | `10m`                              | Timeout                                                             |
| `TRIVY_SCANNERS`       | padrão do Trivy                    | Ex.: `vuln,secret,misconfig,license`                                |
| `TRIVY_ALL_PACKAGES`   | `true`                             | Inclui `--list-all-pkgs` (auto-disable em `config-scan` e não-JSON) |
| `TRIVY_IGNOREFILE`     | auto-detect                        | Path do `.trivyignore`                                              |

### Trivy Server (opcional)

| Variável                | Default | Descrição                        |
| ----------------------- | ------- | -------------------------------- |
| `TRIVY_SERVER`          | vazio   | Endpoint do Trivy Server         |
| `TRIVY_TOKEN`           | vazio   | Token (lido nativamente)         |
| `TRIVY_SERVER_REQUIRED` | `false` | Sem fallback local quando `true` |
| `TRIVY_TOKEN_AS_FLAG`   | `false` | Envia token via `--token`        |

### Hadolint

| Variável                 | Default     | Descrição              |
| ------------------------ | ----------- | ---------------------- |
| `HADOLINT_CONFIG`        | vazio       | `.hadolint.yaml`       |
| `HADOLINT_FORMAT`        | `json`      | `json`, `tty`, `sarif` |
| `HADOLINT_FAILURE_LEVEL` | vazio       | `warning`, `error`     |
| `HADOLINT_OUTPUT`        | por comando | Saída                  |

### Betterleaks

| Variável                       | Default     | Descrição                                   |
| ------------------------------ | ----------- | ------------------------------------------- |
| `BETTERLEAKS_CONFIG`           | vazio       | Path para `.betterleaks.toml`               |
| `BETTERLEAKS_BASELINE`         | vazio       | Path para `betterleaks-baseline.json`       |
| `BETTERLEAKS_FORMAT`           | `json`      | `json`, `csv`, `junit`, `sarif`, `template` |
| `BETTERLEAKS_OUTPUT`           | por comando | Saída                                       |
| `BETTERLEAKS_NO_GIT`           | `false`     | Força scan local com `dir`                  |
| `BETTERLEAKS_EXIT_CODE`        | `1`         | Exit code quando encontrar secrets          |
| `BETTERLEAKS_FAIL_ON_FINDINGS` | `true`      | Falha pipeline se encontrar secrets         |

### SBOM (opcional)

| Variável      | Default     | Descrição                |
| ------------- | ----------- | ------------------------ |
| `SBOM_FORMAT` | `cyclonedx` | `cyclonedx`, `spdx-json` |
| `SBOM_OUTPUT` | por comando | Arquivo de saída         |

### Full-scan (combinado)

| Variável                 | Default      | Descrição                  |
| ------------------------ | ------------ | -------------------------- |
| `FULL_SCAN_PATH`         | auto-detect  | Diretório do projeto       |
| `FULL_SCAN_DOCKERFILES`  | `Dockerfile` | Lista separada por vírgula |
| `FULL_SCAN_MODE`         | `fs`         | `fs` ou `repo` (Trivy)     |
| `FULL_SCAN_SKIP_IMAGE`   | `false`      | Pula image scan            |
| `FULL_SCAN_SKIP_LINT`    | `false`      | Pula Dockerfile lint       |
| `FULL_SCAN_SKIP_SECRETS` | `false`      | Pula Betterleaks           |

### Webhook

| Variável                | Default    | Descrição                        |
| ----------------------- | ---------- | -------------------------------- |
| `REPORT_URL`            | vazio      | URLs separadas por vírgula       |
| `REPORT_TOKEN`          | vazio      | Bearer                           |
| `REPORT_HEADERS`        | vazio      | Headers extras (linha por linha) |
| `REPORT_METHOD`         | `POST`     | HTTP method                      |
| `REPORT_FAIL_ON_ERROR`  | `false`    | Falha pipeline se upload falhar  |
| `REPORT_SEND_EACH_SCAN` | `false`    | Envia após cada scan individual  |
| `REPORT_DIR`            | `/reports` | Diretório de relatórios          |

### Webhook SBOM (override)

| Variável                    | Fallback               |
| --------------------------- | ---------------------- |
| `REPORT_SBOM_URL`           | `REPORT_URL`           |
| `REPORT_SBOM_TOKEN`         | `REPORT_TOKEN`         |
| `REPORT_SBOM_HEADERS`       | `REPORT_HEADERS`       |
| `REPORT_SBOM_METHOD`        | `REPORT_METHOD`        |
| `REPORT_SBOM_FAIL_ON_ERROR` | `REPORT_FAIL_ON_ERROR` |

---

## Metadados SCM / CI

Todos os relatórios incluem um objeto `metadata` com:

```json
{
  "metadata": {
    "scm": { "branch", "commit", "commit_short", "repository", "tag" },
    "ci":  { "platform", "user", "pipeline_id", "job_id", "url" }
  }
}
```

### Precedência

```plaintext
CLI flag > env explícita (CI_BRANCH, ...) > env nativa do CI > git fallback > null
```

### Auto-detect

| Plataforma          | Detecção                 |
| ------------------- | ------------------------ |
| GitLab CI           | `GITLAB_CI`              |
| GitHub Actions      | `GITHUB_ACTIONS`         |
| Azure DevOps        | `TF_BUILD`               |
| Bitbucket Pipelines | `BITBUCKET_BUILD_NUMBER` |
| Jenkins             | `JENKINS_URL`            |

---

## Flags de metadata (CLI)

```text
--branch <name>
--commit <sha>
--user <name>
--repository <name>   (alias: --repo)
--tag <name>
```

---

## `.trivyignore`

Auto-resolvido em:

1. `TRIVY_IGNOREFILE` (env)
2. `/.trivyignore` (mount em container)
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

> Para inventário completo sem SBOM extra, prefira `TRIVY_ALL_PACKAGES=true`
> (default). É mais barato.

---

## Failure gates

| Gate        | Condição                                 | Var de controle                               |
| ----------- | ---------------------------------------- | --------------------------------------------- |
| Trivy       | Severidade em `TRIVY_SEVERITY_FAIL`      | `TRIVY_EXIT_CODE=1` (default)                 |
| Hadolint    | Issues no nível `HADOLINT_FAILURE_LEVEL` | `HADOLINT_FAILURE_LEVEL`                      |
| Betterleaks | Qualquer secret detectado                | `BETTERLEAKS_FAIL_ON_FINDINGS=true` (default) |

---

## Webhook de envio de relatórios

Quando `REPORT_URL` é definido, o `ark-tools` envia o envelope automaticamente:

```bash
-e REPORT_URL="https://hook1/api,https://hook2/api"
```

SBOM pode ir para endpoint separado via `REPORT_SBOM_*`.

---

## Mounts recomendados

| Mount                                            | Propósito                                                 |
| ------------------------------------------------ | --------------------------------------------------------- |
| `-v "$PWD":/workspace:ro`                        | Repositório no container                                  |
| `-v "$PWD/.git":/workspace/.git:ro`              | (opcional) Fallback git p/ metadata + Betterleaks history |
| `-v "$PWD/.trivyignore":/.trivyignore:ro`        | `.trivyignore` auto-detectado                             |
| `-v "$HOME/.cache/trivy":/home/app/.cache/trivy` | Cache persistente do Trivy DB                             |
| `-v "$PWD/scan-reports":/reports`                | Persistência local dos relatórios                         |
| `-v /var/run/docker.sock:/var/run/docker.sock`   | Image scan de imagens locais (requer `--user 0`)          |

> ⚠️ Para Betterleaks vasculhar history do git, monte `.git` **sem** `:ro`
> quando usar com baseline ou comandos que precisem escrever cache.

---

## Exemplos práticos

### Scan de imagem local (via docker.sock)

```bash
docker run --rm --user 0 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/tooark/security-scanner:latest \
  image-scan mylocalimage:tag
```

### Secret scan sem git history (mais rápido)

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  ghcr.io/tooark/security-scanner:latest \
  secret-scan --no-git /workspace
```

### Secret scan com baseline

```bash
docker run --rm \
  -v "$PWD":/workspace \
  ghcr.io/tooark/security-scanner:latest \
  secret-scan --baseline /workspace/.betterleaks-baseline.json /workspace
```

### Full-scan completo com webhook

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

### Full-scan pulando Betterleaks

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
          fetch-depth: 0 # Betterleaks precisa de history completo
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
  GIT_DEPTH: "0" # Betterleaks precisa history completo

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

## Exemplos Em Samples

Para facilitar reaproveitamento, existem exemplos completos em [samples/README.md](../samples/README.md):

- Local: [samples/security-scanner-local.sh](../samples/security-scanner-local.sh)
- GitHub Actions: [samples/security-scanner-github-actions.yml](../samples/security-scanner-github-actions.yml)
- GitLab CI: [samples/security-scanner-gitlab-ci.yml](../samples/security-scanner-gitlab-ci.yml)

Esses exemplos incluem cobertura ampla de comandos, flags e variáveis de ambiente da imagem `security-scanner`.

---

## JSON Schema (`ark-report-tools`)

Todos os relatórios seguem o envelope **`ark-report-tools v1.2`**,
formalizado em [`schemas/ark-report-tools.schema.v1.2.json`](schemas/ark-report-tools.schema.v1.2.json).

Dentro da imagem, também disponível em
`/usr/local/share/ark-tools/ark-report-tools.schema.v1.2.json`
(acessível via `ARK_REPORT_SCHEMA`).

### Estrutura

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
  "report": { /* payload bruto */ },
  "results": {
    "image_scan":       { /* trivy */ },
    "source_scan":      { /* trivy */ },
    "secret_scan":      [ /* betterleaks */ ],
    "dockerfile_lints": [ { "file": "Dockerfile", "report": [...] } ]
  }
}
```

### Campo `image_family`

Permite roteamento/analytics entre **trivy-hadolint**, **security-scanner**
e **iac-scanner** num backend de ingestão único.

### Validação

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

## Testes

```bash
./tests/run-tests.sh
VERBOSE=1 ./tests/run-tests.sh
```

A suite cobre:

- `is_true()`, `detect_ci_platform()`, `_first_nonempty()`
- `collect_metadata()` (auto-detect, precedência, normalização null)
- `parse_metadata_flags()` (incluindo o bugfix do shell pai com `REMAINING_ARGS`)
- `wrap_ark_report()` (envelope v1.2 + `image_family`)
- `_report_file_or_null()`
- `should_use_list_all_pkgs()` e `trivy_list_all_pkgs_flag()` (config NÃO recebe)
- `resolve_trivy_ignorefile()`
- `trivy_failure_gate()`
- `betterleaks_failure_gate()`

---

## Build local

```bash
version="1.0.0"      # Security Scanner
trivy="0.70.0"       # Trivy
hadolint="2.14.0"    # Hadolint
betterleaks="1.3.1"  # Betterleaks
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  -t security-scanner:local \
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

## Documentação oficial

- [Trivy](https://trivy.dev/docs/latest/guide/)
  - [Notas de lançamento](https://github.com/aquasecurity/trivy/releases)
- [Hadolint](https://github.com/hadolint/hadolint)
  - [Notas de lançamento](https://github.com/hadolint/hadolint/releases)
- [Betterleaks](https://github.com/betterleaks/betterleaks)
  - [Notas de lançamento](https://github.com/betterleaks/betterleaks/releases)

---

## Licença

MIT — ver `LICENSE` na raiz do repositório.
