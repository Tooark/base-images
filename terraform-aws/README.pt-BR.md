# terraform-aws

Imagem base com o `terraform` (Terraform CLI), `aws` (AWS CLI v2) e `kubectl`,
prontos para uso em pipelines e execuções ad-hoc em container.

> Esta família ficou legada. Para novos fluxos, use [tofu-aws/README.pt-BR.md](../tofu-aws/README.pt-BR.md).

🌍 **Idiomas:** [![USA Flag](https://flagcdn.com/w20/us.png) English](https://github.com/Tooark/base-images/blob/main/terraform-aws/README.md) · ![Brazil Flag](https://flagcdn.com/w20/br.png) **Português (este arquivo)**

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

- **Terraform**, **AWS CLI v2** e **kubectl** na mesma imagem
- Base Debian minimalista com usuário não-root
- Compatível com linux/amd64 e linux/arm64

---

## Tags da imagem

| Tag                                                | Descrição       |
| -------------------------------------------------- | --------------- |
| `ghcr.io/tooark/terraform-aws:<MAJOR.MINOR.PATCH>` | Versão completa |
| `ghcr.io/tooark/terraform-aws:<MAJOR.MINOR>`       | Versão curta    |
| `ghcr.io/tooark/terraform-aws:<MAJOR>`             | Major track     |
| `ghcr.io/tooark/terraform-aws:latest`              | Última estável  |

---

## Conteúdo da imagem

| Item                  | Descrição                                                       |
| --------------------- | --------------------------------------------------------------- |
| Base                  | `debian:13-slim`                                                |
| Terraform CLI         | `/usr/local/bin/terraform`                                      |
| AWS CLI v2            | `/usr/local/aws-cli/v2/current/bin/aws`                         |
| kubectl               | `/usr/local/bin/kubectl`                                        |
| Symlink               | `/usr/local/bin/aws` -> `/usr/local/aws-cli/v2/current/bin/aws` |
| Runtime deps          | `ca-certificates`, `gosu`                                       |
| Usuário padrão        | `app` (não-root)                                                |
| Identificador família | `ARK_IMAGE_FAMILY=terraform-aws`                                |

---

## Início rápido

Verificar versões instaladas:

```bash
docker run --rm ghcr.io/tooark/terraform-aws:latest terraform version
docker run --rm ghcr.io/tooark/terraform-aws:latest aws --version
docker run --rm ghcr.io/tooark/terraform-aws:latest kubectl version --client
```

Inicializar um diretório Terraform (monte seu código):

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/terraform-aws:latest terraform init
```

Executar plan e apply:

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/terraform-aws:latest terraform plan
```

### Passando credenciais ao container

Por variáveis de ambiente:

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  -e AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
  -e AWS_REGION=us-east-1 \
  ghcr.io/tooark/terraform-aws:latest aws sts get-caller-identity --no-cli-pager
```

Usar `kubectl get` com kubeconfig montado:

```bash
docker run --rm \
  -v "$HOME/.kube/config:/home/app/.kube/config:ro" \
  ghcr.io/tooark/terraform-aws:latest kubectl get nodes --request-timeout=10s
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

#### Exemplo com deployment em EKS (GH)

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

### GitLab CI

#### Exemplo básico (GL)

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

#### Exemplo com deployment em EKS (GL)

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

---

## Build local

```bash
version="1.14.0"  # Imagem com Terraform, AWS CLI e kubectl
tf="1.14.0"       # Terraform
aws="2.32.3"      # AWS CLI v2
kube="1.34.2"     # kubectl
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg TF_AWS_VERSION=$version \
  --build-arg TERRAFORM_VERSION=$tf \
  --build-arg AWSCLI_VERSION=$aws \
  --build-arg KUBECTL_VERSION=$kube \
  -t terraform-aws:$version \
  -t terraform-aws:$short \
  -t terraform-aws:latest \
  ./terraform-aws
```

---

## Documentação oficial

- [Terraform](https://developer.hashicorp.com/terraform/install#linux)
  - [Notas de lançamento](https://github.com/hashicorp/terraform/releases)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [Notas de lançamento](https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Notas de lançamento](https://kubernetes.io/releases/)

---

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.

<!-- markdownlint-enable MD060 -->
