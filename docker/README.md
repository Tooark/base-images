# docker

Esta imagem fornece os comandos `docker` (Docker CLI) e `docker buildx`, prontos para uso em pipelines e execuções ad-hoc em container.

## Nome e tags da imagem

- Nome da imagem: `docker` (nome da pasta)
- Tags publicadas por versão:
  - Versão completa: `docker:<major.minor.patch>`
  - Versão curta (major.minor): `docker:<major.minor>`
  - Versão menor (major): `docker:<major>`
  - Última estável: `docker:latest`

Substitua os números acima pelos valores da sua build.

## O que existe na imagem

| Item           | Descrição                            |
| -------------- | ------------------------------------ |
| Base           | `debian:12-slim` (padrão)            |
| Docker CLI     | Instalado em `/usr/local/bin/docker` |
| Pacotes        | `ca-certificates`, `git`             |
| Usuário padrão | `app` (não-root), HOME: `/home/app`  |

O plugin Buildx fica em `/usr/local/libexec/docker/cli-plugins/docker-buildx`.

Observações:

- O usuário padrão é `app` e o HOME é `/home/app`.
- Não há `bash` na imagem; o shell padrão é `/bin/sh`.
- O `CMD` padrão é `/bin/sh`.
- Variáveis de ambiente úteis: `DOCKER_BUILDKIT=1`, `DOCKER_CLI_HINTS=false`.
- A imagem é compatível com `linux/amd64` e `linux/arm64`.

## Uso rápido

Verificar versão do Docker CLI e do Buildx:

```powershell
docker run --rm ghcr.io/tooark/docker:latest docker --version
docker run --rm ghcr.io/tooark/docker:latest docker buildx version
```

Listar builders (com acesso ao socket Docker do host Linux):

```bash
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$DOCKER_GID" \
  ghcr.io/tooark/docker:latest docker buildx ls
```

Build e push multi-arquitetura com Buildx:

```bash
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$DOCKER_GID" \
  -v "$PWD":/workspace \
  -w /workspace \
  -e DOCKER_BUILDKIT=1 \
  ghcr.io/tooark/docker:latest \
  sh -c 'docker buildx create --name ci-builder --driver docker-container --use --bootstrap || docker buildx use ci-builder; docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/org/app:latest --push .'
```

## Variantes de tag

- `docker:<major>.<minor>.<patch>`: versão exata do Docker CLI (ex.: `28.1.1`).
- `docker:<major>.<minor>`: acompanha a última patch da série (ex.: `28.1`).
- `docker:<major>`: acompanha a última minor da série (ex.: `28`).
- `docker:latest`: aponta para a última versão estável construída.

Para pipelines reprodutíveis, prefira a versão completa.

## Como verificar versões dentro da imagem

```powershell
docker run --rm --entrypoint sh ghcr.io/tooark/docker:latest -c "docker --version; docker buildx version"
```

## Multi-arquitetura

O `Dockerfile` detecta `TARGETARCH` e baixa:

- O binário correto do Docker CLI (distribuição estática oficial)
- O plugin Buildx da arquitetura correspondente

Arquiteturas suportadas:

- `linux/amd64`
- `linux/arm64`

Builds para arquiteturas diferentes falham explicitamente no estágio de build.

## GitHub Actions

### Exemplo básico (GitHub Actions)

```yaml
name: Docker Buildx

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/docker:latest
    steps:
      - uses: actions/checkout@v4

      - name: Show versions
        run: |
          docker --version
          docker buildx version
```

## GitLab CI

### Exemplo básico (GitLab CI)

```yaml
stages:
  - build

build_image:
  stage: build
  image: ghcr.io/tooark/docker:latest
  script:
    - docker --version
    - docker buildx version
```

## Notas de build (opcional)

Ao construir localmente, publique tags equivalentes para a mesma imagem (versão completa, curta e `latest`).

```powershell
$dockerVersion = "28.1.1"
$buildxVersion = "0.26.1"
$short = ($dockerVersion -split '\\.') [0..1] -join '.'

docker build `
  --build-arg DOCKER_VERSION=$dockerVersion `
  --build-arg DOCKER_BUILDX_VERSION=$buildxVersion `
  -t docker:$dockerVersion `
  -t docker:$short `
  -t docker:latest `
  ./docker
```

## Documentação oficial

- [Docker CLI](https://docs.docker.com/engine/reference/commandline/cli/)
  - [Releases do Docker CLI](https://github.com/docker/cli/releases)
- [Docker Buildx](https://docs.docker.com/build/buildx/)
  - [Releases do Buildx](https://github.com/docker/buildx/releases)

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
