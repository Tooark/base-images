# dockerx

Imagem base com `docker` (Docker CLI) e `docker buildx`, prontos para uso em
pipelines e execuções ad-hoc em container.

🌍 **Idiomas:** [![USA Flag](https://flagcdn.com/w20/us.png) English](https://github.com/Tooark/base-images/blob/main/dockerx/README.md) · ![Brazil Flag](https://flagcdn.com/w20/br.png) **Português (este arquivo)**

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

- **Docker CLI** e **Docker Buildx** prontos para uso em CI/CD
- Base Debian minimalista com usuário não-root
- Compatível com linux/amd64 e linux/arm64

---

## Tags da imagem

| Tag                                          | Descrição       |
| -------------------------------------------- | --------------- |
| `ghcr.io/tooark/dockerx:<MAJOR.MINOR.PATCH>` | Versão completa |
| `ghcr.io/tooark/dockerx:<MAJOR.MINOR>`       | Versão curta    |
| `ghcr.io/tooark/dockerx:<MAJOR>`             | Major track     |
| `ghcr.io/tooark/dockerx:latest`              | Última estável  |

## Conteúdo da imagem

| Item                  | Descrição                                             |
| --------------------- | ----------------------------------------------------- |
| Base                  | `debian:13-slim`                                      |
| Docker CLI            | `/usr/local/bin/docker`                               |
| Docker Buildx         | `/usr/local/libexec/docker/cli-plugins/docker-buildx` |
| Runtime deps          | `ca-certificates`, `git`, `gosu`                      |
| Usuário padrão        | `app` (não-root)                                      |
| Identificador família | `ARK_IMAGE_FAMILY=dockerx`                            |

---

## Início rápido

Verificar versão do Docker CLI e do Buildx:

```bash
docker run --rm ghcr.io/tooark/dockerx:latest docker --version
docker run --rm ghcr.io/tooark/dockerx:latest docker buildx version
```

Listar builders (com acesso ao socket Docker do host Linux):

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/tooark/dockerx:latest docker buildx ls
```

O `docker-entrypoint.sh` da imagem sincroniza automaticamente o GID do
`/var/run/docker.sock` e executa como usuário não-root (`app`).

Build e push multi-arquitetura com Buildx:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD":/workspace \
  -w /workspace \
  -e DOCKER_BUILDKIT=1 \
  ghcr.io/tooark/dockerx:latest \
  sh -c 'docker buildx create --name ci-builder --driver docker-container --use --bootstrap || docker buildx use ci-builder; docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/org/app:latest --push .'
```

## Pipelines

### GitHub Actions

#### Exemplo básico (GH)

```yaml
name: Docker Buildx

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/dockerx:latest
    steps:
      - uses: actions/checkout@v4

      - name: Show versions
        run: |
          docker --version
          docker buildx version
```

### GitLab CI

#### Exemplo básico (GL)

```yaml
stages:
  - build

build_image:
  stage: build
  image: ghcr.io/tooark/dockerx:latest
  script:
    - docker --version
    - docker buildx version
```

---

## Build local

Ao construir localmente, publique tags equivalentes para a mesma imagem (versão completa, curta e `latest`).

```bash
version="29.1.1"       # DockerX
dockerVersion="29.5.2" # Docker CLI
buildxVersion="0.34.1" # Docker Buildx
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg DOCKERX_VERSION=$version \
  --build-arg DOCKER_VERSION=$dockerVersion \
  --build-arg DOCKER_BUILDX_VERSION=$buildxVersion \
  -t dockerx:$version \
  -t dockerx:$short \
  -t dockerx:latest \
  ./dockerx
```

---

## Documentação oficial

- [Docker CLI](https://docs.docker.com/reference/cli/docker/)
  - [Notas de lançamento](https://docs.docker.com/engine/release-notes/)
- [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/)
  - [Notas de lançamento](https://github.com/docker/buildx/releases/)

---

## Licença

MIT — ver `LICENSE` na raiz do repositório.
