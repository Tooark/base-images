# terraform-aws

Esta imagem fornece o `terraform`, `aws` (AWS CLI v2) e `kubectl`, prontos para uso em pipelines e execuções ad-hoc em container.

## Nome e tags da imagem

- Nome da imagem: `terraform-aws` (nome da pasta)
- Tags publicadas por versão:
  - Versão completa: `terraform-aws:<major.minor.patch>`
  - Versão curta (major.minor): `terraform-aws:<major.minor>`
  - Versão menor (major): `terraform-aws:<major>`
  - Última estável: `terraform-aws:latest`

Substitua os números acima pelos valores da sua build.

## O que existe na imagem

| Item           | Descrição                                                       |
| -------------- | --------------------------------------------------------------- |
| Base           | `debian:12-slim` (padrão)                                       |
| Terraform      | Instalado em `/usr/local/bin/terraform`                         |
| AWS CLI v2     | Instalado em `/usr/local/aws-cli/v2/current/bin/aws`            |
| kubectl        | Instalado em `/usr/local/bin/kubectl`                           |
| Symlink        | `/usr/local/bin/aws` -> `/usr/local/aws-cli/v2/current/bin/aws` |
| Binários       | `terraform`, `aws`, `kubectl` disponíveis em `/usr/local/bin`   |
| Pacote         | `ca-certificates`                                               |
| Usuário padrão | `app` (não-root), HOME: `/home/app`                             |

Observações:

- O usuário padrão é `app` e o HOME é `/home/app`.
- Não há `bash` na imagem; o shell padrão é `/bin/sh`.
- O `CMD` padrão é `/bin/sh`.
- Variáveis de CI pré-configuradas: `TF_IN_AUTOMATION=1`, `TF_INPUT=0`, `TF_CLI_ARGS="-input=false -no-color"`.
- A imagem é compatível com `linux/amd64` e `linux/arm64`.

## Uso rápido

Verificar versões instaladas:

```powershell
docker run --rm ghcr.io/tooark/terraform-aws:latest terraform version
docker run --rm ghcr.io/tooark/terraform-aws:latest aws --version
docker run --rm ghcr.io/tooark/terraform-aws:latest kubectl version --client
```

Inicializar um diretório Terraform (monte seu código):

```powershell
docker run --rm `
  -v ${PWD}:/workspace `
  -w /workspace `
  ghcr.io/tooark/terraform-aws:latest terraform init
```

Executar plan e apply:

```powershell
docker run --rm `
  -v ${PWD}:/workspace `
  -w /workspace `
  ghcr.io/tooark/terraform-aws:latest terraform plan
```

Executar comando AWS (ex.: STS):

```powershell
docker run --rm `
  -e AWS_ACCESS_KEY_ID=$env:AWS_ACCESS_KEY_ID `
  -e AWS_SECRET_ACCESS_KEY=$env:AWS_SECRET_ACCESS_KEY `
  -e AWS_REGION=us-east-1 `
  ghcr.io/tooark/terraform-aws:latest aws sts get-caller-identity --no-cli-pager
```

Usar kubectl com kubeconfig montado:

```powershell
docker run --rm `
  -v C:\caminho\para\kubeconfig:/home/app/.kube/config:ro `
  ghcr.io/tooark/terraform-aws:latest kubectl get nodes --request-timeout=10s
```

## Variantes de tag

- `terraform-aws:<major.minor.patch>`: versão exata (ex.: `terraform-aws:1.14.0`).
- `terraform-aws:<major.minor>`: acompanha a última patch da série (ex.: `terraform-aws:1.14`).
- `terraform-aws:<major>`: acompanha a última minor da série (ex.: `terraform-aws:1`).
- `terraform-aws:latest`: aponta para a última versão estável construída.

Para pipelines reprodutíveis, prefira a versão completa.

## Como verificar versões dentro da imagem

```powershell
docker run --rm --entrypoint sh ghcr.io/tooark/terraform-aws:latest -c "terraform version; aws --version; kubectl version --client; dpkg -l | grep -E 'ca-certificates'"
```

## Multi-arquitetura

O `Dockerfile` detecta `TARGETARCH` e baixa:

- O binário Terraform da arquitetura correspondente
- O instalador AWS CLI da arquitetura correspondente
- O binário kubectl da arquitetura correspondente

Arquiteturas suportadas:

- `linux/amd64`
- `linux/arm64`

Builds para arquiteturas diferentes falham explicitamente no estágio de build.

## GitHub Actions

### Exemplo básico

```yaml
name: Terraform Deploy

on:
  push:
    branches: [main]
  pull_request:

jobs:
  terraform:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/terraform-aws:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_REGION: us-east-1
    steps:
      - uses: actions/checkout@v4

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply tfplan
```

### Exemplo com deployment em EKS

```yaml
name: Deploy to EKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/terraform-aws:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_REGION: us-east-1
    steps:
      - uses: actions/checkout@v4

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply tfplan

      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER }}
          kubectl apply -f k8s/

      - name: Verify deployment
        run: kubectl rollout status deployment/${{ vars.APP_NAME }} --timeout=120s
```

## GitLab CI

### Exemplo básico

```yaml
stages:
  - validate
  - deploy

variables:
  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
  AWS_REGION: us-east-1

terraform_plan:
  stage: validate
  image: ghcr.io/tooark/terraform-aws:latest
  script:
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
  image: ghcr.io/tooark/terraform-aws:latest
  script:
    - terraform init
    - terraform apply tfplan
  dependencies:
    - terraform_plan
  only:
    - main
  when: manual
```

### Exemplo com deployment em EKS

```yaml
stages:
  - deploy

variables:
  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
  AWS_REGION: us-east-1

deploy_eks:
  stage: deploy
  image: ghcr.io/tooark/terraform-aws:latest
  script:
    - terraform init
    - terraform apply -auto-approve
    - aws eks update-kubeconfig --name $EKS_CLUSTER
    - kubectl apply -f k8s/
    - kubectl rollout status deployment/$APP_NAME --timeout=120s
  only:
    - main
  when: manual
```

## Notas de build (opcional)

Ao construir localmente, publique tags equivalentes para a mesma imagem.

```powershell
$tf_aws = "1.14.0"  # Imagem com Terraform, AWS CLI e kubectl
$tf = "1.14.0"      # Terraform
$aws = "2.32.3"     # AWS CLI v2
$kube = "1.34.2"    # kubectl

docker build `
  --build-arg TF_AWS_VERSION=$tf_aws `
  --build-arg TERRAFORM_VERSION=$tf `
  --build-arg AWSCLI_VERSION=$aws `
  --build-arg KUBECTL_VERSION=$kube `
  -t terraform-aws:latest `
  -t terraform-aws:$tf_aws `
  ./terraform-aws
```

## Documentação oficial

- [Terraform](https://developer.hashicorp.com/terraform/install#linux)
  - [Notas de lançamento](https://github.com/hashicorp/terraform/releases)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [Notas de lançamento](https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Notas de lançamento](https://kubernetes.io/releases/)

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
