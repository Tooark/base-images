# aws-cli — uso da imagem

Esta imagem fornece o comando `aws` (AWS CLI v2) pronto para uso em pipelines e em containers ad-hoc. O objetivo deste documento é mostrar o que está disponível na imagem e como usá-la — não detalhes de manutenção ou do processo de build.

## O que tem nesta imagem

| Ferramenta / item    | Versão / observação         | ARG               |
| -------------------- | --------------------------- | ----------------- |
| Debian (imagem base) | `debian:12-slim`            | `BASE_IMAGE`      |
| AWS CLI              | `2.31.32`                   | `PACKAGE_VERSION` |
| ca-certificates      | pacote instalado no runtime | N/A               |
| bash                 | pacote instalado no runtime | N/A               |
| Usuário padrão       | `app` (não-root)            | N/A               |

**Observação:** as versões dos pacotes do sistema são as fornecidas pelo repositório do `debian:12-slim` no momento do build.

## Uso rápido

Executar o comando `aws --version` (CMD padrão):

```powershell
docker run --rm ghcr.io/tooark/aws-cli:latest --version
```

Executar um subcomando (ex.: sts get-caller-identity). Atenção: comandos que acessam a AWS exigem credenciais.

```powershell
docker run --rm ghcr.io/tooark/aws-cli:latest sts get-caller-identity --no-cli-pager
```

Passando credenciais ao container (opções comuns):

- Variáveis de ambiente:

```powershell
docker run --rm -e AWS_ACCESS_KEY_ID=$env:AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$env:AWS_SECRET_ACCESS_KEY -e AWS_REGION=us-east-1 ghcr.io/tooark/aws-cli:latest sts get-caller-identity --no-cli-pager
```

- Montando o arquivo de credenciais (~/.aws):

```powershell
# A imagem usa usuário não-root 'app'; monte em /home/app/.aws
docker run --rm -v ${env:USERPROFILE}\.aws:/home/app/.aws:ro ghcr.io/tooark/aws-cli:latest sts get-caller-identity --no-cli-pager
```

> Observação: no Windows PowerShell, `${env:USERPROFILE}\.aws` aponta para o diretório `.aws` do usuário local. O caminho destino dentro do container deve refletir o HOME do usuário 'app' (/home/app).

## Como verificar versões exatas dentro da imagem

Você pode sobrescrever o entrypoint para executar um shell e checar as versões instaladas. Exemplo:

```powershell
docker run --rm --entrypoint bash ghcr.io/tooark/aws-cli:latest -c "aws --version; dpkg -l | grep -E 'ca-certificates|bash'"
```

Isso mostrará a versão do `aws` e listará as versões dos pacotes de runtime principais instalados via APT.

## Multi-arquitetura

Esta imagem é construída para suportar linux/amd64 e linux/arm64. O `Dockerfile` detecta `TARGETARCH`/`TARGETPLATFORM` e baixa o instalador adequado do AWS CLI v2 para a arquitetura alvo.

- Imagem base configurável via `--build-arg BASE_IMAGE` (padrão: `debian:12-slim`).
- Versão do AWS CLI configurável via `--build-arg PACKAGE_VERSION`. Se omitido, a build usa a última versão disponível no site da AWS.

Use `docker buildx` para produzir e publicar manifestos multi-arch.

## Sobre este repositório

Este repositório (`base-images`) agrega Dockerfiles para imagens base utilitárias usadas em pipelines e ambientes de CI/CD da organização Tooark. A imagem `aws-cli` é publicada em: `ghcr.io/tooark/aws-cli`.

Tags típicas:

- `latest`: última build automatizada.
- Versão específica do CLI: `ghcr.io/tooark/aws-cli:<versão>` (ex.: `2.31.32`).

## Licença

MIT – ver arquivo `LICENSE` na raiz do repositório.
