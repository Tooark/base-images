# aws-cli

Esta imagem fornece o comando `aws` (AWS CLI v2) pronto para uso em pipelines e em containers ad-hoc. Este documento explica como usar a imagem gerada pelo build, incluindo as tags publicadas.

## Nome e tags da imagem

- Nome da imagem: `aws-cli` (nome da pasta)
- Tags publicadas por versão:
  - Versão completa: `aws-cli:2.31.38`
  - Versão curta (major.minor): `aws-cli:2.31`
  - Última estável: `aws-cli:latest`

Substitua os números de versão acima pelo valor correspondente à sua build.

## O que tem nesta imagem

| Ferramenta / item    | Versão / observação                                 | ARG (build)       |
| -------------------- | --------------------------------------------------- | ----------------- |
| Debian (imagem base) | `debian:12-slim` (padrão)                           | `BASE_IMAGE`      |
| AWS CLI (v2)         | Versão definida pela tag da imagem (ex.: `2.31.38`) | `PACKAGE_VERSION` |
| Binário disponível   | `aws` (em `/usr/local/bin`)                         | N/A               |
| Pacote de runtime    | `ca-certificates`                                   | N/A               |
| Usuário padrão       | `app` (não-root), HOME: `/home/app`                 | N/A               |

Observações:

- O usuário padrão é `app` e o HOME é `/home/app`.
- Não há `bash` na imagem; o shell padrão é `/bin/sh`.

## Uso rápido

Executar `aws --version` (CMD padrão):

```powershell
docker run --rm ghcr.io/tooark/aws-cli:latest --version
```

Executar um subcomando (ex.: `sts get-caller-identity`). Atenção: comandos que acessam a AWS exigem credenciais válidas.

```powershell
docker run --rm ghcr.io/tooark/aws-cli:latest sts get-caller-identity --no-cli-pager
```

### Passando credenciais ao container

- Variáveis de ambiente:

```powershell
docker run --rm `
	-e AWS_ACCESS_KEY_ID=$env:AWS_ACCESS_KEY_ID `
	-e AWS_SECRET_ACCESS_KEY=$env:AWS_SECRET_ACCESS_KEY `
	-e AWS_SESSION_TOKEN=$env:AWS_SESSION_TOKEN `
	-e AWS_REGION=us-east-1 `
	ghcr.io/tooark/aws-cli:latest sts get-caller-identity --no-cli-pager
```

- Montando o diretório de credenciais do host (`~/.aws`):

```powershell
# A imagem usa usuário não-root 'app'; monte em /home/app/.aws
docker run --rm `
	-v ${env:USERPROFILE}\.aws:/home/app/.aws:ro `
	ghcr.io/tooark/aws-cli:latest sts get-caller-identity --no-cli-pager
```

> No Windows PowerShell, `${env:USERPROFILE}\.aws` aponta para o diretório `.aws` do usuário local. O caminho destino dentro do container deve refletir o HOME do usuário `app` (`/home/app`).

## Variantes de tag

- `aws-cli:<major>.<minor>.<patch>`: versão exata do AWS CLI (ex.: `2.31.38`).
- `aws-cli:<major>.<minor>`: acompanha a última patch daquela série (ex.: `2.31`).
- `aws-cli:latest`: aponta para a última versão estável construída.

Use a variante que atenda ao seu requisito de estabilidade. Para pipelines reprodutíveis, prefira a versão completa.

## Como verificar versões dentro da imagem

Sobrescreva o entrypoint para executar um shell e checar versões:

```powershell
docker run --rm --entrypoint sh ghcr.io/tooark/aws-cli:latest -c "aws --version; dpkg -l | grep -E 'ca-certificates'"
```

Isso mostrará a versão do `aws` e listará a versão do pacote `ca-certificates` instalado via APT.

## Multi-arquitetura

A imagem é construída para linux/amd64 e linux/arm64. O `Dockerfile` detecta `TARGETARCH` e baixa o instalador adequado do AWS CLI v2 para a arquitetura alvo.

- Imagem base configurável via `--build-arg BASE_IMAGE` (padrão: `debian:12-slim`).
- Versão do AWS CLI definida via `--build-arg PACKAGE_VERSION` (obrigatório no build).

## Notas de build (opcional)

Ao construir localmente, publique múltiplas tags equivalentes à mesma imagem (versão completa, curta e `latest`). Exemplo simplificado com Docker (PowerShell):

```powershell
$version = "2.31.38"
$short = ($version -split '\\.')[0..1] -join '.'

docker build `
	--build-arg PACKAGE_VERSION=$version `
	-t aws-cli:$version `
	-t aws-cli:$short `
	-t aws-cli:latest `
	./aws-cli
```

## Licença

MIT – ver arquivo `LICENSE` na raiz do repositório.
