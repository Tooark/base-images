# sonar-scanner

Imagem base com `sonar-scanner` (SonarQube Scanner CLI) pronto para uso em pipelines CI/CD com SonarQube, voltada para linguagens como Go, PHP e outras que utilizam o scanner CLI diretamente.

---

## Sumário

- [Recursos](#recursos)
- [Tags da imagem](#tags-da-imagem)
- [Conteúdo da imagem](#conteúdo-da-imagem)
- [Início rápido](#início-rápido)
- [Pipelines](#pipelines)
- [Build local](#build-local)
- [Documentação oficial](#documentação-oficial)
- [Licença](#licença)

---

## Recursos

- **Sonar Scanner CLI** pronto para uso em CI/CD
- Base Debian minimalista com usuário não-root
- Compatível com linux/amd64 e linux/arm64

---

## Tags da imagem

| Tag                                                | Descrição       |
| -------------------------------------------------- | --------------- |
| `ghcr.io/tooark/sonar-scanner:<MAJOR.MINOR.PATCH>` | Versão completa |
| `ghcr.io/tooark/sonar-scanner:<MAJOR.MINOR>`       | Versão curta    |
| `ghcr.io/tooark/sonar-scanner:<MAJOR>`             | Major track     |
| `ghcr.io/tooark/sonar-scanner:latest`              | Última estável  |

---

## Conteúdo da imagem

| Item                  | Descrição                                                   |
| --------------------- | ----------------------------------------------------------- |
| Base                  | `debian:12-slim`                                            |
| Sonar Scanner CLI     | `/opt/sonar-scanner`                                        |
| Runtime deps          | `ca-certificates`, `bash`, `git`, `openjdk-17-jre-headless` |
| Usuário padrão        | `app` (não-root)                                            |
| Identificador família | `ARK_IMAGE_FAMILY=sonar-scanner`                            |

---

## Início rápido

Verificar versão do scanner:

```bash
docker run --rm ghcr.io/tooark/sonar-scanner:latest sonar-scanner --version
```

Executar scan em um projeto (montando o diretório de trabalho):

```bash
docker run --rm \
  -e SONAR_HOST_URL="https://sonarqube.exemplo.com" \
  -e SONAR_TOKEN="seu-token" \
  -v $(pwd):/usr/src \
  -w /usr/src \
  ghcr.io/tooark/sonar-scanner:latest \
  sonar-scanner -Dsonar.projectKey="meu-projeto"
```

---

## Variáveis de ambiente

### SONAR SCANNER CLI

| Variável         | Default | Descrição                          |
| ---------------- | ------- | ---------------------------------- |
| `SONAR_HOST_URL` | -       | URL do servidor SonarQube          |
| `SONAR_TOKEN`    | -       | Token de autenticação do SonarQube |

---

## Pipelines

### GitHub Actions

#### Exemplo básico (GH)

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

      - name: Executar análise SonarQube
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

#### Exemplo básico (GL)

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

Configure no GitLab (Settings > CI/CD > Variables):

- `SONAR_HOST_URL`
- `SONAR_TOKEN`
- `SONAR_PROJECT_KEY`
- `SONAR_PROJECT_NAME`

---

## Build local

Ao construir localmente, publique tags equivalentes para a mesma imagem (versão completa, curta e `latest`).

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

## Documentação oficial

- [SonarScanner CLI](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/scanners/sonarscanner)
  - [Notas de lançamento](https://github.com/SonarSource/sonar-scanner-cli/releases)

---

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
