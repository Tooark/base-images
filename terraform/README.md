# terraform

Esta imagem fornece o comando `terraform` (Terraform CLI) pronto para uso em pipelines e execuções ad-hoc em container.

## Nome e tags da imagem

- Nome da imagem: `terraform` (nome da pasta)
- Tags publicadas por versão:
  - Versão completa: `terraform:<major.minor.patch>`
  - Versão curta (major.minor): `terraform:<major.minor>`
  - Versão menor (major): `terraform:<major>`
  - Última estável: `terraform:latest`

Substitua os números acima pelos valores da sua build.

## O que existe na imagem

| Item           | Descrição                                      |
| -------------- | ---------------------------------------------- |
| Base           | `debian:12-slim` (padrão)                      |
| Terraform CLI  | Instalado em `/usr/local/bin/terraform`        |
| Pacote         | `ca-certificates`                              |
| Usuário padrão | `app` (não-root), HOME: `/home/app`            |

Observações:

- O usuário padrão é `app` e o HOME é `/home/app`.
- Não há `bash` na imagem; o shell padrão é `/bin/sh`.
- O `CMD` padrão é `/bin/sh`.
- Variáveis de CI pré-configuradas: `TF_IN_AUTOMATION=1`, `TF_INPUT=0`, `TF_CLI_ARGS="-input=false -no-color"`.
- A imagem é compatível com `linux/amd64` e `linux/arm64`.

## Uso rápido

Verificar a versão do Terraform:

```powershell
docker run --rm ghcr.io/tooark/terraform:latest terraform version
```

Inicializar um diretório de trabalho (monte seu código):

```powershell
docker run --rm `
  -v ${PWD}:/workspace `
  -w /workspace `
  ghcr.io/tooark/terraform:latest terraform init
```

Executar plan e apply:

```powershell
docker run --rm `
  -v ${PWD}:/workspace `
  -w /workspace `
  ghcr.io/tooark/terraform:latest terraform plan
```

> Dica: Para cache de plugins/providers entre execuções, monte um diretório persistente em `/home/app/.terraform.d`.

## Variantes de tag

- `terraform:<major>.<minor>.<patch>`: versão exata do Terraform (ex.: `1.14.0`).
- `terraform:<major>.<minor>`: acompanha a última patch da série (ex.: `1.14`).
- `terraform:<major>`: acompanha a última minor da série (ex.: `1`).
- `terraform:latest`: aponta para a última versão estável construída.

Para pipelines reprodutíveis, prefira a versão completa.

## Como verificar versões dentro da imagem

```powershell
docker run --rm --entrypoint sh ghcr.io/tooark/terraform:latest -c "terraform version; dpkg -l | grep -E 'ca-certificates'"
```

## Multi-arquitetura

O `Dockerfile` detecta `TARGETARCH` e baixa o binário adequado do Terraform.

Arquiteturas suportadas:

- `linux/amd64`
- `linux/arm64`

Builds para arquiteturas diferentes falham explicitamente no estágio de build.

## GitHub Actions

### Exemplo básico

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

## Notas de build (opcional)

Ao construir localmente, publique tags equivalentes para a mesma imagem (versão completa, curta e `latest`).

```powershell
$version = "1.14.0"
$short = ($version -split '\\.')[0..1] -join '.'

docker build `
  --build-arg TERRAFORM_VERSION=$version `
  -t terraform:$version `
  -t terraform:$short `
  -t terraform:latest `
  ./terraform
```

## Documentação oficial

- [Terraform](https://developer.hashicorp.com/terraform/install#linux)
  - [Notas de lançamento](https://github.com/hashicorp/terraform/releases)

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
