# aws-cli

Esta imagem fornece o comando `aws` (AWS CLI v2) pronto para uso em pipelines e em containers ad-hoc. Este documento explica como usar a imagem gerada pelo build, incluindo as tags publicadas.

## Nome e tags da imagem

- Nome da imagem: `aws-cli` (nome da pasta)
- Tags publicadas por versão:
  - Versão completa: `aws-cli:2.32.3`
  - Versão curta (major.minor): `aws-cli:2.32`
  - Última estável: `aws-cli:latest`

Substitua os números de versão acima pelo valor correspondente à sua build.

## O que tem nesta imagem

| Ferramenta / item    | Versão / observação                                | ARG (build)       |
| -------------------- | -------------------------------------------------- | ----------------- |
| Debian (imagem base) | `debian:12-slim` (padrão)                          | `BASE_IMAGE`      |
| AWS CLI (v2)         | Versão definida pela tag da imagem (ex.: `2.32.3`) | `AWSCLI_VERSION`  |
| kubectl              | Versão definida via build arg (ex.: `1.34.2`)      | `KUBECTL_VERSION` |
| Binários disponíveis | `aws`, `kubectl` (ambos em `/usr/local/bin`)       | N/A               |
| Pacote(s) de runtime | `ca-certificates`                                  | N/A               |
| Usuário padrão       | `app` (não-root), HOME: `/home/app`                | N/A               |

Observações:

- O usuário padrão é `app` e o HOME é `/home/app`.
- Não há `bash` na imagem; o shell padrão é `/bin/sh`.
- Inclui também o cliente `kubectl`, permitindo interagir com clusters Kubernetes (ex.: EKS).

## Uso rápido

Executar `aws --version` (CMD padrão):

```powershell
docker run --rm ghcr.io/tooark/aws-cli:latest --version
```

Executar um subcomando (ex.: `sts get-caller-identity`). Atenção: comandos que acessam a AWS exigem credenciais válidas.

```powershell
docker run --rm ghcr.io/tooark/aws-cli:latest sts get-caller-identity --no-cli-pager
```

Ver versão do kubectl (cliente) e testar um comando simples (necessita acesso a um cluster válido):

```powershell
docker run --rm ghcr.io/tooark/aws-cli:latest kubectl version --client --short
```

Usar `kubectl get` com kubeconfig montado (exemplo):

```powershell
docker run --rm `
  -v C:\caminho\para\kubeconfig:/home/app/.kube/config:ro `
  ghcr.io/tooark/aws-cli:latest kubectl get nodes --request-timeout=10s
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

Para usar `kubectl` você também pode montar um kubeconfig em `/home/app/.kube/config`.

## Variantes de tag

- `aws-cli:<major>.<minor>.<patch>`: versão exata do AWS CLI (ex.: `2.32.3`).
- `aws-cli:<major>.<minor>`: acompanha a última patch daquela série (ex.: `2.32`).
- `aws-cli:latest`: aponta para a última versão estável construída.

Use a variante que atenda ao seu requisito de estabilidade. Para pipelines reprodutíveis, prefira a versão completa.

## Como verificar versões dentro da imagem

Sobrescreva o entrypoint para executar um shell e checar versões:

```powershell
docker run --rm --entrypoint sh ghcr.io/tooark/aws-cli:latest -c "aws --version; kubectl version --client --short; dpkg -l | grep -E 'ca-certificates'"
```

Isso mostrará a versão do `aws` e listará a versão do pacote `ca-certificates` instalado via APT.

## Multi-arquitetura

A imagem é construída para linux/amd64 e linux/arm64. O `Dockerfile` detecta `TARGETARCH` e baixa:

- O instalador adequado do AWS CLI v2
- O binário `kubectl` correspondente à arquitetura (amd64 ou arm64)

- Imagem base configurável via `--build-arg BASE_IMAGE` (padrão: `debian:12-slim`).
- Versão do AWS CLI definida via `--build-arg AWSCLI_VERSION` (obrigatório no build).

## Notas de build (opcional)

Ao construir localmente, publique múltiplas tags equivalentes à mesma imagem (versão completa, curta e `latest`). Forneça ambos os ARGs (`AWSCLI_VERSION` e `KUBECTL_VERSION`). Exemplo simplificado com Docker (PowerShell):

```powershell
$version = "2.32.3"          # AWS CLI
$kubectl = "1.34.2"          # kubectl
$short = ($version -split '\\.') [0..1] -join '.'

docker build `
  --build-arg AWSCLI_VERSION=$version `
  --build-arg KUBECTL_VERSION=$kubectl `
  -t aws-cli:$version `
  -t aws-cli:$short `
  -t aws-cli:latest `
  ./aws-cli
```

## Documentação oficial

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [Notas de lançamento](https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Notas de lançamento](https://kubernetes.io/releases/)

## Licença

MIT – ver arquivo `LICENSE` na raiz do repositório.
