# terraform

Imagem base com `terraform` (Terraform CLI) pronto para uso em pipelines e
execuções ad-hoc em container.

> Esta família ficou legada. Para novos fluxos, use [tofu/README.pt-BR.md](../tofu/README.pt-BR.md).

🌍 **Idiomas:** [![USA Flag](https://flagcdn.com/w20/us.png) English](https://github.com/Tooark/base-images/blob/main/terraform/README.md) · ![Brazil Flag](https://flagcdn.com/w20/br.png) **Português (este arquivo)**

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

- **Terraform CLI** pronto para execução em CI/CD
- Base Debian minimalista com usuário não-root
- Compatível com linux/amd64 e linux/arm64

---

## Tags da imagem

| Tag                                            | Descrição       |
| ---------------------------------------------- | --------------- |
| `ghcr.io/tooark/terraform:<MAJOR.MINOR.PATCH>` | Versão completa |
| `ghcr.io/tooark/terraform:<MAJOR.MINOR>`       | Versão curta    |
| `ghcr.io/tooark/terraform:<MAJOR>`             | Major track     |
| `ghcr.io/tooark/terraform:latest`              | Última estável  |

## Conteúdo da imagem

| Item                  | Descrição                    |
| --------------------- | ---------------------------- |
| Base                  | `debian:13-slim`             |
| Terraform CLI         | `/usr/local/bin/terraform`   |
| Runtime deps          | `ca-certificates`, `gosu`    |
| Usuário padrão        | `app` (não-root)             |
| Identificador família | `ARK_IMAGE_FAMILY=terraform` |

---

## Início rápido

Verificar a versão do Terraform:

```bash
docker run --rm ghcr.io/tooark/terraform:latest terraform version
```

Inicializar um diretório de trabalho (monte seu código):

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/terraform:latest terraform init
```

Executar plan e apply:

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/terraform:latest terraform plan
```

> Dica: Para cache de plugins/providers entre execuções, monte um diretório persistente em `/home/app/.terraform.d`.

---

## Pipelines

### GitHub Actions

#### Exemplo básico (GH)

```yaml
name: Terraform

on:
  push:
    branches: [main]
  pull_request:

jobs:
  plan:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/terraform:latest
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
  image: ghcr.io/tooark/terraform:latest
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
  image: ghcr.io/tooark/terraform:latest
  script:
    - terraform init
    - terraform apply tfplan
  dependencies:
    - terraform_plan
  only:
    - main
  when: manual
```

---

## Build local

```bash
version="1.15.5"   # Terraform
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg TERRAFORM_VERSION=$version \
  -t terraform:$version \
  -t terraform:$short \
  -t terraform:latest \
  ./terraform
```

---

## Documentação oficial

- [Terraform](https://developer.hashicorp.com/terraform/install#linux)
  - [Notas de lançamento](https://github.com/hashicorp/terraform/releases)

---

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
