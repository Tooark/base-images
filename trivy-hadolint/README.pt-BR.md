# trivy-hadolint

Imagem base com **Trivy** e **Hadolint** integrados, focada em padronizar scans
de segurança em pipelines de CI/CD.

A imagem expõe um wrapper CLI chamado **`ark-tools`** que cobre os principais
cenários de análise (imagem, filesystem, IaC, repositório e Dockerfile) e
consolida os resultados em um envelope JSON padronizado: o
[**ark-report-tools**](#json-schema-ark-report-tools).

🌍 **Idiomas:** [![USA Flag](https://flagcdn.com/w20/us.png) English](https://github.com/Tooark/base-images/blob/main/trivy-hadolint/README.md) · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/base-images/blob/main/trivy-hadolint/README.pt-BR.md)

---

## Sumário

- [Recursos](#recursos)
- [Tags da imagem](#tags-da-imagem)
- [Conteúdo da imagem](#conteúdo-da-imagem)
- [Início rápido](#início-rápido)
- [Comandos disponíveis](#comandos-disponíveis)
- [Aliases](#aliases)
- [Variáveis de ambiente](#variáveis-de-ambiente)
- [Metadados de SCM / CI (auto-detect)](#metadados-de-scm--ci-auto-detect)
- [Flags de metadata](#flags-de-metadata-cli)
- [`.trivyignore`](#trivyignore)
- [Geração de SBOM](#geração-de-sbom)
- [Failure gate](#failure-gate)
- [Webhook de envio de relatórios](#webhook-de-envio-de-relatórios)
- [Mounts recomendados](#mounts-recomendados)
- [Exemplos práticos](#exemplos-práticos)
- [Pipelines](#pipelines)
- [JSON Schema (ark-report-tools)](#json-schema-ark-report-tools)
- [Validação de relatórios](#validação-de-relatórios)
- [Testes do wrapper](#testes-do-wrapper)
- [Build local](#build-local)
- [Common pitfalls](#common-pitfalls)
- [Licença](#licença)

---

## Recursos

- Scan de **imagem**, **filesystem**, **IaC (config)**, **repositório** e
  lint de **Dockerfile** em uma única CLI (`ark-tools`)
- Relatórios em **JSON, SARIF, TABLE, CycloneDX, SPDX-JSON**
- Geração de **SBOM** (CycloneDX/SPDX) sob demanda
- Inclusão de **inventário completo de pacotes** (`--list-all-pkgs`, opcional)
- Integração opcional com **Trivy Server** + fallback local
- Auto-resolução de **`.trivyignore`** (env, `/.trivyignore`, `$PWD/.trivyignore`)
- **Auto-detect** de variáveis de CI (GitLab, GitHub, Azure, Bitbucket, Jenkins)
- **Envelope padronizado** (`ark-report-tools v1.1`) com metadata de SCM/CI
- Envio de relatórios via **webhook** (1+ URLs)
- **Failure gate** por severidade configurável
- `WORKDIR /workspace` por padrão para evitar scan acidental do container
- **Suite de testes** automatizada para o wrapper (`tests/run-tests.sh`)

---

## Tags da imagem

| Tag                                                 | Descrição       |
| --------------------------------------------------- | --------------- |
| `ghcr.io/tooark/trivy-hadolint:<MAJOR.MINOR.PATCH>` | Versão completa |
| `ghcr.io/tooark/trivy-hadolint:<MAJOR.MINOR>`       | Versão curta    |
| `ghcr.io/tooark/trivy-hadolint:<MAJOR>`             | Major track     |
| `ghcr.io/tooark/trivy-hadolint:latest`              | Última estável  |

---

## Conteúdo da imagem

| Item                 | Descrição                                                      |
| -------------------- | -------------------------------------------------------------- |
| Base                 | `debian:13-slim` (configurável via `BASE_IMAGE`)               |
| Trivy                | `/usr/local/bin/trivy`                                         |
| Hadolint             | `/usr/local/bin/hadolint`                                      |
| Wrapper CLI          | `/usr/local/bin/ark-tools` (entrypoint)                        |
| JSON Schema          | `/usr/local/share/ark-tools/ark-report-tools.schema.v1.1.json` |
| Versões registradas  | `/etc/ark-tools-versions`                                      |
| Runtime deps         | `bash`, `curl`, `jq`, `git`, `ca-certificates`, `gosu`         |
| Usuário padrão       | `app` (não-root)                                               |
| `WORKDIR`            | `/workspace`                                                   |
| Cache Trivy          | `TRIVY_CACHE_DIR=/home/app/.cache/trivy`                       |
| Diretório de reports | `REPORT_DIR=/reports`                                          |

---

## Início rápido

```bash
# Ajuda
docker run --rm ghcr.io/tooark/trivy-hadolint:latest help

# Versões
docker run --rm ghcr.io/tooark/trivy-hadolint:latest version

# Scan de imagem do registry
docker run --rm ghcr.io/tooark/trivy-hadolint:latest image-scan nginx:latest

# Scan de filesystem (repo montado em /workspace)
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/scan-reports":/reports \
  ghcr.io/tooark/trivy-hadolint:latest \
  filesystem-scan
```

---

## Comandos disponíveis

```text
help                                                                       # Ajuda geral
version                                                                    # Versões
image-scan [--sbom[=fmt]|--sbom-format <fmt>] <image> [-- <extras>]        # Scan de imagem
filesystem-scan [--sbom[=fmt]|--sbom-format <fmt>] [path] [-- <extras>]    # Scan de filesystem
config-scan [path] [-- <extras>]                                           # Scan de IaC
repo-scan [path|url] [-- <extras>]                                         # Scan de repositório
dockerfile-lint [Dockerfile] [-- <extras>]                                 # Lint de Dockerfile
container [options] <image> [-- <extras>]                                  # Combinado (image + source + lint)
send-report <file>                                                         # Envio manual via webhook
```

Todos os comandos de scan aceitam também as
[flags de metadata](#flags-de-metadata-cli) (`--branch`, `--commit`, etc.).

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
| `container`       | `ctr`             |
| `send-report`     | `send`            |

---

## Variáveis de ambiente

### Trivy (gerais)

| Variável                    | Default                            | Descrição                                                                                                   |
| --------------------------- | ---------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `TRIVY_SEVERITY`            | `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL` | Severidades **incluídas no relatório**                                                                      |
| `TRIVY_IGNORE_UNFIXED`      | `false`                            | Remove vulnerabilidades sem fix do **relatório**                                                            |
| `TRIVY_SEVERITY_FAIL`       | `HIGH,CRITICAL`                    | Severidades que **disparam o failure gate**                                                                 |
| `TRIVY_IGNORE_UNFIXED_FAIL` | `true`                             | Gate bloqueia apenas em vulnerabilidades que **possuem fix**                                                |
| `TRIVY_EXIT_CODE`           | `1`                                | `0` desativa o gate; `1` falha o pipeline ao detectar issues                                                |
| `TRIVY_FORMAT`              | `json`                             | `json`, `sarif`, `table`, `cyclonedx`, `spdx-json`                                                          |
| `TRIVY_OUTPUT`              | por comando                        | Caminho de saída (para comandos unitários)                                                                  |
| `TRIVY_TIMEOUT`             | `10m`                              | Timeout do scan                                                                                             |
| `TRIVY_SCANNERS`            | padrão do Trivy                    | Ex.: `vuln,secret,misconfig,license`                                                                        |
| `TRIVY_ALL_PACKAGES`        | `true`                             | Inclui inventário completo (`--list-all-pkgs`). Auto-desativa se `TRIVY_FORMAT != json` ou em `config-scan` |
| `TRIVY_IGNOREFILE`          | auto-detect                        | Path explícito de `.trivyignore`                                                                            |

### Trivy Server (opcional)

| Variável                | Default | Descrição                                                  |
| ----------------------- | ------- | ---------------------------------------------------------- |
| `TRIVY_SERVER`          | vazio   | Endpoint do Trivy Server (ex.: `http://trivy-server:4954`) |
| `TRIVY_TOKEN`           | vazio   | Token de autenticação (lido nativamente pelo Trivy)        |
| `TRIVY_SERVER_REQUIRED` | `false` | Se `true`, não tenta fallback local quando server falha    |
| `TRIVY_TOKEN_AS_FLAG`   | `false` | Se `true`, envia token via flag `--token`                  |

### SBOM

| Variável      | Default     | Descrição                               |
| ------------- | ----------- | --------------------------------------- |
| `SBOM_FORMAT` | `cyclonedx` | Formato SBOM (`cyclonedx`, `spdx-json`) |
| `SBOM_OUTPUT` | por comando | Arquivo de saída no modo SBOM           |

### Hadolint

| Variável                 | Default     | Descrição                                    |
| ------------------------ | ----------- | -------------------------------------------- |
| `HADOLINT_CONFIG`        | vazio       | Caminho para `.hadolint.yaml`                |
| `HADOLINT_FORMAT`        | `json`      | Formato de saída: `json`, `tty`, `sarif`     |
| `HADOLINT_FAILURE_LEVEL` | vazio       | Nível mínimo para falha (`warning`, `error`) |
| `HADOLINT_OUTPUT`        | por comando | Arquivo de saída do lint                     |

### Container (comando `container`)

| Variável                | Default               | Descrição                  |
| ----------------------- | --------------------- | -------------------------- |
| `CONTAINER_PATH`        | auto-detect ou `$PWD` | Diretório do projeto       |
| `CONTAINER_DOCKERFILES` | `Dockerfile`          | Lista separada por vírgula |
| `CONTAINER_SCAN_MODE`   | `fs`                  | Opções: `fs` ou `repo`     |
| `CONTAINER_SKIP_IMAGE`  | `false`               | Pula scan de imagem        |
| `CONTAINER_SKIP_LINT`   | `false`               | Pula lint de Dockerfile    |

### Webhook (envio de relatórios)

| Variável                | Default    | Descrição                                   |
| ----------------------- | ---------- | ------------------------------------------- |
| `REPORT_URL`            | vazio      | URLs separadas por vírgula                  |
| `REPORT_TOKEN`          | vazio      | Bearer token                                |
| `REPORT_HEADERS`        | vazio      | Headers extras, um por linha (`Key: Value`) |
| `REPORT_METHOD`         | `POST`     | Método HTTP                                 |
| `REPORT_FAIL_ON_ERROR`  | `false`    | Falha pipeline se algum upload falhar       |
| `REPORT_SEND_EACH_SCAN` | `false`    | Envia após cada scan individual             |
| `REPORT_DIR`            | `/reports` | Diretório dos relatórios                    |

### Webhook SBOM (override por endpoint separado)

| Variável                    | Fallback               |
| --------------------------- | ---------------------- |
| `REPORT_SBOM_URL`           | `REPORT_URL`           |
| `REPORT_SBOM_TOKEN`         | `REPORT_TOKEN`         |
| `REPORT_SBOM_HEADERS`       | `REPORT_HEADERS`       |
| `REPORT_SBOM_METHOD`        | `REPORT_METHOD`        |
| `REPORT_SBOM_FAIL_ON_ERROR` | `REPORT_FAIL_ON_ERROR` |

---

## Metadados de SCM / CI (auto-detect)

A partir do envelope `ark-report-tools v1.1`, todos os relatórios incluem um
objeto `metadata` com informações de **SCM** (controle de versão) e **CI**
(pipeline), úteis para rastreabilidade entre builds, dashboards de segurança
e análises de regressão.

### Estrutura

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

Campos não detectados ficam como `null`.

### Plataformas detectadas

O `ark-tools` identifica automaticamente o ambiente a partir de variáveis
sentinela:

| Plataforma          | Variável detectora       |
| ------------------- | ------------------------ |
| GitLab CI           | `GITLAB_CI`              |
| GitHub Actions      | `GITHUB_ACTIONS`         |
| Azure DevOps        | `TF_BUILD`               |
| Bitbucket Pipelines | `BITBUCKET_BUILD_NUMBER` |
| Jenkins             | `JENKINS_URL`            |

### Mapeamento por plataforma

| Campo        | GitLab CI                      | GitHub Actions                      | Azure DevOps             | Bitbucket                       | Jenkins                    |
| ------------ | ------------------------------ | ----------------------------------- | ------------------------ | ------------------------------- | -------------------------- |
| **branch**   | `CI_COMMIT_REF_NAME`           | `GITHUB_REF_NAME`/`GITHUB_HEAD_REF` | `BUILD_SOURCEBRANCHNAME` | `BITBUCKET_BRANCH`              | `BRANCH_NAME`/`GIT_BRANCH` |
| **commit**   | `CI_COMMIT_SHA`                | `GITHUB_SHA`                        | `BUILD_SOURCEVERSION`    | `BITBUCKET_COMMIT`              | `GIT_COMMIT`               |
| **repo**     | `CI_PROJECT_PATH`              | `GITHUB_REPOSITORY`                 | `BUILD_REPOSITORY_NAME`  | `BITBUCKET_REPO_FULL_NAME`      | `JOB_NAME`                 |
| **tag**      | `CI_COMMIT_TAG`                | —                                   | —                        | `BITBUCKET_TAG`                 | —                          |
| **user**     | `GITLAB_USER_LOGIN`            | `GITHUB_ACTOR`                      | `BUILD_REQUESTEDFOR`     | `BITBUCKET_STEP_TRIGGERER_UUID` | `BUILD_USER_ID`            |
| **pipeline** | `CI_PIPELINE_ID`               | `GITHUB_RUN_ID`                     | `BUILD_BUILDID`          | `BITBUCKET_BUILD_NUMBER`        | `BUILD_NUMBER`             |
| **job**      | `CI_JOB_ID`                    | `GITHUB_JOB`                        | `SYSTEM_JOBID`           | `BITBUCKET_STEP_UUID`           | `JOB_NAME`                 |
| **url**      | `CI_PIPELINE_URL`/`CI_JOB_URL` | calculado de `GITHUB_*`             | `BUILD_BUILDURI`         | —                               | `BUILD_URL`                |

> 💡 Quando o `ark-tools` roda dentro de outro container via `docker run`,
> as variáveis nativas precisam ser repassadas com `-e GITHUB_*`, `-e CI_*` etc.,
> ou via `--env-file`.

### Precedência (mais alta para mais baixa)

1. **Flag CLI** (`--branch`, `--commit`, `--user`, `--repository`, `--tag`)
2. **Env genérica** (`CI_BRANCH`, `CI_COMMIT`, `CI_USER`, `CI_REPOSITORY`, `CI_TAG`)
3. **Env nativa do CI** (auto-detectada conforme tabela acima)
4. **Git** (best-effort, se `.git` estiver acessível)
5. Campo nulo (`null`)

---

## Flags de metadata (CLI)

Aceitas em **todos** os comandos de scan:

```text
--branch <name>      SCM branch
--commit <sha>       SCM commit SHA
--user <name>        CI user / triggerer
--repository <name>  SCM repository (owner/repo)   (alias: --repo)
--tag <name>         SCM tag
```

Exemplo:

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

O wrapper resolve automaticamente o `.trivyignore` na seguinte ordem:

1. `TRIVY_IGNOREFILE` (env explícita)
2. `/.trivyignore` (mount em container)
3. `$PWD/.trivyignore`

Se nenhum existir, o flag `--ignorefile` **não é passado** ao Trivy.

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/.trivyignore":/.trivyignore:ro \
  ghcr.io/tooark/trivy-hadolint:latest \
  filesystem-scan
```

---

## Geração de SBOM

Disponível para `image-scan`, `filesystem-scan` e `container`:

```bash
# CycloneDX (default)
ark-tools image-scan --sbom nginx:latest

# SPDX JSON
ark-tools image-scan --sbom-format spdx-json nginx:latest

# Container scan + SBOM
ark-tools container --sbom myapp:latest --path /workspace
```

> ℹ️ A geração de SBOM é um **scan adicional** (não substitui o scan de
> vulnerabilidades). Se você só precisa do inventário completo de pacotes
> junto com as CVEs, prefira `TRIVY_ALL_PACKAGES=true` (default) — é mais barato.

---

## Failure gate

- O **relatório** sempre é gerado com **todas as severidades** definidas em
  `TRIVY_SEVERITY`, independente do gate. Por padrão (`TRIVY_IGNORE_UNFIXED=false`)
  ele também mantém vulnerabilidades ainda sem fix, dando visão completa aos dashboards.
- Quando `TRIVY_EXIT_CODE=1` (default), o wrapper analisa o JSON e verifica se
  há findings com severidade em `TRIVY_SEVERITY_FAIL`. Se sim, o pipeline falha.
- Por padrão (`TRIVY_IGNORE_UNFIXED_FAIL=true`) o **gate** bloqueia apenas em
  vulnerabilidades que possuem fix disponível; as sem fix permanecem no relatório
  mas não falham o build. Defina como `false` para bloquear também nas sem fix.
- `TRIVY_IGNORE_UNFIXED_FAIL` filtra o relatório que o gate lê, então uma
  vulnerabilidade já excluída por `TRIVY_IGNORE_UNFIXED=true` nunca dispara o gate.
- Quando `TRIVY_FORMAT != json`, o gate é **ignorado** (com aviso).
- O gate analisa `Vulnerabilities`, `Misconfigurations`, `Secrets` e `Licenses`.
  Misconfigurations, secrets e licenses não têm conceito de "fix" e sempre contam
  para o gate.

---

## Webhook de envio de relatórios

Quando `REPORT_URL` está definido, o `ark-tools` envia automaticamente o
envelope `ark-report-tools` via HTTP. Aceita uma ou múltiplas URLs:

```bash
-e REPORT_URL="https://hook1/api,https://hook2/api"
```

O **SBOM** pode ser enviado para um endpoint diferente via `REPORT_SBOM_*`.

Modos de envio:

- **Por scan** (`REPORT_SEND_EACH_SCAN=true`): cada comando individual envia
  seu próprio envelope.
- **Consolidado** (default no `container`): envia o `container-report.json`
  com todos os sub-resultados.

---

## Mounts recomendados

| Mount                                            | Propósito                                                |
| ------------------------------------------------ | -------------------------------------------------------- |
| `-v "$PWD":/workspace:ro`                        | Repositório dentro do container                          |
| `-v "$PWD/.git":/workspace/.git:ro`              | (opcional) Fallback git para metadata SCM                |
| `-v "$PWD/.trivyignore":/.trivyignore:ro`        | `.trivyignore` auto-detectado                            |
| `-v "$HOME/.cache/trivy":/home/app/.cache/trivy` | Cache persistente do Trivy DB                            |
| `-v "$PWD/scan-reports":/reports`                | Persistência dos relatórios localmente                   |
| `-v /var/run/docker.sock:/var/run/docker.sock`   | Scan de **imagens locais** (entrypoint ajusta permissão) |

---

## Exemplos práticos

### Scan de imagem **local** (via docker.sock)

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/tooark/trivy-hadolint:latest \
  image-scan mylocalimage:tag
```

> O `docker-entrypoint.sh` sincroniza automaticamente o GID do socket e executa
> o processo como usuário não-root (`app`).

### Filesystem com cache persistente

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/.git":/workspace/.git:ro \
  -v "$HOME/.cache/trivy":/home/app/.cache/trivy \
  ghcr.io/tooark/trivy-hadolint:latest \
  filesystem-scan
```

### Container scan completo com Trivy Server e webhook

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/scan-reports":/reports \
  -e TRIVY_SERVER=http://trivy-server.internal:4954 \
  -e TRIVY_TOKEN="$TRIVY_TOKEN" \
  -e TRIVY_SERVER_REQUIRED=false \
  -e TRIVY_SEVERITY=CRITICAL,HIGH \
  -e TRIVY_EXIT_CODE=1 \
  -e TRIVY_IGNORE_UNFIXED=false \
  -e TRIVY_IGNORE_UNFIXED_FAIL=true \
  -e HADOLINT_FAILURE_LEVEL=warning \
  -e REPORT_URL=https://example.internal/security/report \
  -e REPORT_TOKEN="$REPORT_TOKEN" \
  -e REPORT_FAIL_ON_ERROR=true \
  ghcr.io/tooark/trivy-hadolint:latest \
  container myapp:latest --path /workspace
```

### Container com múltiplos Dockerfiles

```bash
docker run --rm \
  -v "$PWD":/workspace:ro \
  ghcr.io/tooark/trivy-hadolint:latest \
  container myapp:latest \
  --path /workspace \
  --dockerfiles "Dockerfile,docker/Dockerfile.worker,docker/Dockerfile.nginx"
```

### Passando flags extras para Trivy / Hadolint

Use `--` para encaminhar argumentos:

```bash
# Trivy
ark-tools image-scan myapp:tag -- --ignore-policy /policies/trivy.rego

# Hadolint
ark-tools dockerfile-lint /workspace/Dockerfile -- --ignore DL3008
```

> No comando `container`, flags após `--` são encaminhadas **somente** ao Trivy.

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
            -e TRIVY_IGNORE_UNFIXED_FAIL=true \
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
  TRIVY_IGNORE_UNFIXED: "false"
  TRIVY_IGNORE_UNFIXED_FAIL: "true"
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
    # As variáveis CI_*, GITLAB_USER_LOGIN, etc. são auto-detectadas
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

Todos os relatórios gerados pelo `ark-tools` seguem o envelope
**`ark-report-tools` v1.1**, formalizado em
[`schemas/ark-report-tools.schema.v1.1.json`](schemas/ark-report-tools.schema.v1.1.json).

Dentro da imagem, o schema também está disponível em:

```bash
/usr/local/share/ark-tools/ark-report-tools.schema.v1.1.json
```

Path acessível via `ARK_REPORT_SCHEMA`.

### Estrutura do envelope

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
    /* payload bruto do Trivy/Hadolint */
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

### Campos do envelope

| Campo           | Tipo              | Obrigatório    | Descrição                                                                                             |
| --------------- | ----------------- | -------------- | ----------------------------------------------------------------------------------------------------- |
| `schema`        | string (const)    | sim            | Sempre `"ark-report-tools"`                                                                           |
| `version`       | string            | sim            | Versão do envelope (`"1.1"`)                                                                          |
| `timestamp`     | string (ISO)      | sim            | Momento de geração (UTC)                                                                              |
| `command`       | string (enum)     | sim            | `image-scan` \| `filesystem-scan` \| `config-scan` \| `repo-scan` \| `dockerfile-lint` \| `container` |
| `target`        | string            | sim            | Imagem, path ou URL alvo                                                                              |
| `tool`          | string            | sim            | `trivy`, `hadolint` ou `trivy+hadolint`                                                               |
| `sbom_enabled`  | boolean           | não            | Indica se SBOM foi gerado                                                                             |
| `list_all_pkgs` | boolean           | não            | Indica se inventário completo foi incluído (`--list-all-pkgs`)                                        |
| `metadata`      | object            | não            | `scm{}` + `ci{}` + opcionalmente `scan_context{}`                                                     |
| `report`        | object/array/null | sim            | Payload bruto da ferramenta                                                                           |
| `results`       | object/null       | só `container` | Sub-relatórios consolidados                                                                           |

> O **payload bruto** (`report`) é deixado flexível porque a estrutura do JSON
> do Trivy/Hadolint varia entre versões. O schema garante a estabilidade do
> **envelope**, não do conteúdo interno.

### Sobre `$schema` e `$id`

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:tooark:schemas:ark-report-tools:1.1"
}
```

- **`$schema`** indica o **dialeto do JSON Schema** usado (Draft 2020-12), não
  o caminho do seu schema.
- **`$id`** é o **identificador único** do schema. Como o `tooark.com` é
  estático, o identificador é uma **URN** (não precisa ser uma URL acessível).

### Sobre `allOf`

O `allOf` faz **composição** (AND lógico). No nosso schema, ele é usado para
aplicar uma **regra condicional**: quando `command == "container"`, o campo
`results` torna-se obrigatório.

---

## Validação de relatórios

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
console.log("✅ Report válido");
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
print("✅ Report válido")
```

### Dentro da imagem (sem dependências)

A imagem traz o schema embutido. Você pode consultá-lo:

```bash
docker run --rm \
  --entrypoint cat \
  ghcr.io/tooark/trivy-hadolint:latest \
  /usr/local/share/ark-tools/ark-report-tools.schema.v1.1.json
```

---

## Testes do wrapper

O projeto inclui uma suite de testes automatizada em `tests/run-tests.sh`,
cobrindo as principais funções do `ark-tools.sh` (parsing de flags,
auto-detect de CI, envelope, failure gate, etc.).

### Pré-requisitos

- `bash >= 4`
- `jq`
- `coreutils`

### Executando

```bash
./tests/run-tests.sh

# Modo verboso (mostra diffs em falhas)
VERBOSE=1 ./tests/run-tests.sh
```

Os testes carregam o `ark-tools.sh` em **modo biblioteca** (sem disparar o
dispatcher), através da variável `ARK_TOOLS_LIBRARY_MODE=1`. Isso permite
testar funções unitárias sem efeitos colaterais.

### Cobertura atual

- ✅ `is_true()` — parser de booleanos
- ✅ `should_use_list_all_pkgs()` — regras de ativação
- ✅ `trivy_list_all_pkgs_flag()` — controle por comando (config não recebe)
- ✅ `detect_ci_platform()` — todas as 5 plataformas
- ✅ `_first_nonempty()` — precedência de valores
- ✅ `collect_metadata()` — auto-detect, precedência CLI > env, normalização null
- ✅ `parse_metadata_flags()` — todas as flags + variantes `--flag=value`
- ✅ `resolve_trivy_ignorefile()` — fallback chain
- ✅ `default_fs_target()` — `/workspace` vs `$PWD`
- ✅ `wrap_ark_report()` — envelope completo + default `{}`
- ✅ `trivy_failure_gate()` — relatório limpo/sujo/não-json
- ✅ `_report_file_or_null()` — fallback para arquivo `null.json`

---

## Build local

```bash
version="1.72.0"    # Imagem Trivy + Hadolint
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

- **CVEs estranhas do SO base no relatório** → você esqueceu de montar o repo.
  Use `-v "$PWD":/workspace:ro` ou rode `filesystem-scan /caminho/explicito`.

- **`.trivyignore` não aplicado** → verifique a precedência (`TRIVY_IGNOREFILE` >
  `/.trivyignore` > `$PWD/.trivyignore`). Em container, o mais simples é
  `-v "$PWD/.trivyignore":/.trivyignore:ro`.

- **Relatório JSON enorme** → defina `TRIVY_ALL_PACKAGES=false` se você só
  precisa das CVEs.

- **`metadata.scm.branch` está `null`** → você está fora de um CI conhecido e
  o `.git` não está montado. Use as flags `--branch/--commit/...` ou monte
  `.git` em `/workspace/.git`.

- **GitHub Actions/Docker não auto-detecta** → precisa repassar as variáveis com
  `-e GITHUB_*` no `docker run` (ou usar `--env-file`).

- **Image scan de imagem local falha por permissão** → monte
  `/var/run/docker.sock`; o entrypoint ajusta GID/grupo automaticamente.

---

## Licença

MIT – ver arquivo `LICENSE` na raiz do repositório.
