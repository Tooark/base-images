# aws-cli

Imagem base com `aws` (AWS CLI v2), `kubectl`, `docker` e `docker buildx`,
prontos para uso em pipelines e execuções ad-hoc em container.

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

- **AWS CLI v2**, **kubectl**, **Docker CLI** e **Docker Buildx** na mesma imagem
- Base Debian minimalista com usuário não-root
- Compatível com linux/amd64 e linux/arm64

---

## Tags da imagem

| Tag                                          | Descrição       |
| -------------------------------------------- | --------------- |
| `ghcr.io/tooark/aws-cli:<MAJOR.MINOR.PATCH>` | Versão completa |
| `ghcr.io/tooark/aws-cli:<MAJOR.MINOR>`       | Versão curta    |
| `ghcr.io/tooark/aws-cli:<MAJOR>`             | Major track     |
| `ghcr.io/tooark/aws-cli:latest`              | Última estável  |

---

## Conteúdo da imagem

| Item                  | Descrição                                                       |
| --------------------- | --------------------------------------------------------------- |
| Base                  | `debian:12-slim`                                                |
| AWS CLI v2            | `/usr/local/aws-cli/v2/current/bin/aws`                         |
| kubectl               | `/usr/local/bin/kubectl`                                        |
| Docker CLI            | `/usr/local/bin/docker`                                         |
| Docker Buildx         | `/usr/local/libexec/docker/cli-plugins/docker-buildx`           |
| Symlink               | `/usr/local/bin/aws` -> `/usr/local/aws-cli/v2/current/bin/aws` |
| Runtime deps          | `ca-certificates`                                               |
| Usuário padrão        | `app` (não-root)                                                |
| Identificador família | `ARK_IMAGE_FAMILY=aws-cli`                                      |

---

## Início rápido

Executar `aws --version`:

```bash
docker run --rm ghcr.io/tooark/aws-cli:latest aws --version
```

Executar um subcomando do AWS CLI (ex.: `sts get-caller-identity`).

```bash
docker run --rm ghcr.io/tooark/aws-cli:latest aws sts get-caller-identity --no-cli-pager
```

Ver versão do kubectl (cliente):

```bash
docker run --rm ghcr.io/tooark/aws-cli:latest kubectl version --client
```

Usar `kubectl get` com kubeconfig montado (exemplo):

```bash
docker run --rm \
  -v "$HOME/.kube/config:/home/app/.kube/config:ro" \
  ghcr.io/tooark/aws-cli:latest kubectl get nodes --request-timeout=10s
```

Ver versão do Docker CLI:

```bash
docker run --rm ghcr.io/tooark/aws-cli:latest docker --version
```

Ver versão do Docker Buildx:

```bash
docker run --rm ghcr.io/tooark/aws-cli:latest docker buildx version
```

### Passando credenciais ao container

Por variáveis de ambiente:

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID=$env:AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$env:AWS_SECRET_ACCESS_KEY \
  -e AWS_SESSION_TOKEN=$env:AWS_SESSION_TOKEN \
  -e AWS_REGION=us-east-1 \
  ghcr.io/tooark/aws-cli:latest aws sts get-caller-identity --no-cli-pager
```

Montando o diretório de credenciais do host (`~/.aws`):

```bash
# A imagem usa usuário não-root 'app'; monte em /home/app/.aws
docker run --rm \
  -v "$HOME/.aws:/home/app/.aws:ro \
  ghcr.io/tooark/aws-cli:latest aws sts get-caller-identity --no-cli-pager
```

Para usar `kubectl`, você também pode montar um kubeconfig em `/home/app/.kube/config`.

---

## Variáveis de ambiente

### AWS CLI

| Variável                | Default     | Descrição              |
| ----------------------- | ----------- | ---------------------- |
| `AWS_ACCESS_KEY_ID`     | -           | Chave de acesso da AWS |
| `AWS_SECRET_ACCESS_KEY` | -           | Chave secreta da AWS   |
| `AWS_SESSION_TOKEN`     | -           | Token de sessão da AWS |
| `AWS_REGION`            | `us-east-1` | Região padrão da AWS   |

---

## Pipelines

### GitHub Actions

#### Exemplo básico (GH)

```yaml
name: Deploy AWS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/aws-cli:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_REGION: us-east-1
    steps:
      - uses: actions/checkout@v4

      - name: Verificar identidade
        run: aws sts get-caller-identity --no-cli-pager

      - name: Deploy para S3
        run: aws s3 sync ./dist s3://${{ vars.BUCKET_NAME }} --delete
```

#### Exemplo com kubectl (EKS) (GH)

```yaml
name: Deploy EKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/aws-cli:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_REGION: us-east-1
    steps:
      - uses: actions/checkout@v4

      - name: Configurar kubeconfig via EKS
        run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER }} --no-cli-pager

      - name: Aplicar manifests
        run: kubectl apply -f k8s/

      - name: Verificar rollout
        run: kubectl rollout status deployment/${{ vars.APP_NAME }} --timeout=120s
```

### GitLab CI

#### Exemplo básico (GL)

```yaml
stages:
  - deploy

deploy_s3:
  stage: deploy
  image: ghcr.io/tooark/aws-cli:latest
  variables:
    AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
    AWS_REGION: us-east-1
  script:
    - aws sts get-caller-identity --no-cli-pager
    - aws s3 sync ./dist s3://$BUCKET_NAME --delete
  only:
    - main
```

#### Exemplo com kubectl (EKS) (GL)

```yaml
stages:
  - deploy

deploy_eks:
  stage: deploy
  image: ghcr.io/tooark/aws-cli:latest
  variables:
    AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
    AWS_REGION: us-east-1
  script:
    - aws eks update-kubeconfig --name $EKS_CLUSTER --no-cli-pager
    - kubectl apply -f k8s/
    - kubectl rollout status deployment/$APP_NAME --timeout=120s
  only:
    - main
```

---

## Build local

```bash
version="2.32.3"   # AWS CLI
kubectl="1.34.2"   # kubectl
docker="28.1.1"    # Docker CLI
buildx="0.26.1"    # Buildx
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg AWSCLI_VERSION=$version \
  --build-arg KUBECTL_VERSION=$kubectl \
  --build-arg DOCKER_VERSION=$docker \
  --build-arg DOCKER_BUILDX_VERSION=$buildx \
  -t aws-cli:$version \
  -t aws-cli:$short \
  -t aws-cli:latest \
  ./aws-cli
```

---

## Documentação oficial

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [Notas de lançamento](https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Notas de lançamento](https://kubernetes.io/releases/)
- [Docker CLI](https://docs.docker.com/reference/cli/docker/)
  - [Notas de lançamento](https://docs.docker.com/engine/release-notes/)
- [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/)
  - [Notas de lançamento](https://github.com/docker/buildx/releases/)

---

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
