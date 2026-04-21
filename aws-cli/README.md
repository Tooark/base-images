# aws-cli

Esta imagem fornece os comandos `aws` (AWS CLI v2) e `kubectl`, prontos para uso em pipelines e execuções ad-hoc em container.

## Nome e tags da imagem

- Nome da imagem: `aws-cli` (nome da pasta)
- Tags publicadas por versão:
  - Versão completa: `aws-cli:<major.minor.patch>`
  - Versão curta (major.minor): `aws-cli:<major.minor>`
  - Versão menor (major): `aws-cli:<major>`
  - Última estável: `aws-cli:latest`

Substitua os números acima pelos valores da sua build.

## O que existe na imagem

| Item           | Descrição                                                       |
| -------------- | --------------------------------------------------------------- |
| Base           | `debian:12-slim` (padrão)                                       |
| AWS CLI v2     | Instalado em `/usr/local/aws-cli/v2/current/bin/aws`            |
| kubectl        | Instalado em `/usr/local/bin/kubectl`                           |
| Symlink        | `/usr/local/bin/aws` -> `/usr/local/aws-cli/v2/current/bin/aws` |
| Binários       | `aws`, `kubectl` disponíveis em `/usr/local/bin`                |
| Pacotes        | `ca-certificates` instalado para conexões HTTPS seguras         |
| Usuário padrão | `app` (não-root)                                                |

Observações:

- O usuário padrão é `app` e o HOME é `/home/app`.
- Não há `bash` na imagem; o shell padrão é `/bin/sh`.
- O `CMD` padrão é `/bin/sh`.
- A imagem é compatível com `linux/amd64` e `linux/arm64`.

## Uso rápido

Executar `aws --version`:

```powershell
docker run --rm ghcr.io/tooark/aws-cli:latest aws --version
```

Executar um subcomando do AWS CLI (ex.: `sts get-caller-identity`).

```powershell
docker run --rm ghcr.io/tooark/aws-cli:latest aws sts get-caller-identity --no-cli-pager
```

Ver versão do kubectl (cliente):

```powershell
docker run --rm ghcr.io/tooark/aws-cli:latest kubectl version --client
```

Usar `kubectl get` com kubeconfig montado (exemplo):

```powershell
docker run --rm `
  -v C:\caminho\para\kubeconfig:/home/app/.kube/config:ro `
  ghcr.io/tooark/aws-cli:latest kubectl get nodes --request-timeout=10s
```

### Passando credenciais ao container

Por variáveis de ambiente:

```powershell
docker run --rm `
  -e AWS_ACCESS_KEY_ID=$env:AWS_ACCESS_KEY_ID `
  -e AWS_SECRET_ACCESS_KEY=$env:AWS_SECRET_ACCESS_KEY `
  -e AWS_SESSION_TOKEN=$env:AWS_SESSION_TOKEN `
  -e AWS_REGION=us-east-1 `
  ghcr.io/tooark/aws-cli:latest aws sts get-caller-identity --no-cli-pager
```

Montando o diretório de credenciais do host (`~/.aws`):

```powershell
# A imagem usa usuário não-root 'app'; monte em /home/app/.aws
docker run --rm `
  -v ${env:USERPROFILE}\.aws:/home/app/.aws:ro `
  ghcr.io/tooark/aws-cli:latest aws sts get-caller-identity --no-cli-pager
```

Para usar `kubectl`, você também pode montar um kubeconfig em `/home/app/.kube/config`.

## Variantes de tag

- `aws-cli:<major>.<minor>.<patch>`: versão exata do AWS CLI (ex.: `2.32.3`).
- `aws-cli:<major>.<minor>`: acompanha a última patch da série (ex.: `2.32`).
- `aws-cli:<major>`: acompanha a última minor da série (ex.: `2`).
- `aws-cli:latest`: aponta para a última versão estável construída.

Para pipelines reprodutíveis, prefira a versão completa.

## Como verificar versões dentro da imagem

```powershell
docker run --rm --entrypoint sh ghcr.io/tooark/aws-cli:latest -c "aws --version; kubectl version --client; dpkg -l | grep -E 'ca-certificates'"
```

## Multi-arquitetura

O `Dockerfile` detecta `TARGETARCH` e baixa:

- O instalador adequado do AWS CLI v2
- O binário `kubectl` da arquitetura correspondente

Arquiteturas suportadas:

- `linux/amd64`
- `linux/arm64`

Builds para arquiteturas diferentes falham explicitamente no estágio de build.

## GitHub Actions

### Exemplo básico

```yaml
name: Deploy

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

### Exemplo com kubectl (EKS)

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

## GitLab CI

### Exemplo básico

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

### Exemplo com kubectl (EKS)

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

## Notas de build (opcional)

Ao construir localmente, publique tags equivalentes para a mesma imagem (versão completa, curta e `latest`).

```powershell
$version = "2.32.3"   # AWS CLI
$kubectl = "1.34.2"   # kubectl
$short = ($version -split '\\.')[0..1] -join '.'

docker build `
  --build-arg AWSCLI_VERSION=$version `
  --build-arg KUBECTL_VERSION=$kubectl `
  -t aws-cli:$version `
  -t aws-cli:$short `
  -t aws-cli:latest `
  ./aws-cli
```

## Documentação oficial

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [Notas de lançamento](https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Notas de lançamento](https://kubernetes.io/releases/)

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
