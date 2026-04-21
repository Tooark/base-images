# trivy-hadolint

Imagem base com Trivy e Hadolint para uso em pipelines de CI/CD.

A imagem inclui um wrapper CLI (`ci-tools`) para padronizar scans de imagem, filesystem, configuração IaC, repositório e lint de Dockerfile, com suporte a:

- Relatórios JSON/SARIF/TABLE
- Geração de SBOM via `image-scan` e `filesystem-scan`
- Integração opcional com Trivy Server
- Fallback local controlado por variável
- Envio de relatório por webhook (uma ou múltiplas URLs)
- Envio automático após cada scan individual (opcional)

## Nome e tags da imagem

- Nome: `trivy-hadolint`
- Tags sugeridas por release:
  - Versão completa: `trivy-hadolint:<major.minor.patch>`
  - Versão curta: `trivy-hadolint:<major.minor>`
  - Versão menor: `trivy-hadolint:<major>`
  - Última estável: `trivy-hadolint:latest`

## O que existe na imagem

| Item           | Descrição                                           |
| -------------- | --------------------------------------------------- |
| Base           | `debian:12-slim` (padrão)                           |
| Trivy          | Instalado como binário em `/usr/local/bin/trivy`    |
| Hadolint       | Instalado como binário em `/usr/local/bin/hadolint` |
| Wrapper        | `/usr/local/bin/ci-tools`                           |
| Runtime deps   | `bash`, `curl`, `jq`, `git`, `ca-certificates`      |
| Usuário padrão | `app` (não-root)                                    |
| Cache Trivy    | `TRIVY_CACHE_DIR=/home/app/.cache/trivy`            |

## Comandos disponíveis

```text
ci-tools help                                                                                     # Exibe ajuda e comandos disponíveis
ci-tools version                                                                                  # Exibe versões do wrapper, Trivy e Hadolint
ci-tools image-scan [--sbom[=format]|--sbom-format <format>] <image> [-- <trivy-extra-flags>]     # Scan de imagem Docker
ci-tools filesystem-scan [--sbom[=format]|--sbom-format <format>] [path] [-- <trivy-extra-flags>] # Scan de filesystem local
ci-tools config-scan [path] [-- <trivy-extra-flags>]                                              # Scan de configuração IaC (Terraform, Kubernetes, etc.)
ci-tools repo-scan [path|url] [-- <trivy-extra-flags>]                                            # Scan de repositório
ci-tools dockerfile-lint [Dockerfile] [-- <hadolint-extra-flags>]                                 # Lint de Dockerfile
ci-tools full-scan <image> [path] [-- <extra-flags>]                                              # Scan completo (imagem + filesystem + configuração)
ci-tools send-report [file]                                                                       # Envio de relatório
```

## Aliases de comandos

| Comando           | Alias       | Alternativo |
| ----------------- | ----------- | ----------- |
| `help`            | `--help`    | `-h`        |
| `version`         | `--version` | `-v`        |
| `image-scan`      | `img-scan`  | `is`        |
| `filesystem-scan` | `fs-scan`,  | `fs`        |
| `config-scan`     | `cfg-scan`  | `cs`        |
| `repo-scan`       | `rp-scan`,  | `rs`        |
| `dockerfile-lint` | `hadolint`  | `dl`        |
| `full-scan`       | `full`      | -           |
| `send-report`     | `send`      | -           |

## Variáveis de ambiente

### Trivy (gerais)

| Variável               | Default         | Descrição                                   |
| ---------------------- | --------------- | ------------------------------------------- |
| `TRIVY_SEVERITY`       | `CRITICAL,HIGH` | Severidades para scan de vulnerabilidade    |
| `TRIVY_EXIT_CODE`      | `1`             | Exit code usado quando há achados           |
| `TRIVY_IGNORE_UNFIXED` | `true`          | Ignora vulnerabilidades sem fix             |
| `TRIVY_FORMAT`         | `json`          | Formato de saída (`json`, `sarif`, `table`) |
| `TRIVY_OUTPUT`         | por comando     | Caminho do arquivo de saída                 |
| `TRIVY_TIMEOUT`        | padrão do Trivy | Timeout do scan                             |
| `TRIVY_SCANNERS`       | padrão do Trivy | Ex.: `vuln,secret,misconfig`                |

### Trivy Server (opcional)

| Variável                | Default | Descrição                                                  |
| ----------------------- | ------- | ---------------------------------------------------------- |
| `TRIVY_SERVER`          | vazio   | Endpoint do Trivy Server (ex.: `http://trivy-server:4954`) |
| `TRIVY_TOKEN`           | vazio   | Token de autenticação                                      |
| `TRIVY_SERVER_REQUIRED` | `false` | Se `true`, não tenta fallback local quando server falha    |
| `TRIVY_TOKEN_AS_FLAG`   | `false` | Se `true`, envia token como `--token`                      |

Notas:

- Por padrão, o token deve ser fornecido via ambiente (`TRIVY_TOKEN`) para reduzir exposição em argumentos.
- Com `TRIVY_SERVER_REQUIRED=false`, o wrapper tenta fallback local se o scan via server falhar e não houver relatório gerado.

### SBOM

| Variável      | Default     | Descrição                               |
| ------------- | ----------- | --------------------------------------- |
| `SBOM_FORMAT` | `cyclonedx` | Formato SBOM (`cyclonedx`, `spdx-json`) |
| `SBOM_OUTPUT` | por comando | Arquivo de saída no modo SBOM           |

### Hadolint

| Variável                 | Default     | Descrição                                    |
| ------------------------ | ----------- | -------------------------------------------- |
| `HADOLINT_CONFIG`        | vazio       | Caminho para `.hadolint.yaml`                |
| `HADOLINT_FORMAT`        | `json`      | Formato de saída (`json`, `tty`, `sarif`)    |
| `HADOLINT_FAILURE_LEVEL` | vazio       | Nível mínimo para falha (`warning`, `error`) |
| `HADOLINT_OUTPUT`        | por comando | Arquivo de saída do lint                     |

### Webhook (envio de relatório)

| Variável                | Default           | Descrição                                                         |
| ----------------------- | ----------------- | ----------------------------------------------------------------- |
| `REPORT_URL`            | vazio             | Uma ou mais URLs separadas por vírgula (ex: `url1,url2`)          |
| `REPORT_TOKEN`          | vazio             | Token Bearer para o webhook                                       |
| `REPORT_HEADERS`        | vazio             | Headers extras, um por linha (`Key: Value`)                       |
| `REPORT_METHOD`         | `POST`            | Método HTTP                                                       |
| `REPORT_FAIL_ON_ERROR`  | `false`           | Se `true`, falha pipeline quando qualquer upload falha            |
| `REPORT_SEND_EACH_SCAN` | `false`           | Se `true`, envia relatório automaticamente após cada scan         |
| `REPORT_DIR`            | `/tmp/ci-reports` | Diretório dos relatórios                                          |

## Exemplos básicos

### 1) Ver ajuda e versões

```bash
docker run --rm ghcr.io/tooark/trivy-hadolint:latest help
docker run --rm ghcr.io/tooark/trivy-hadolint:latest version
```

### 2) Scan de imagem

```bash
docker run --rm ghcr.io/tooark/trivy-hadolint:latest image-scan nginx:latest
```

### 3) Scan de filesystem local

```bash
docker run --rm \
  -v "$PWD":/workspace \
  ghcr.io/tooark/trivy-hadolint:latest filesystem-scan /workspace
```

### 4) Scan de configuração IaC

```bash
docker run --rm \
  -v "$PWD":/workspace \
  ghcr.io/tooark/trivy-hadolint:latest config-scan /workspace
```

### 5) Scan de repositório remoto

```bash
docker run --rm ghcr.io/tooark/trivy-hadolint:latest repo-scan https://github.com/aquasecurity/trivy
```

### 6) Lint de Dockerfile

```bash
docker run --rm \
  -v "$PWD":/workspace \
  ghcr.io/tooark/trivy-hadolint:latest dockerfile-lint /workspace/Dockerfile
```

### 7) Full scan

```bash
docker run --rm \
  -v "$PWD":/workspace \
  ghcr.io/tooark/trivy-hadolint:latest full-scan myapp:latest /workspace
```

## Exemplos SBOM

### 1) SBOM em image-scan (CycloneDX)

```bash
docker run --rm \
  ghcr.io/tooark/trivy-hadolint:latest \
  image-scan --sbom nginx:latest
```

### 2) SBOM em image-scan (SPDX JSON)

```bash
docker run --rm \
  ghcr.io/tooark/trivy-hadolint:latest \
  image-scan --sbom-format spdx-json nginx:latest
```

### 3) SBOM em filesystem-scan com saída customizada

```bash
docker run --rm \
  -v "$PWD":/workspace \
  -e SBOM_OUTPUT=/tmp/ci-reports/fs-sbom.json \
  ghcr.io/tooark/trivy-hadolint:latest \
  filesystem-scan --sbom /workspace
```

## Exemplos com todas as configurações relevantes

### 1) image-scan com Trivy Server, token, scanners customizados e timeout

```bash
docker run --rm \
  -e TRIVY_SERVER=http://trivy-server.internal:4954 \
  -e TRIVY_TOKEN="$TRIVY_TOKEN" \
  -e TRIVY_TOKEN_AS_FLAG=false \
  -e TRIVY_SERVER_REQUIRED=true \
  -e TRIVY_SEVERITY=CRITICAL,HIGH,MEDIUM \
  -e TRIVY_SCANNERS=vuln,secret,misconfig \
  -e TRIVY_IGNORE_UNFIXED=true \
  -e TRIVY_TIMEOUT=10m \
  -e TRIVY_FORMAT=json \
  -e TRIVY_OUTPUT=/tmp/ci-reports/trivy-image-custom.json \
  -e REPORT_DIR=/tmp/ci-reports \
  ghcr.io/tooark/trivy-hadolint:latest \
  image-scan myapp:latest
```

### 2) filesystem-scan com fallback habilitado e SBOM SPDX

```bash
docker run --rm \
  -v "$PWD":/workspace \
  -e TRIVY_SERVER=http://trivy-server.internal:4954 \
  -e TRIVY_TOKEN="$TRIVY_TOKEN" \
  -e TRIVY_SERVER_REQUIRED=false \
  -e SBOM_FORMAT=spdx-json \
  -e SBOM_OUTPUT=/tmp/ci-reports/fs.spdx.json \
  ghcr.io/tooark/trivy-hadolint:latest \
  filesystem-scan --sbom /workspace
```

### 3) full-scan completo com webhook

```bash
docker run --rm \
  -v "$PWD":/workspace \
  -e TRIVY_SERVER=http://trivy-server.internal:4954 \
  -e TRIVY_TOKEN="$TRIVY_TOKEN" \
  -e TRIVY_SERVER_REQUIRED=false \
  -e TRIVY_SEVERITY=CRITICAL,HIGH \
  -e TRIVY_EXIT_CODE=1 \
  -e TRIVY_IGNORE_UNFIXED=true \
  -e TRIVY_TIMEOUT=5m \
  -e HADOLINT_FORMAT=json \
  -e HADOLINT_FAILURE_LEVEL=warning \
  -e REPORT_DIR=/tmp/ci-reports \
  -e REPORT_URL=https://example.internal/security/report \
  -e REPORT_TOKEN="$REPORT_TOKEN" \
  -e REPORT_METHOD=POST \
  -e REPORT_FAIL_ON_ERROR=true \
  ghcr.io/tooark/trivy-hadolint:latest \
  full-scan myapp:latest /workspace
```

### 4) Envio para múltiplas URLs

```bash
docker run --rm \
  -v "$PWD":/workspace \
  -e REPORT_URL="https://hook1.internal/report,https://hook2.internal/report" \
  -e REPORT_TOKEN="$REPORT_TOKEN" \
  -e REPORT_FAIL_ON_ERROR=true \
  ghcr.io/tooark/trivy-hadolint:latest \
  full-scan myapp:latest /workspace
```

### 5) Envio automático após cada scan individual

```bash
docker run --rm \
  -v "$PWD":/workspace \
  -e REPORT_URL=https://example.internal/security/report \
  -e REPORT_TOKEN="$REPORT_TOKEN" \
  -e REPORT_SEND_EACH_SCAN=true \
  ghcr.io/tooark/trivy-hadolint:latest \
  image-scan myapp:latest
```

## Passando flags extras para Trivy e Hadolint

Use `--` para encaminhar argumentos extras ao comando subjacente.

### Exemplo Trivy

```bash
docker run --rm \
  ghcr.io/tooark/trivy-hadolint:latest \
  image-scan myapp:latest -- --ignore-policy /policies/trivy.rego
```

### Exemplo Hadolint

```bash
docker run --rm \
  -v "$PWD":/workspace \
  ghcr.io/tooark/trivy-hadolint:latest \
  dockerfile-lint /workspace/Dockerfile -- --ignore DL3008
```

## GitHub Actions

### Exemplo básico (GitHub Actions)

```yaml
name: Security Scan

on:
  push:
  pull_request:

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Image scan
        run: |
          docker run --rm \
            ghcr.io/tooark/trivy-hadolint:latest \
            image-scan myapp:${{ github.sha }}
```

### Exemplo avançado (GitHub Actions, full-scan + server + webhook + artifacts)

```yaml
name: Security Full Scan

on:
  push:
  pull_request:

jobs:
  full-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run full scan
        env:
          TRIVY_SERVER: ${{ secrets.TRIVY_SERVER }}
          TRIVY_TOKEN: ${{ secrets.TRIVY_TOKEN }}
          TRIVY_SERVER_REQUIRED: "false"
          TRIVY_SEVERITY: CRITICAL,HIGH
          TRIVY_EXIT_CODE: "1"
          TRIVY_IGNORE_UNFIXED: "true"
          TRIVY_TIMEOUT: 10m
          REPORT_URL: ${{ secrets.REPORT_URL }}
          REPORT_TOKEN: ${{ secrets.REPORT_TOKEN }}
          REPORT_FAIL_ON_ERROR: "true"
        run: |
          docker run --rm \
            -v "${{ github.workspace }}:/workspace" \
            -e TRIVY_SERVER \
            -e TRIVY_TOKEN \
            -e TRIVY_SERVER_REQUIRED \
            -e TRIVY_SEVERITY \
            -e TRIVY_EXIT_CODE \
            -e TRIVY_IGNORE_UNFIXED \
            -e TRIVY_TIMEOUT \
            -e REPORT_URL \
            -e REPORT_TOKEN \
            -e REPORT_FAIL_ON_ERROR \
            ghcr.io/tooark/trivy-hadolint:latest \
            full-scan myapp:${{ github.sha }} /workspace

      - name: Upload reports
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: security-reports
          path: |
            /tmp/ci-reports
```

## GitLab CI

### Exemplo básico (GitLab CI)

```yaml
stages:
  - scan

image_scan:
  stage: scan
  image: ghcr.io/tooark/trivy-hadolint:latest
  script:
    - ci-tools image-scan $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
```

### Exemplo avançado (GitLab CI, full-scan + server + webhook + artifacts)

```yaml
stages:
  - scan

variables:
  TRIVY_SERVER_REQUIRED: "false"
  TRIVY_SEVERITY: "CRITICAL,HIGH"
  TRIVY_EXIT_CODE: "1"
  TRIVY_IGNORE_UNFIXED: "true"
  TRIVY_TIMEOUT: "10m"
  REPORT_FAIL_ON_ERROR: "true"

security_full_scan:
  stage: scan
  image: ghcr.io/tooark/trivy-hadolint:latest
  script:
    - ci-tools full-scan "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA" "$CI_PROJECT_DIR"
  variables:
    TRIVY_SERVER: $TRIVY_SERVER
    TRIVY_TOKEN: $TRIVY_TOKEN
    REPORT_URL: $REPORT_URL
    REPORT_TOKEN: $REPORT_TOKEN
  artifacts:
    when: always
    paths:
      - /tmp/ci-reports/
```

## Pipeline realista (Build → Scans → Webhook)

Cenário comum em CI/CD: fazer build da imagem, scanear a imagem buildada, scanear os arquivos do repositório, lint de Dockerfile e enviar todos os relatórios para um endpoint de segurança.

### GitHub Actions (cenário realista com build + scans + webhook)

```yaml
name: Build and Security Scan

on:
  push:
    branches: [main, develop]
  pull_request:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}

  security-scan:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4

      - name: Run full security scan
        env:
          IMAGE_TAG: ${{ needs.build.outputs.image_tag }}
          TRIVY_SEVERITY: CRITICAL,HIGH
          TRIVY_EXIT_CODE: "1"
          TRIVY_IGNORE_UNFIXED: "true"
          TRIVY_TIMEOUT: 10m
        run: |
          docker run --rm \
            -v "${{ github.workspace }}:/workspace" \
            -e TRIVY_SEVERITY \
            -e TRIVY_EXIT_CODE \
            -e TRIVY_IGNORE_UNFIXED \
            -e TRIVY_TIMEOUT \
            ghcr.io/tooark/trivy-hadolint:latest \
            full-scan "${{ needs.build.outputs.image_tag }}" /workspace

      - name: Send security report via webhook
        if: always()
        env:
          REPORT_URL: ${{ secrets.SECURITY_REPORT_URL }}
          REPORT_TOKEN: ${{ secrets.SECURITY_REPORT_TOKEN }}
        run: |
          docker run --rm \
            -v /tmp/ci-reports:/reports \
            -e REPORT_URL \
            -e REPORT_TOKEN \
            ghcr.io/tooark/trivy-hadolint:latest \
            send-report /reports/full-report.json

      - name: Upload security reports
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: security-scan-reports
          path: /tmp/ci-reports/
          retention-days: 30
```

### GitLab CI (cenário realista com build + scans + webhook)

```yaml
stages:
  - build
  - scan
  - report

variables:
  REGISTRY: registry.gitlab.com
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  TRIVY_SEVERITY: CRITICAL,HIGH
  TRIVY_EXIT_CODE: "1"
  TRIVY_IGNORE_UNFIXED: "true"
  TRIVY_TIMEOUT: 10m

build-image:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker build -t $IMAGE_TAG .
    - docker push $IMAGE_TAG
  only:
    - main
    - develop
    - merge_requests

security-scan:
  stage: scan
  image: ghcr.io/tooark/trivy-hadolint:latest
  script:
    - ci-tools image-scan $IMAGE_TAG
    - ci-tools filesystem-scan $CI_PROJECT_DIR
    - ci-tools dockerfile-lint $CI_PROJECT_DIR/Dockerfile
  artifacts:
    when: always
    paths:
      - /tmp/ci-reports/
    expire_in: 30 days
  allow_failure: true

send-security-report:
  stage: report
  image: ghcr.io/tooark/trivy-hadolint:latest
  script:
    - ci-tools send-report /tmp/ci-reports/full-report.json
  variables:
    REPORT_URL: $SECURITY_REPORT_URL
    REPORT_TOKEN: $SECURITY_REPORT_TOKEN
    REPORT_FAIL_ON_ERROR: "true"
  dependencies:
    - security-scan
  when: always
  allow_failure: true
  only:
    - main
    - develop
```

## Dicas operacionais

- Defina `TRIVY_SERVER_REQUIRED=true` em ambientes críticos para evitar fallback silencioso.
- Use `TRIVY_SERVER_REQUIRED=false` em ambientes de desenvolvimento para maior resiliência.
- Evite `TRIVY_TOKEN_AS_FLAG=true` quando possível, para não expor credencial em argumentos de processo.
- Monte o workspace com `-v` quando precisar escanear arquivos locais.
- Use `REPORT_SEND_EACH_SCAN=true` para receber notificações incrementais durante pipelines longas.
- `REPORT_URL` aceita múltiplas URLs separadas por vírgula; espaços ao redor são ignorados.

## Build local da imagem

```bash
docker build \
  -t trivy-hadolint:local \
  --build-arg TRIVY_VERSION=0.67.2 \
  --build-arg HADOLINT_VERSION=2.14.0 \
  --build-arg TRIVY_HADOLINT_VERSION=2.0.0 \
  ./trivy-hadolint
```

## Licença

MIT – ver arquivo `LICENSE` na raiz do repositório.
