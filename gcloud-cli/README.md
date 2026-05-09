# gcloud-cli

Esta imagem fornece o Google Cloud SDK (`gcloud`, `gsutil`, `bq`), `kubectl`, `docker` e `docker buildx`, prontos para uso em pipelines e execuções ad-hoc em container.

## Nome e tags da imagem

- Nome da imagem: `gcloud-cli` (nome da pasta)
- Tags publicadas por versão:
  - Versão completa: `gcloud-cli:<major.minor.patch>`
  - Versão curta (major.minor): `gcloud-cli:<major.minor>`
  - Versão menor (major): `gcloud-cli:<major>`
  - Última estável: `gcloud-cli:latest`

Substitua os números acima pelos valores da sua build.

## O que existe na imagem

| Item             | Descrição                                                         |
| ---------------- | ----------------------------------------------------------------- |
| Base             | `debian:12-slim` (padrão)                                         |
| Google Cloud SDK | Instalado em `/opt/google-cloud-sdk`                              |
| kubectl          | Instalado em `/usr/local/bin/kubectl`                             |
| Docker CLI       | Instalado em `/usr/local/bin/docker`                              |
| Docker Buildx    | Plugin em `/usr/local/libexec/docker/cli-plugins/docker-buildx`   |
| Symlinks         | `gcloud`, `gsutil`, `bq` disponíveis em `/usr/local/bin`          |
| Binários         | `gcloud`, `gsutil`, `bq`, `kubectl`, `docker` em `/usr/local/bin` |
| Pacotes          | `ca-certificates`, `bash`, `python3`                              |
| Usuário padrão   | `app` (não-root), HOME: `/home/app`                               |

Observações:

- O usuário padrão é `app` e o HOME é `/home/app`.
- A imagem inclui `bash` e `python3` (necessários para os scripts do gcloud).
- O `CMD` padrão é `/bin/bash`.
- Prompts interativos são desabilitados por padrão: `CLOUDSDK_CORE_DISABLE_PROMPTS=1`.
- A imagem é compatível com `linux/amd64` e `linux/arm64`.

## Uso rápido

Executar `gcloud --version`:

```powershell
docker run --rm ghcr.io/tooark/gcloud-cli:latest gcloud --version
```

Listar informações de configuração atuais (sem autenticar):

```powershell
docker run --rm ghcr.io/tooark/gcloud-cli:latest gcloud info
```

Ver versão do kubectl (cliente):

```powershell
docker run --rm ghcr.io/tooark/gcloud-cli:latest kubectl version --client
```

### Autenticação e credenciais

Em ambientes CI/CD, prefira contas de serviço. Duas formas comuns:

1. Variável `GOOGLE_APPLICATION_CREDENTIALS` apontando para um arquivo JSON montado:

   ```powershell
   docker run --rm `
     -e GOOGLE_APPLICATION_CREDENTIALS=/home/app/key.json `
     -v ${env:USERPROFILE}\Downloads\sa.json:/home/app/key.json:ro `
     ghcr.io/tooark/gcloud-cli:latest gcloud auth activate-service-account --key-file=/home/app/key.json
   ```

2. Definir projeto/região/zone via variáveis de ambiente:

   ```powershell
   docker run --rm `
     -e CLOUDSDK_CORE_PROJECT=meu-projeto `
     -e CLOUDSDK_COMPUTE_REGION=us-central1 `
     -e CLOUDSDK_COMPUTE_ZONE=us-central1-a `
     ghcr.io/tooark/gcloud-cli:latest gcloud config list
   ```

3. Usar `kubectl get` com kubeconfig montado:

   ```powershell
   docker run --rm `
     -v C:\caminho\para\kubeconfig:/home/app/.kube/config:ro `
     ghcr.io/tooark/gcloud-cli:latest kubectl get nodes --request-timeout=10s
   ```

> O usuário padrão é `app`; ao montar arquivos de credencial, use caminhos sob `/home/app` dentro do container.

## Variantes de tag

- `gcloud-cli:<major>.<minor>.<patch>`: versão exata do SDK (ex.: `548.0.0`).
- `gcloud-cli:<major>.<minor>`: acompanha a última patch da série (ex.: `548.0`).
- `gcloud-cli:<major>`: acompanha a última minor da série (ex.: `548`).
- `gcloud-cli:latest`: aponta para a última versão estável construída.

Para pipelines reprodutíveis, prefira a versão completa.

## Como verificar versões dentro da imagem

```powershell
docker run --rm --entrypoint sh ghcr.io/tooark/gcloud-cli:latest -c "gcloud --version; gsutil --version; bq version; kubectl version --client; docker --version; docker buildx version; dpkg -l | grep -E 'ca-certificates|bash|python3'"
```

## Multi-arquitetura

O `Dockerfile` detecta `TARGETARCH` e baixa:

- O Google Cloud SDK da arquitetura correspondente
- O binário `kubectl` da arquitetura correspondente
- O Docker CLI estático da arquitetura correspondente
- O plugin Docker Buildx da arquitetura correspondente

Arquiteturas suportadas:

- `linux/amd64`
- `linux/arm64`

Builds para arquiteturas diferentes falham explicitamente no estágio de build.

## GitHub Actions

### Exemplo básico

```yaml
name: Deploy GCP

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/gcloud-cli:latest
    steps:
      - uses: actions/checkout@v4

      - name: Autenticar com service account
        env:
          GCP_SA_KEY: ${{ secrets.GCP_SA_KEY }}
        run: |
          echo "$GCP_SA_KEY" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud config set project ${{ vars.GCP_PROJECT }}

      - name: Deploy para Cloud Storage
        run: gsutil -m rsync -r ./dist gs://${{ vars.GCS_BUCKET }}
```

### Exemplo com kubectl (GKE)

```yaml
name: Deploy GKE

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/gcloud-cli:latest
    steps:
      - uses: actions/checkout@v4

      - name: Autenticar e configurar cluster
        env:
          GCP_SA_KEY: ${{ secrets.GCP_SA_KEY }}
        run: |
          echo "$GCP_SA_KEY" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud container clusters get-credentials ${{ vars.GKE_CLUSTER }} \
            --zone ${{ vars.GKE_ZONE }} \
            --project ${{ vars.GCP_PROJECT }}

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

deploy_gcs:
  stage: deploy
  image: ghcr.io/tooark/gcloud-cli:latest
  script:
    - echo "$GCP_SA_KEY" > /tmp/sa.json
    - gcloud auth activate-service-account --key-file=/tmp/sa.json
    - gcloud config set project $GCP_PROJECT
    - gsutil -m rsync -r ./dist gs://$GCS_BUCKET
  only:
    - main
```

### Exemplo com kubectl (GKE)

```yaml
stages:
  - deploy

deploy_gke:
  stage: deploy
  image: ghcr.io/tooark/gcloud-cli:latest
  script:
    - echo "$GCP_SA_KEY" > /tmp/sa.json
    - gcloud auth activate-service-account --key-file=/tmp/sa.json
    - gcloud container clusters get-credentials $GKE_CLUSTER --zone $GKE_ZONE --project $GCP_PROJECT
    - kubectl apply -f k8s/
    - kubectl rollout status deployment/$APP_NAME --timeout=120s
  only:
    - main
```

## Notas de build (opcional)

Ao construir localmente, publique tags equivalentes para a mesma imagem (versão completa, curta e `latest`).

```powershell
$version = "548.0.0"   # Google Cloud SDK
$kubectl = "1.30.4"    # kubectl
$docker  = "28.1.1"    # Docker CLI
$buildx  = "0.26.1"    # Buildx
$short = ($version -split '\\.')[0..1] -join '.'

docker build `
  --build-arg GCLOUD_VERSION=$version `
  --build-arg KUBECTL_VERSION=$kubectl `
  --build-arg DOCKER_VERSION=$docker `
  --build-arg DOCKER_BUILDX_VERSION=$buildx `
  -t gcloud-cli:$version `
  -t gcloud-cli:$short `
  -t gcloud-cli:latest `
  ./gcloud-cli
```

## Documentação oficial

- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install)
  - [Notas de lançamento](https://cloud.google.com/sdk/docs/release-notes)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Notas de lançamento](https://kubernetes.io/releases/)
- [Docker CLI](https://docs.docker.com/engine/release-notes/)
  - [Releases](https://github.com/docker/cli/releases)
- [Docker Buildx](https://docs.docker.com/build/buildx/)
  - [Releases](https://github.com/docker/buildx/releases)

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
