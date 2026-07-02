# terraform-aws-gcloud

Imagem base com o `terraform` (Terraform CLI), `aws` (AWS CLI v2), `gcloud` (Google Cloud SDK),
`gsutil`, `bq` e `kubectl`, prontos para uso em pipelines e execuções ad-hoc em container.

> Esta família ficou legada. Para novos fluxos, use [tofu-aws-gcloud/README.md](../tofu-aws-gcloud/README.md).

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

- **Terraform** com **AWS CLI**, **Google Cloud SDK** e **kubectl** na mesma imagem
- Base Debian minimalista com usuário não-root
- Compatível com linux/amd64 e linux/arm64

---

## Tags da imagem

| Tag                                                       | Descrição       |
| --------------------------------------------------------- | --------------- |
| `ghcr.io/tooark/terraform-aws-gcloud:<MAJOR.MINOR.PATCH>` | Versão completa |
| `ghcr.io/tooark/terraform-aws-gcloud:<MAJOR.MINOR>`       | Versão curta    |
| `ghcr.io/tooark/terraform-aws-gcloud:<MAJOR>`             | Major track     |
| `ghcr.io/tooark/terraform-aws-gcloud:latest`              | Última estável  |

---

## Conteúdo da imagem

| Item                  | Descrição                                                       |
| --------------------- | --------------------------------------------------------------- |
| Base                  | `debian:12-slim`                                                |
| Terraform CLI         | `/usr/local/bin/terraform`                                      |
| AWS CLI v2            | `/usr/local/aws-cli/v2/current/bin/aws`                         |
| Google Cloud SDK      | `/opt/google-cloud-sdk`                                         |
| kubectl               | `/usr/local/bin/kubectl`                                        |
| Symlink               | `/usr/local/bin/aws` -> `/usr/local/aws-cli/v2/current/bin/aws` |
| Symlink               | `gcloud`, `gsutil`, `bq` -> `/opt/google-cloud-sdk/bin/gcloud`  |
| Runtime deps          | `ca-certificates`, `bash`, `python3`                            |
| Usuário padrão        | `app` (não-root)                                                |
| Identificador família | `ARK_IMAGE_FAMILY=terraform-aws-gcloud`                         |

---

## Início rápido

Verificar versões instaladas:

```bash
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest terraform version
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest aws --version
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest gcloud --version
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest kubectl version --client
```

Inicializar um diretório Terraform (monte seu código):

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/terraform-aws-gcloud:latest terraform init
```

Executar plan e apply:

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/terraform-aws-gcloud:latest terraform plan
```

Listar projetos GCP (requer autenticação prévia):

```bash
docker run --rm \
  -v ${HOME}/.config/gcloud:/home/app/.config/gcloud:ro \
  ghcr.io/tooark/terraform-aws-gcloud:latest gcloud projects list --format="table(projectId,name)"
```

Usar kubectl com kubeconfig montado:

```bash
docker run --rm \
  -v ${HOME}/.kube/config:/home/app/.kube/config:ro \
  ghcr.io/tooark/terraform-aws-gcloud:latest kubectl get nodes --request-timeout=10s
```

### Passando credenciais ao container

Por variáveis de ambiente:

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID=$env:AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$env:AWS_SECRET_ACCESS_KEY \
  -e AWS_SESSION_TOKEN=$env:AWS_SESSION_TOKEN \
  -e AWS_REGION=us-east-1 \
  ghcr.io/tooark/terraform-aws-gcloud:latest aws sts get-caller-identity --no-cli-pager
```

Em ambientes CI/CD, prefira contas de serviço. Duas formas comuns:

Variável `GOOGLE_APPLICATION_CREDENTIALS` apontando para um arquivo JSON montado:

```bash
docker run --rm \
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/app/key.json \
  -v "$HOME/tmp/sa.json:/home/app/key.json:ro" \
  ghcr.io/tooark/terraform-aws-gcloud:latest gcloud auth activate-service-account --key-file=/home/app/key.json
```

Definir projeto/região/zone via variáveis de ambiente:

```bash
docker run --rm \
  -e CLOUDSDK_CORE_PROJECT=meu-projeto \
  -e CLOUDSDK_COMPUTE_REGION=us-central1 \
  -e CLOUDSDK_COMPUTE_ZONE=us-central1-a \
  ghcr.io/tooark/terraform-aws-gcloud:latest gcloud config list
```

Usar `kubectl get` com kubeconfig montado:

```bash
docker run --rm \
  -v "$HOME/.kube/config:/home/app/.kube/config:ro" \
  ghcr.io/tooark/terraform-aws-gcloud:latest kubectl get nodes --request-timeout=10s
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

### Exemplo com deploy em EKS e GKE (GH)

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

### GitLab CI

### Exemplo básico (GL)

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

### Exemplo com deploy em EKS e GKE (GL)

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

---

## Build local

```bash
version="1.14.0" # Imagem com Terraform, AWS CLI, Google Cloud SDK e kubectl
tf="1.14.0"            # Terraform
aws="2.32.3"           # AWS CLI
gcloud="548.0.0"       # Google Cloud SDK
kube="1.34.2"          # kubectl
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg TF_AWS_GCLOUD_VERSION=$version \
  --build-arg TERRAFORM_VERSION=$tf \
  --build-arg AWSCLI_VERSION=$aws \
  --build-arg GCLOUD_VERSION=$gcloud \
  --build-arg KUBECTL_VERSION=$kube \
  -t terraform-aws-gcloud:$version \
  -t terraform-aws-gcloud:$short \
  -t terraform-aws-gcloud:latest \
  ./terraform-aws-gcloud
```

---

## Documentação oficial

- [Terraform](https://developer.hashicorp.com/terraform/install#linux)
  - [Notas de lançamento](https://github.com/hashicorp/terraform/releases)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [Notas de lançamento](https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst)
- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install)
  - [Notas de lançamento](https://cloud.google.com/sdk/docs/release-notes)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Notas de lançamento](https://kubernetes.io/releases/)

---

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
