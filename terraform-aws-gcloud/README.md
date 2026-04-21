# terraform-aws-gcloud

Esta imagem fornece o `terraform`, `aws` (AWS CLI v2), `gcloud` (Google Cloud SDK), `gsutil`, `bq` e `kubectl`, prontos para uso em pipelines e execuções ad-hoc em container.

## Nome e tags da imagem

- Nome da imagem: `terraform-aws-gcloud` (nome da pasta)
- Tags publicadas por versão:
  - Versão completa: `terraform-aws-gcloud:<major.minor.patch>`
  - Versão curta (major.minor): `terraform-aws-gcloud:<major.minor>`
  - Versão menor (major): `terraform-aws-gcloud:<major>`
  - Última estável: `terraform-aws-gcloud:latest`

Substitua os números acima pelos valores da sua build.

## O que existe na imagem

| Item             | Descrição                                               |
| ---------------- | ------------------------------------------------------- |
| Base             | `debian:12-slim` (padrão)                               |
| Terraform        | Instalado em `/usr/local/bin/terraform`                 |
| AWS CLI v2       | Instalado em `/usr/local/aws-cli/v2/current/bin/aws`    |
| Google Cloud SDK | Instalado em `/opt/google-cloud-sdk`                    |
| kubectl          | Instalado em `/usr/local/bin/kubectl`                   |
| Symlinks         | `aws`, `gcloud`, `gsutil`, `bq` em `/usr/local/bin`     |
| Binários         | `terraform`, `aws`, `gcloud`, `gsutil`, `bq`, `kubectl` |
| Pacotes          | `ca-certificates`, `bash`, `python3`                    |
| Usuário padrão   | `app` (não-root), HOME: `/home/app`                     |

Observações:

- O usuário padrão é `app` e o HOME é `/home/app`.
- A imagem inclui `bash` e `python3` (necessários para scripts do gcloud).
- O `CMD` padrão é `/bin/bash`.
- Variáveis de CI pré-configuradas: `TF_IN_AUTOMATION=1`, `TF_INPUT=0`, `TF_CLI_ARGS="-input=false -no-color"`.
- A imagem é compatível com `linux/amd64` e `linux/arm64`.

## Uso rápido

Verificar versões instaladas:

```powershell
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest terraform version
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest aws --version
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest gcloud --version
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest kubectl version --client
```

Inicializar diretório Terraform (monte seu código):

```powershell
docker run --rm `
  -v ${PWD}:/workspace `
  -w /workspace `
  ghcr.io/tooark/terraform-aws-gcloud:latest terraform init
```

Executar plan Terraform:

```powershell
docker run --rm `
  -v ${PWD}:/workspace `
  -w /workspace `
  ghcr.io/tooark/terraform-aws-gcloud:latest terraform plan
```

Executar comando AWS (ex.: STS):

```powershell
docker run --rm `
  -e AWS_ACCESS_KEY_ID=$env:AWS_ACCESS_KEY_ID `
  -e AWS_SECRET_ACCESS_KEY=$env:AWS_SECRET_ACCESS_KEY `
  -e AWS_REGION=us-east-1 `
  ghcr.io/tooark/terraform-aws-gcloud:latest aws sts get-caller-identity --no-cli-pager
```

Listar projetos GCP (requer autenticação prévia):

```powershell
docker run --rm `
  -v ${env:USERPROFILE}\.config\gcloud:/home/app/.config/gcloud:ro `
  ghcr.io/tooark/terraform-aws-gcloud:latest gcloud projects list --format="table(projectId,name)"
```

Usar kubectl com kubeconfig montado:

```powershell
docker run --rm `
  -v C:\caminho\para\kubeconfig:/home/app/.kube/config:ro `
  ghcr.io/tooark/terraform-aws-gcloud:latest kubectl get nodes --request-timeout=10s
```

## Variantes de tag

- `terraform-aws-gcloud:<major.minor.patch>`: versão exata (ex.: `terraform-aws-gcloud:1.14.0`).
- `terraform-aws-gcloud:<major.minor>`: acompanha a última patch da série (ex.: `terraform-aws-gcloud:1.14`).
- `terraform-aws-gcloud:<major>`: acompanha a última minor da série (ex.: `terraform-aws-gcloud:1`).
- `terraform-aws-gcloud:latest`: aponta para a última versão estável construída.

Para pipelines reprodutíveis, prefira a versão completa.

## Como verificar versões dentro da imagem

```powershell
docker run --rm --entrypoint sh ghcr.io/tooark/terraform-aws-gcloud:latest -c "terraform version; aws --version; gcloud --version; kubectl version --client; dpkg -l | grep -E 'ca-certificates|bash|python3'"
```

## Multi-arquitetura

O `Dockerfile` detecta `TARGETARCH` e baixa:

- O binário Terraform da arquitetura correspondente
- O instalador AWS CLI da arquitetura correspondente
- O Google Cloud SDK da arquitetura correspondente
- O binário kubectl da arquitetura correspondente

Arquiteturas suportadas:

- `linux/amd64`
- `linux/arm64`

Builds para arquiteturas diferentes falham explicitamente no estágio de build.

## GitHub Actions

### Exemplo básico

```yaml
name: Terraform MultiCloud

on:
  push:
    branches: [main]
  pull_request:

jobs:
  terraform:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/terraform-aws-gcloud:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Auth GCP
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

### Exemplo com deploy em EKS e GKE

```yaml
name: Deploy MultiCluster

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/terraform-aws-gcloud:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
      AWS_REGION: us-east-1
    steps:
      - uses: actions/checkout@v4

      - name: Auth GCP + Terraform
        run: |
          echo "$GOOGLE_CREDENTIALS" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud config set project ${{ vars.GCP_PROJECT }}
          terraform init
          terraform apply -auto-approve

      - name: Deploy EKS
        run: |
          aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER }}
          kubectl apply -f k8s/eks

      - name: Deploy GKE
        run: |
          gcloud container clusters get-credentials ${{ vars.GKE_CLUSTER }} --zone ${{ vars.GKE_ZONE }}
          kubectl apply -f k8s/gke
```

## GitLab CI

### Exemplo básico

```yaml
stages:
  - validate
  - deploy

terraform_plan:
  stage: validate
  image: ghcr.io/tooark/terraform-aws-gcloud:latest
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
  image: ghcr.io/tooark/terraform-aws-gcloud:latest
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

### Exemplo com deploy em EKS e GKE

```yaml
stages:
  - deploy

deploy_multicluster:
  stage: deploy
  image: ghcr.io/tooark/terraform-aws-gcloud:latest
  script:
    - echo "$GCP_SA_KEY" > /tmp/sa.json
    - gcloud auth activate-service-account --key-file=/tmp/sa.json
    - gcloud config set project $GCP_PROJECT
    - terraform init
    - terraform apply -auto-approve
    - aws eks update-kubeconfig --name $EKS_CLUSTER
    - kubectl apply -f k8s/eks
    - gcloud container clusters get-credentials $GKE_CLUSTER --zone $GKE_ZONE
    - kubectl apply -f k8s/gke
  only:
    - main
  when: manual
```

## Notas de build (opcional)

Ao construir localmente, publique tags equivalentes para a mesma imagem.

```powershell
$tf_aws_gcloud = "1.14.0" # Imagem com Terraform, AWS CLI, Google Cloud SDK e kubectl
$tf = "1.14.0"            # Terraform
$aws = "2.32.3"           # AWS CLI
$gcloud = "548.0.0"       # Google Cloud SDK
$kube = "1.34.2"          # kubectl

docker build `
  --build-arg TF_AWS_GCLOUD_VERSION=$tf_aws_gcloud `
  --build-arg TERRAFORM_VERSION=$tf `
  --build-arg AWSCLI_VERSION=$aws `
  --build-arg GCLOUD_VERSION=$gcloud `
  --build-arg KUBECTL_VERSION=$kube `
  -t terraform-aws-gcloud:latest `
  -t terraform-aws-gcloud:$tf_aws_gcloud `
  ./terraform-aws-gcloud
```

## Documentação oficial

- [Terraform](https://developer.hashicorp.com/terraform/install#linux)
  - [Notas de lançamento](https://github.com/hashicorp/terraform/releases)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [Notas de lançamento](https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
  - [Notas de lançamento](https://cloud.google.com/sdk/docs/release-notes)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Notas de lançamento](https://kubernetes.io/releases/)

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
