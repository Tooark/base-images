# terraform

Esta imagem fornece o comando `terraform` (Terraform CLI) pronto para uso em pipelines e em containers ad-hoc. Este documento explica como usar a imagem gerada pelo build, incluindo as tags publicadas.

## Nome e tags da imagem

- Nome da imagem: `terraform` (nome da pasta)
- Tags publicadas por versão:
  - Versão completa: `terraform:1.14.0`
  - Versão curta (major.minor): `terraform:1.14`
  - Última estável: `terraform:latest`

Substitua os números de versão acima pelo valor correspondente à sua build.

## O que tem nesta imagem

| Ferramenta / item    | Versão / observação                      | ARG (build)         |
| -------------------- | ---------------------------------------- | ------------------- |
| Debian (imagem base) | `debian:12-slim` (padrão)                | `BASE_IMAGE`        |
| Terraform CLI        | Versão definida pela tag (ex.: `1.14.0`) | `TERRAFORM_VERSION` |
| Binário disponível   | `terraform` (em `/usr/local/bin`)        | N/A                 |
| Pacote de runtime    | `ca-certificates`                        | N/A                 |
| Usuário padrão       | `app` (não-root), HOME: `/home/app`      | N/A                 |

Observações:

- O usuário padrão é `app` e o HOME é `/home/app`.
- Não há `bash` na imagem; o shell padrão é `/bin/sh`.

## Uso rápido

Verificar a versão do Terraform:

```powershell
docker run --rm ghcr.io/tooark/terraform:latest terraform version
```

Inicializar um diretório de trabalho (monte seu código):

```powershell
docker run --rm -it `
	-v ${PWD}:/workspace `
	-w /workspace `
	ghcr.io/tooark/terraform:latest terraform init
```

Executar planos e applies (exemplo):

```powershell
docker run --rm -it `
	-v ${PWD}:/workspace `
	-w /workspace `
	ghcr.io/tooark/terraform:latest terraform plan
```

> Dica: Para cache de plugins/providers entre execuções, monte um diretório persistente em `/home/app/.terraform.d`.

## Variantes de tag

- `terraform:<major>.<minor>.<patch>`: versão exata do Terraform (ex.: `1.14.0`).
- `terraform:<major>.<minor>`: acompanha a última patch daquela série (ex.: `1.14`).
- `terraform:latest`: aponta para a última versão estável construída.

Use a variante que atenda ao seu requisito de estabilidade. Para pipelines reprodutíveis, prefira a versão completa.

## Como verificar versões dentro da imagem

Sobrescreva o entrypoint para executar um shell e checar versões/pacotes:

```powershell
docker run --rm --entrypoint sh ghcr.io/tooark/terraform:latest -c "terraform version; dpkg -l | grep -E 'ca-certificates'"
```

## Multi-arquitetura

A imagem é construída para linux/amd64 e linux/arm64. O `Dockerfile` detecta `TARGETARCH` e baixa o binário adequado do Terraform para a arquitetura alvo.

- Imagem base configurável via `--build-arg BASE_IMAGE` (padrão: `debian:12-slim`).
- Versão do Terraform definida via `--build-arg TERRAFORM_VERSION` (obrigatório no build).

## Notas de build (opcional)

Ao construir localmente, publique múltiplas tags equivalentes à mesma imagem (versão completa, curta e `latest`). Exemplo simplificado com Docker (PowerShell):

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

- [TERRAFORM](https://developer.hashicorp.com/terraform/install#linux)
  - [Notas de lançamento](https://github.com/hashicorp/terraform/releases)

## Licença

MIT – ver arquivo `LICENSE` na raiz do repositório.
