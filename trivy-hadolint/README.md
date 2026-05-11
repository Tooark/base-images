# trivy-hadolint

Imagem base com Trivy e Hadolint para uso em pipelines de CI/CD.

A imagem inclui um wrapper CLI (`ci-tools`) para padronizar scans de imagem, filesystem, configuração IaC, repositório e lint de Dockerfile, com suporte a:

- Relatórios JSON/SARIF/TABLE
- Geração de SBOM via `image-scan`, `filesystem-scan` e `container`
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
ci-tools help                                                                                        # Exibe ajuda e comandos disponíveis
ci-tools version                                                                                     # Exibe versões do wrapper, Trivy e Hadolint
ci-tools image-scan [--sbom[=format]|--sbom-format <format>] <image> [-- <trivy-extra-flags>]        # Scan de imagem Docker
ci-tools filesystem-scan [--sbom[=format]|--sbom-format <format>] [path] [-- <trivy-extra-flags>]    # Scan de filesystem local
ci-tools config-scan [path] [-- <trivy-extra-flags>]                                                 # Scan de configuração IaC (Terraform, Kubernetes, etc.)
ci-tools repo-scan [path|url] [-- <trivy-extra-flags>]                                               # Scan de repositório
ci-tools dockerfile-lint [Dockerfile] [-- <hadolint-extra-flags>]                                    # Lint de Dockerfile
ci-tools container [options] <image> [-- <trivy-extra-flags>]                                        # Scan combinado: imagem + fonte + lint de Dockerfile
ci-tools send-report [file]                                                                          # Envio de relatório via webhook
```

## Aliases de comandos

| Comando           | Alias       | Alternativo |
| ----------------- | ----------- | ----------- |
| `help`            | `--help`    | `-h`        |
| `version`         | `--version` | `-v`        |
| `image-scan`      | `img-scan`  | `is`        |
| `filesystem-scan` | `fs-scan`   | `fs`        |
| `config-scan`     | `cfg-scan`  | `cs`        |
| `repo-scan`       | `rp-scan`   | `rs`        |
| `dockerfile-lint` | `hadolint`  | `dl`        |
| `container`       | `ctr`       | -           |
| `send-report`     | `send`      | -           |

## Variáveis de ambiente

### Trivy (gerais)

| Variável               | Default                              | Descrição                                                          |
| ---------------------- | ------------------------------------ | ------------------------------------------------------------------ |
| `TRIVY_SEVERITY`       | `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL`   | Severidades para scan de vulnerabilidade                           |
| `TRIVY_SEVERITY_FAIL`  | `HIGH,CRITICAL`                      | Severidades usadas no gate de falha                                |
| `TRIVY_EXIT_CODE`      | `1`                                  | Gate ativa se 1; falha com vulnerabilidades em TRIVY_SEVERITY_FAIL |
| `TRIVY_IGNORE_UNFIXED` | `true`                               | Ignora vulnerabilidades sem fix                                    |
| `TRIVY_FORMAT`         | `json`                               | Formato de saída (`json`, `sarif`, `table`)                        |
| `TRIVY_OUTPUT`         | por comando                          | Caminho do arquivo de saída                                        |
| `TRIVY_TIMEOUT`        | `10m`                                | Timeout do scan                                                    |
| `TRIVY_SCANNERS`       | padrão do Trivy                      | Ex.: `vuln,secret,misconfig`                                       |

### Trivy Server (opcional)

| Variável                | Default | Descrição                                                  |
| ----------------------- | ------- | ---------------------------------------------------------- |
| `TRIVY_SERVER`          | vazio   | Endpoint do Trivy Server (ex.: `http://trivy-server:4954`) |
| `TRIVY_TOKEN`           | vazio   | Token de autenticação (lido nativamente pelo Trivy)        |
| `TRIVY_SERVER_REQUIRED` | `false` | Se `true`, não tenta fallback local quando server falha    |
| `TRIVY_TOKEN_AS_FLAG`   | `false` | Se `true`, envia token como `--token` na linha de comando  |

Notas:

- **Geração de relatório**: O relatório sempre é gerado com todas as severidades definidas em `TRIVY_SEVERITY`, independente de `TRIVY_EXIT_CODE`.
- **Gate de falha**: Quando `TRIVY_EXIT_CODE=1`, o wrapper analisa o relatório JSON e verifica se há vulnerabilidades com severidade em `TRIVY_SEVERITY_FAIL`. Se encontrar, a pipeline falha. Se o formato não for JSON, o gate é ignorado.
- Por padrão, o token deve ser fornecido via variável de ambiente (`TRIVY_TOKEN`) para reduzir exposição em argumentos.
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

### Container (comando `container`)

| Variável               | Default               | Descrição                                               |
| ---------------------- | --------------------- | ------------------------------------------------------- |
| `CONTAINER_PATH`       | auto-detect ou `$PWD` | Diretório do projeto (override de `--path`)             |
| `CONTAINER_DOCKERFILES`| `Dockerfile`          | Lista separada por vírgula de Dockerfiles               |
| `CONTAINER_SCAN_MODE`  | `fs`                  | Modo de scan do código (`fs` ou `repo`)                 |
| `CONTAINER_SKIP_IMAGE` | `false`               | Se `true`, pula o scan de imagem                        |
| `CONTAINER_SKIP_LINT`  | `false`               | Se `true`, pula o lint de Dockerfile                    |

### Webhook (envio de relatório)

| Variável                | Default           | Descrição                                                            |
| ----------------------- | ----------------- | -------------------------------------------------------------------- |
| `REPORT_URL`            | vazio             | Uma ou mais URLs separadas por vírgula (ex: `url1,url2`)             |
| `REPORT_TOKEN`          | vazio             | Token Bearer para o webhook                                          |
| `REPORT_HEADERS`        | vazio             | Headers extras, um por linha (`Key: Value`)                          |
| `REPORT_METHOD`         | `POST`            | Método HTTP                                                          |
| `REPORT_FAIL_ON_ERROR`  | `false`           | Se `true`, falha pipeline quando qualquer upload falha               |
| `REPORT_SEND_EACH_SCAN` | `false`           | Se `true`, envia relatório automaticamente após cada scan individual |
| `REPORT_DIR`            | `/tmp/ci-reports` | Diretório dos relatórios                                             |

### Webhook SBOM (override para endpoint separado)

| Variável                    | Default                          | Descrição                                              |
| --------------------------- | -------------------------------- | ------------------------------------------------------ |
| `REPORT_SBOM_URL`           | fallback em `REPORT_URL`         | Override de URL(s) para envio do SBOM                  |
| `REPORT_SBOM_TOKEN`         | fallback em `REPORT_TOKEN`       | Override de token Bearer para o endpoint SBOM          |
| `REPORT_SBOM_HEADERS`       | fallback em `REPORT_HEADERS`     | Override de headers extras para o endpoint SBOM        |
| `REPORT_SBOM_METHOD`        | fallback em `REPORT_METHOD`      | Override de método HTTP para o endpoint SBOM           |
| `REPORT_SBOM_FAIL_ON_ERROR` | fallback em `REPORT_FAIL_ON_ERROR` | Override de comportamento de falha para SBOM         |

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

### 7) Container scan (imagem + fonte + lint)

```bash
docker run --rm \
  -v "$PWD":/workspace \
  ghcr.io/tooark/trivy-hadolint:latest container myapp:latest --path /workspace
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

### 4) SBOM em container scan

```bash
docker run --rm \
  -v "$PWD":/workspace \
  ghcr.io/tooark/trivy-hadolint:latest \
  container --sbom myapp:latest --path /workspace
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

### 3) container scan completo com webhook

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
  container myapp:latest --path /workspace
```

### 4) container scan com múltiplos Dockerfiles

```bash
docker run --rm \
  -v "$PWD":/workspace \
  ghcr.io/tooark/trivy-hadolint:latest \
  container myapp:latest \
  --path /workspace \
  --dockerfiles "Dockerfile,docker/Dockerfile.worker,docker/Dockerfile.nginx"
```

### 5) container scan pulando imagem (apenas fonte + lint)

```bash
docker run --rm \
  -v "$PWD":/workspace \
  ghcr.io/tooark/trivy-hadolint:latest \
  container --skip-image --path /workspace
```

### 6) Envio para múltiplas URLs

```bash
docker run --rm \
  -v "$PWD":/workspace \
  -e REPORT_URL="https://hook1.internal/report,https://hook2.internal/report" \
  -e REPORT_TOKEN="$REPORT_TOKEN" \
  -e REPORT_FAIL_ON_ERROR=true \
  ghcr.io/tooark/trivy-hadolint:latest \
  container myapp:latest --path /workspace
```

### 7) Envio automático após cada scan individual

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

> **Nota:** No comando `container`, flags passadas após `--` são encaminhadas apenas para o Trivy (não para o Hadolint).

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
      - name: ci-tools version
        run: docker run --rm ghcr.io/tooark/trivy-hadolint:latest version
      - name: image scan
        run: docker run --rm ghcr.io/tooark/trivy-hadolint:latest image-scan nginx:latest
```

### Exemplo avançado (GitHub Actions, container scan + server + webhook + artifacts)

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
      - name: Container scan
        env:
          TRIVY_SERVER: ${{ secrets.TRIVY_SERVER }}
          TRIVY_TOKEN: ${{ secrets.TRIVY_TOKEN }}
          TRIVY_SERVER_REQUIRED: "false"
          TRIVY_SEVERITY: "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
          TRIVY_EXIT_CODE: "1"
          TRIVY_IGNORE_UNFIXED: "true"
          TRIVY_TIMEOUT: "10m"
          HADOLINT_FORMAT: "json"
          HADOLINT_FAILURE_LEVEL: "warning"
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
            -e HADOLINT_FORMAT \
            -e HADOLINT_FAILURE_LEVEL \
            -e REPORT_URL \
            -e REPORT_TOKEN \
            -e REPORT_FAIL_ON_ERROR \
            ghcr.io/tooark/trivy-hadolint:latest \
            container myapp:${{ github.sha }} --path /workspace
      - name: Upload reports
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: security-reports
          path: /tmp/ci-reports/
```

## GitLab CI

### Exemplo básico (GitLab CI)

```yaml
stages:
  - scan

security_scan:
  stage: scan
  image: ghcr.io/tooark/trivy-hadolint:latest
  script:
    - ci-tools version
    - ci-tools image-scan nginx:latest
```

### Exemplo avançado (GitLab CI, container scan + server + webhook + artifacts)

```yaml
stages:
  - scan

variables:
  TRIVY_SERVER_REQUIRED: "false"
  TRIVY_SEVERITY: "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
  TRIVY_EXIT_CODE: "1"
  TRIVY_IGNORE_UNFIXED: "true"
  TRIVY_TIMEOUT: "10m"
  HADOLINT_FAILURE_LEVEL: "warning"
  REPORT_FAIL_ON_ERROR: "true"

security_container_scan:
  stage: scan
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker run --rm
        -v "$CI_PROJECT_DIR:/workspace"
        -e TRIVY_SERVER -e TRIVY_TOKEN -e TRIVY_SERVER_REQUIRED
        -e TRIVY_SEVERITY -e TRIVY_EXIT_CODE -e TRIVY_IGNORE_UNFIXED -e TRIVY_TIMEOUT
        -e HADOLINT_FAILURE_LEVEL
        -e REPORT_URL -e REPORT_TOKEN -e REPORT_FAIL_ON_ERROR
        ghcr.io/tooark/trivy-hadolint:latest
        container myapp:latest --path /workspace
  artifacts:
    when: always
    paths:
      - /tmp/ci-reports/
    expire_in: 7 days
  allow_failure: true
```

## Pipeline realista (Build → Scans → Webhook)

Cenário comum em CI/CD: fazer build da imagem, executar o container scan (imagem + filesystem + lint) e enviar o relatório consolidado para um endpoint de segurança.

### GitHub Actions (cenário realista com build + container scan + webhook)

```yaml
name: Build and Security Scan

on:
  push:
    branches: [main]
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
      image: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4
      - name: Log in to registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}

  security-scan:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
      - name: Container scan
        env:
          TRIVY_SERVER: ${{ secrets.TRIVY_SERVER }}
          TRIVY_TOKEN: ${{ secrets.TRIVY_TOKEN }}
          REPORT_URL: ${{ secrets.SECURITY_REPORT_URL }}
          REPORT_TOKEN: ${{ secrets.REPORT_TOKEN }}
        run: |
          docker run --rm \
            -v "$PWD":/workspace \
            -e TRIVY_SERVER \
            -e TRIVY_TOKEN \
            -e REPORT_URL \
            -e REPORT_TOKEN \
            -e REPORT_FAIL_ON_ERROR=true \
            ghcr.io/tooark/trivy-hadolint:latest \
            container ${{ needs.build.outputs.image }} --path /workspace
      - name: Upload reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: security-reports
          path: /tmp/ci-reports/
```

### GitLab CI (cenário realista com build + container scan + webhook)

```yaml
stages:
  - build
  - scan

variables:
  REGISTRY: registry.gitlab.com
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  TRIVY_TIMEOUT: 10m

build-image:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $IMAGE_TAG .
    - docker push $IMAGE_TAG

security-scan:
  stage: scan
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker run --rm
        -v "$CI_PROJECT_DIR:/workspace"
        -e TRIVY_SERVER -e TRIVY_TOKEN
        -e TRIVY_EXIT_CODE=1 
        -e TRIVY_IGNORE_UNFIXED=true 
        -e TRIVY_TIMEOUT
        -e HADOLINT_FAILURE_LEVEL=warning
        -e REPORT_URL 
        -e REPORT_TOKEN
        -e REPORT_FAIL_ON_ERROR=true
        ghcr.io/tooark/trivy-hadolint:latest
        container $IMAGE_TAG --path /workspace
  artifacts:
    when: always
    paths:
      - /tmp/ci-reports/
    expire_in: 7 days
  allow_failure: true
```

## Dicas operacionais

- Defina `TRIVY_SERVER_REQUIRED=true` em ambientes críticos para evitar fallback silencioso.
- Use `TRIVY_SERVER_REQUIRED=false` em ambientes de desenvolvimento para maior resiliência.
- Evite `TRIVY_TOKEN_AS_FLAG=true` quando possível, para não expor a credencial em argumentos de processo.
- Monte o workspace com `-v` quando precisar escanear arquivos locais.
- Use `REPORT_SEND_EACH_SCAN=true` para receber notificações incrementais durante pipelines longas.
- `REPORT_URL` aceita múltiplas URLs separadas por vírgula; espaços ao redor são ignorados.
- Use `CONTAINER_DOCKERFILES` para especificar múltiplos Dockerfiles (ex: `Dockerfile,docker/Dockerfile.worker`).
- O relatório consolidado do `container` é salvo em `$REPORT_DIR/container-report.json`.

## Gestão do `.trivyignore`

O arquivo `.trivyignore` neste diretório contém CVEs aceitas temporariamente para o scan de segurança da imagem `trivy-hadolint`.

Quando o script `update-versions.py` detecta uma nova versão do Trivy ou do Hadolint, o `.trivyignore` é **automaticamente limpo**, pois as exceções de CVE da versão anterior podem não ser mais válidas.

Como `trivy-hadolint` é uma imagem composta (Trivy + Hadolint), seu `.trivyignore` é **reconstruído por concatenação** dos `.trivyignore` individuais dos componentes base, caso ainda contenham exceções vigentes.

> **Nota:** Não edite manualmente o `.trivyignore` de imagens compostas. Edite apenas os `.trivyignore` das imagens base correspondentes — a concatenação é feita automaticamente pelo script.

## Build local da imagem

```bash
docker build \
  -t trivy-hadolint:local \
  ./trivy-hadolint
```

## Licença

MIT – ver arquivo `LICENSE` na raiz do repositório.
