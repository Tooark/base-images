# gcloud-cli

Esta imagem fornece o Google Cloud SDK (`gcloud`, `gsutil`, `bq`) pronto para uso em pipelines e em containers ad-hoc. Este documento explica como usar a imagem gerada pelo build, incluindo as tags publicadas.

## Nome e tags da imagem

- Nome da imagem: `gcloud-cli` (nome da pasta)
- Tags publicadas por versão:
  - Versão completa: `gcloud-cli:548.0.0`
  - Versão curta (major.minor): `gcloud-cli:548.0`
  - Última estável: `gcloud-cli:latest`

Substitua os números de versão acima pelo valor correspondente à sua build.

## O que tem nesta imagem

| Ferramenta / item    | Versão / observação                                 | ARG (build)       |
| -------------------- | --------------------------------------------------- | ----------------- |
| Debian (imagem base) | `debian:12-slim` (padrão)                           | `BASE_IMAGE`      |
| Google Cloud SDK     | Versão definida pela tag da imagem (ex.: `548.0.0`) | `GCLOUD_VERSION` |
| Binários disponíveis | `gcloud`, `gsutil`, `bq` (em `/usr/local/bin`)      | N/A               |
| Pacotes de runtime   | `ca-certificates`, `bash`, `python3`                | N/A               |
| Usuário padrão       | `app` (não-root), HOME: `/home/app`                 | N/A               |

Observações:

- Prompts interativos são desabilitados por padrão: `CLOUDSDK_CORE_DISABLE_PROMPTS=1`.

## Uso rápido

Executar `gcloud --version`:

```powershell
docker run --rm ghcr.io/tooark/gcloud-cli:latest gcloud --version
```

Listar informações de configuração atuais (sem autenticar):

```powershell
docker run --rm ghcr.io/tooark/gcloud-cli:latest gcloud info
```

### Autenticação e credenciais

Em ambientes CI/CD, prefira contas de serviço. Duas formas comuns:

1. Variável `GOOGLE_APPLICATION_CREDENTIALS` apontando para um arquivo JSON montado:

```powershell
docker run --rm `
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/app/key.json `
  -v ${env:USERPROFILE}\\Downloads\\sa.json:/home/app/key.json:ro `
  gcloud-cli:latest gcloud auth activate-service-account --key-file=/home/app/key.json
```

Após a ativação, invoque comandos autenticados (ex.: listar buckets):

```powershell
docker run --rm `
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/app/key.json `
  -v ${env:USERPROFILE}\\Downloads\\sa.json:/home/app/key.json:ro `
  ghcr.io/tooark/gcloud-cli:latest gsutil ls -p meu-projeto
```

1. Autenticação ADC via `gcloud auth application-default activate-service-account` (equivalente para ADC):

```powershell
docker run --rm `
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/app/key.json `
  -v ${env:USERPROFILE}\\Downloads\\sa.json:/home/app/key.json:ro `
  ghcr.io/tooark/gcloud-cli:latest gcloud auth application-default activate-service-account --key-file=/home/app/key.json
```

Defina também projeto/região/zone via variáveis de ambiente quando necessário:

```powershell
docker run --rm `
  -e CLOUDSDK_CORE_PROJECT=meu-projeto `
  -e CLOUDSDK_COMPUTE_REGION=us-central1 `
  -e CLOUDSDK_COMPUTE_ZONE=us-central1-a `
  gcloud-cli:latest gcloud config list
```

> O usuário padrão é `app`; ao montar arquivos de credencial, use caminhos sob `/home/app` dentro do container.

## Variantes de tag

- `gcloud-cli:<major>.<minor>.<patch>`: versão exata do SDK (ex.: `548.0.0`).
- `gcloud-cli:<major>.<minor>`: acompanha a última patch daquela série (ex.: `548.0`).
- `gcloud-cli:latest`: aponta para a última versão estável construída.

Para pipelines reprodutíveis, prefira a versão completa.

## Como verificar versões dentro da imagem

Sobrescreva o entrypoint para executar um shell e checar versões:

```powershell
docker run --rm --entrypoint sh gcloud-cli:latest -c "gcloud --version; gsutil --version; bq version; dpkg -l | grep -E 'ca-certificates|bash|python3'"
```

## Multi-arquitetura

A imagem é construída para linux/amd64 e linux/arm64. O `Dockerfile` detecta `TARGETARCH` e baixa o artefato adequado do Google Cloud SDK para a arquitetura alvo.

- Imagem base configurável via `--build-arg BASE_IMAGE` (padrão: `debian:12-slim`).
- Versão do SDK definida via `--build-arg GCLOUD_VERSION` (obrigatório no build).

## Notas de build (opcional)

Ao construir localmente, publique múltiplas tags equivalentes à mesma imagem (versão completa, curta e `latest`). Exemplo simplificado com Docker (PowerShell):

```powershell
$version = "548.0.0"
$short = ($version -split '\\.')[0..1] -join '.'

docker build `
	--build-arg GCLOUD_VERSION=$version `
	-t gcloud-cli:$version `
	-t gcloud-cli:$short `
	-t gcloud-cli:latest `
	./gcloud-cli
```

## Licença

MIT – ver arquivo `LICENSE` na raiz do repositório.
