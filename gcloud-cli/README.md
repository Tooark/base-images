# gcloud-cli

Imagem base com `gcloud` (Google Cloud SDK), `gsutil`, `bq`, `kubectl`, `docker`
e `docker buildx`, prontos para uso em pipelines e execuções ad-hoc em container.

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

- **Google Cloud SDK**, **kubectl**, **Docker CLI** e **Buildx** na mesma imagem
- Base Debian minimalista com usuário não-root
- Compatível com linux/amd64 e linux/arm64

---

## Tags da imagem

| Tag                                             | Descrição       |
| ----------------------------------------------- | --------------- |
| `ghcr.io/tooark/gcloud-cli:<MAJOR.MINOR.PATCH>` | Versão completa |
| `ghcr.io/tooark/gcloud-cli:<MAJOR.MINOR>`       | Versão curta    |
| `ghcr.io/tooark/gcloud-cli:<MAJOR>`             | Major track     |
| `ghcr.io/tooark/gcloud-cli:latest`              | Última estável  |

---

## Conteúdo da imagem

| Item                  | Descrição                                                      |
| --------------------- | -------------------------------------------------------------- |
| Base                  | `debian:12-slim`                                               |
| Google Cloud SDK      | `/opt/google-cloud-sdk`                                        |
| kubectl               | `/usr/local/bin/kubectl`                                       |
| Docker CLI            | `/usr/local/bin/docker`                                        |
| Docker Buildx         | `/usr/local/libexec/docker/cli-plugins/docker-buildx`          |
| Symlink               | `gcloud`, `gsutil`, `bq` -> `/opt/google-cloud-sdk/bin/gcloud` |
| Runtime deps          | `ca-certificates`, `bash`, `python3`                           |
| Usuário padrão        | `app` (não-root)                                               |
| Identificador família | `ARK_IMAGE_FAMILY=gcloud-cli`                                  |

---

## Início rápido

Executar `gcloud --version`:

```bash
docker run --rm ghcr.io/tooark/gcloud-cli:latest gcloud --version
```

Listar informações de configuração atuais (sem autenticar):

```bash
docker run --rm ghcr.io/tooark/gcloud-cli:latest gcloud info
```

Ver versão do kubectl (cliente):

```bash
docker run --rm ghcr.io/tooark/gcloud-cli:latest kubectl version --client
```

### Autenticação e credenciais

Em ambientes CI/CD, prefira contas de serviço. Duas formas comuns:

Variável `GOOGLE_APPLICATION_CREDENTIALS` apontando para um arquivo JSON montado:

```bash
docker run --rm \
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/app/key.json \
  -v "$HOME/tmp/sa.json:/home/app/key.json:ro" \
  ghcr.io/tooark/gcloud-cli:latest gcloud auth activate-service-account --key-file=/home/app/key.json
```

Definir projeto/região/zone via variáveis de ambiente:

```bash
docker run --rm \
  -e CLOUDSDK_CORE_PROJECT=meu-projeto \
  -e CLOUDSDK_COMPUTE_REGION=us-central1 \
  -e CLOUDSDK_COMPUTE_ZONE=us-central1-a \
  ghcr.io/tooark/gcloud-cli:latest gcloud config list
```

Usar `kubectl get` com kubeconfig montado:

```bash
docker run --rm \
  -v "$HOME/.kube/config:/home/app/.kube/config:ro" \
  ghcr.io/tooark/gcloud-cli:latest kubectl get nodes --request-timeout=10s
```

Para usar `kubectl`, você também pode montar um kubeconfig em `/home/app/.kube/config`.

---

## Variáveis de ambiente

### GCLOUD CLI

| Variável                         | Default | Descrição                                       |
| -------------------------------- | ------- | ----------------------------------------------- |
| `GOOGLE_APPLICATION_CREDENTIALS` | -       | Caminho para o arquivo JSON da conta de serviço |
| `CLOUDSDK_CORE_PROJECT`          | -       | Projeto padrão do GCP                           |
| `CLOUDSDK_COMPUTE_REGION`        | -       | Região padrão do GCP                            |
| `CLOUDSDK_COMPUTE_ZONE`          | -       | Zona padrão do GCP                              |

---

## Pipelines

### GitHub Actions

#### Exemplo básico (GH)

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

#### Exemplo com kubectl (GKE) (GH)

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

### GitLab CI

#### Exemplo básico (GL)

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

#### Exemplo com kubectl (GKE) (GL)

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

---

## Build local

Ao construir localmente, publique tags equivalentes para a mesma imagem (versão completa, curta e `latest`).

```bash
version="571.0.0"  # Google Cloud SDK
kubectl="1.36.1"   # kubectl
docker="29.5.2"    # Docker CLI
buildx="0.34.1"    # Buildx
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg GCLOUD_VERSION="$version" \
  --build-arg KUBECTL_VERSION="$kubectl" \
  --build-arg DOCKER_VERSION="$docker" \
  --build-arg DOCKER_BUILDX_VERSION="$buildx" \
  -t "gcloud-cli:$version" \
  -t "gcloud-cli:$short" \
  -t gcloud-cli:latest \
  ./gcloud-cli
```

---

## Documentação oficial

- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install)
  - [Notas de lançamento](https://cloud.google.com/sdk/docs/release-notes)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Notas de lançamento](https://kubernetes.io/releases/)
- [Docker CLI](https://docs.docker.com/reference/cli/docker/)
  - [Notas de lançamento](https://docs.docker.com/engine/release-notes/)
- [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/)
  - [Notas de lançamento](https://github.com/docker/buildx/releases/)

---

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
