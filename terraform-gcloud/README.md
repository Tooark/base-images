# terraform-gcloud

Esta imagem fornece o `terraform`, `gcloud` (Google Cloud SDK), `gsutil`, `bq` e `kubectl`, prontos para uso em pipelines e execuções ad-hoc em container.

## Nome e tags da imagem

- Nome da imagem: `terraform-gcloud` (nome da pasta)
- Tags publicadas por versão:
  - Versão completa: `terraform-gcloud:<major.minor.patch>`
  - Versão curta (major.minor): `terraform-gcloud:<major.minor>`
  - Versão menor (major): `terraform-gcloud:<major>`
  - Última estável: `terraform-gcloud:latest`

Substitua os números acima pelos valores da sua build.

## O que existe na imagem

| Item             | Descrição                                        |
| ---------------- | ------------------------------------------------ |
| Base             | `debian:12-slim` (padrão)                        |
| Terraform        | Instalado em `/usr/local/bin/terraform`          |
| Google Cloud SDK | Instalado em `/opt/google-cloud-sdk`             |
| kubectl          | Instalado em `/usr/local/bin/kubectl`            |
| Symlinks         | `gcloud`, `gsutil`, `bq` em `/usr/local/bin`     |
| Binários         | `terraform`, `gcloud`, `gsutil`, `bq`, `kubectl` |
| Pacotes          | `ca-certificates`, `bash`, `python3`             |
| Usuário padrão   | `app` (não-root), HOME: `/home/app`              |

Observações:

- O usuário padrão é `app` e o HOME é `/home/app`.
- A imagem inclui `bash` e `python3` (necessários para scripts do gcloud).
- O `CMD` padrão é `/bin/bash`.
- Variáveis de CI pré-configuradas: `TF_IN_AUTOMATION=1`, `TF_INPUT=0`, `TF_CLI_ARGS="-input=false -no-color"`.
- A imagem é compatível com `linux/amd64` e `linux/arm64`.

## Uso rápido

Verificar versões instaladas:

```powershell
docker run --rm ghcr.io/tooark/terraform-gcloud:latest terraform version
docker run --rm ghcr.io/tooark/terraform-gcloud:latest gcloud --version
docker run --rm ghcr.io/tooark/terraform-gcloud:latest kubectl version --client
```

Inicializar diretório Terraform (monte seu código):

```powershell
docker run --rm `
  -v ${PWD}:/workspace `
  -w /workspace `
  ghcr.io/tooark/terraform-gcloud:latest terraform init
```

Executar plan Terraform:

```powershell
docker run --rm `
  -v ${PWD}:/workspace `
  -w /workspace `
  ghcr.io/tooark/terraform-gcloud:latest terraform plan
```

Listar projetos GCP (requer autenticação prévia):

```powershell
docker run --rm `
  -v ${env:USERPROFILE}\.config\gcloud:/home/app/.config/gcloud:ro `
  ghcr.io/tooark/terraform-gcloud:latest gcloud projects list --format="table(projectId,name)"
```

Usar kubectl com kubeconfig montado:

```powershell
docker run --rm `
  -v C:\caminho\para\kubeconfig:/home/app/.kube/config:ro `
  ghcr.io/tooark/terraform-gcloud:latest kubectl get nodes --request-timeout=10s
```

## Variantes de tag

- `terraform-gcloud:<major.minor.patch>`: versão exata (ex.: `terraform-gcloud:1.14.0`).
- `terraform-gcloud:<major.minor>`: acompanha a última patch da série (ex.: `terraform-gcloud:1.14`).
- `terraform-gcloud:<major>`: acompanha a última minor da série (ex.: `terraform-gcloud:1`).
- `terraform-gcloud:latest`: aponta para a última versão estável construída.

Para pipelines reprodutíveis, prefira a versão completa.

## Como verificar versões dentro da imagem

```powershell
docker run --rm --entrypoint sh ghcr.io/tooark/terraform-gcloud:latest -c "terraform version; gcloud --version; kubectl version --client; dpkg -l | grep -E 'ca-certificates|bash|python3'"
```

## Multi-arquitetura

O `Dockerfile` detecta `TARGETARCH` e baixa:

- O binário Terraform da arquitetura correspondente
- O Google Cloud SDK da arquitetura correspondente
- O binário kubectl da arquitetura correspondente

Arquiteturas suportadas:

- `linux/amd64`
- `linux/arm64`

Builds para arquiteturas diferentes falham explicitamente no estágio de build.

## GitHub Actions

### Exemplo básico

```yaml
name: Terraform GCP

on:
  push:
    branches: [main]
  pull_request:

jobs:
  terraform:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/terraform-gcloud:latest
    env:
      GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Autenticar no GCP
        run: |
          echo "$GOOGLE_CREDENTIALS" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud config set project ${{ vars.GCP_PROJECT }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply tfplan
```

### Exemplo com deployment em GKE

```yaml
name: Deploy to GKE

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/terraform-gcloud:latest
    env:
      GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Auth + Terraform
        run: |
          echo "$GOOGLE_CREDENTIALS" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud config set project ${{ vars.GCP_PROJECT }}
          terraform init
          terraform apply -auto-approve

      - name: Configure kubectl and deploy
        run: |
          gcloud container clusters get-credentials ${{ vars.GKE_CLUSTER }} --zone ${{ vars.GKE_ZONE }}
          kubectl apply -f k8s/
          kubectl rollout status deployment/${{ vars.APP_NAME }} --timeout=120s
```

## GitLab CI

### Exemplo básico

```yaml
stages:
  - validate
  - deploy

terraform_plan:
  stage: validate
  image: ghcr.io/tooark/terraform-gcloud:latest
  script:
    - echo "$GCP_SA_KEY" > /tmp/sa.json
    - gcloud auth activate-service-account --key-file=/tmp/sa.json
    - gcloud config set project $GCP_PROJECT
    - terraform init
    - terraform validate
    - terraform plan -out=tfplan
  artifacts:
    paths:
      - tfplan
  only:
    - merge_requests
    - main

terraform_apply:
  stage: deploy
  image: ghcr.io/tooark/terraform-gcloud:latest
  script:
    - echo "$GCP_SA_KEY" > /tmp/sa.json
    - gcloud auth activate-service-account --key-file=/tmp/sa.json
    - gcloud config set project $GCP_PROJECT
    - terraform init
    - terraform apply tfplan
  dependencies:
    - terraform_plan
  only:
    - main
  when: manual
```

### Exemplo com deployment em GKE

```yaml
stages:
  - deploy

deploy_gke:
  stage: deploy
  image: ghcr.io/tooark/terraform-gcloud:latest
  script:
    - echo "$GCP_SA_KEY" > /tmp/sa.json
    - gcloud auth activate-service-account --key-file=/tmp/sa.json
    - gcloud config set project $GCP_PROJECT
    - terraform init
    - terraform apply -auto-approve
    - gcloud container clusters get-credentials $GKE_CLUSTER --zone $GKE_ZONE
    - kubectl apply -f k8s/
    - kubectl rollout status deployment/$APP_NAME --timeout=120s
  only:
    - main
  when: manual
```

## Notas de build (opcional)

Ao construir localmente, publique tags equivalentes para a mesma imagem.

```powershell
$tf_gcloud = "1.14.0" # Imagem com Terraform, Google Cloud SDK e kubectl
$tf = "1.14.0"        # Terraform
$gcloud = "2.32.3"    # Google Cloud SDK
$kube = "1.34.2"      # kubectl

docker build `
  --build-arg TF_GCLOUD_VERSION=$tf_gcloud `
  --build-arg TERRAFORM_VERSION=$tf `
  --build-arg GCLOUD_VERSION=$gcloud `
  --build-arg KUBECTL_VERSION=$kube `
  -t terraform-gcloud:latest `
  -t terraform-gcloud:$tf_gcloud `
  ./terraform-gcloud
```

## Documentação oficial

- [Terraform](https://developer.hashicorp.com/terraform/install#linux)
  - [Notas de lançamento](https://github.com/hashicorp/terraform/releases)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
  - [Notas de lançamento](https://cloud.google.com/sdk/docs/release-notes)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Notas de lançamento](https://kubernetes.io/releases/)

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
