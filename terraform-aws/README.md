# terraform-aws

Imagem base para pipelines que precisam de Terraform, AWS CLI v2 e kubectl juntos, em ambiente mínimo (Debian slim) multi-arquitetura (linux/amd64 e linux/arm64). Este README reflete o conteúdo do `Dockerfile` da pasta `terraform-aws`.

## Nome e tags

- Nome da imagem: `terraform-aws` (nome da pasta)
- Tags sugeridas (exemplos):
  - Composta: `terraform-aws:1.32.34` (terraform-aws-cli-kubectl)
  - Focada em Terraform: `terraform-aws:1.0`
  - Última estável: `terraform-aws:latest`

Escolha a estratégia de tagging que atenda à política de reprodutibilidade do seu pipeline. O `Dockerfile` aceita um ARG agregador `TF_AWS_VERSION` para rotular a imagem (label `org.opencontainers.image.version`).

## Conteúdo da imagem

| Item / ferramenta | Observação / versão (exemplo)                     | ARG (build)         |
| ----------------- | ------------------------------------------------- | ------------------- |
| Base (Debian)     | `debian:12-slim` (padrão, configurável)           | `BASE_IMAGE`        |
| Terraform         | Versão exata (ex.: `1.14.0`)                      | `TERRAFORM_VERSION` |
| AWS CLI v2        | Versão exata (ex.: `2.31.38`)                     | `AWSCLI_VERSION`    |
| kubectl           | Versão exata (ex.: `1.34.2`)                      | `KUBECTL_VERSION`   |
| Label de pacote   | Versão agregada p/ metadados (ex.: `1.32.34`)     | `TF_AWS_VERSION`    |
| Pacotes runtime   | `ca-certificates`                                 | N/A                 |
| Binários          | `terraform`, `aws`, `kubectl` em `/usr/local/bin` | N/A                 |
| Usuário padrão    | `app` (não-root), HOME: `/home/app`               | N/A                 |
| Shell padrão      | `/bin/sh` (não inclui `bash`)                     | N/A                 |

Observações:

- `aws` é symlink para `/usr/local/aws-cli/v2/current/bin/aws`.
- Terraform é instalado como binário único.
- kubectl é baixado diretamente para a arquitetura alvo.

## Variáveis de ambiente (pré-configuradas)

| Variável           | Valor                    | Finalidade                                       |
| ------------------ | ------------------------ | ------------------------------------------------ |
| `TF_IN_AUTOMATION` | `1`                      | Ajusta saída e comportamento para modo automação |
| `TF_INPUT`         | `0`                      | Prevê não-interatividade                         |
| `TF_CLI_ARGS`      | `-input=false -no-color` | Flags extras aplicadas globalmente               |

Você pode sobrescrever qualquer uma no `docker run -e VAR=...` conforme necessário.

## Uso rápido

Executar `aws --version` (CMD padrão):

```powershell
docker run --rm ghcr.io/tooark/terraform-aws:latest terraform -version
docker run --rm ghcr.io/tooark/terraform-aws:latest aws --version
docker run --rm ghcr.io/tooark/terraform-aws:latest kubectl version --client --short
```

Inicializar um diretório Terraform (montando código local):

```powershell
docker run --rm -v C:\caminho\para\infra:/work -w /work ghcr.io/tooark/terraform-aws:latest terraform init
```

Plano Terraform não interativo:

```powershell
docker run --rm
  -v C:\caminho\para\infra:/work
  -w /work
  ghcr.io/tooark/terraform-aws:latest terraform plan -no-color
```

Chamada AWS STS (credenciais necessárias):

```powershell
docker run --rm `
  -e AWS_ACCESS_KEY_ID=$env:AWS_ACCESS_KEY_ID `
  -e AWS_SECRET_ACCESS_KEY=$env:AWS_SECRET_ACCESS_KEY `
  -e AWS_SESSION_TOKEN=$env:AWS_SESSION_TOKEN `
  -e AWS_REGION=us-east-1 `
  ghcr.io/tooark/terraform-aws:latest aws sts get-caller-identity --no-cli-pager
```

kubectl com kubeconfig montado:

```powershell
docker run --rm `
  -v C:\caminho\para\kubeconfig:/home/app/.kube/config:ro `
  ghcr.io/tooark/terraform-aws:latest kubectl get nodes --request-timeout=10s
```

## Credenciais & volumes

- AWS: monte `${env:USERPROFILE}\.aws` em `/home/app/.aws` (somente leitura recomendado).
- Terraform state remoto: configure via backend nos `.tf` (nenhuma alteração especial na imagem).
- kubeconfig: `/home/app/.kube/config`.

## Multi-arquitetura

Suporta `linux/amd64` e `linux/arm64`. O `Dockerfile` usa `TARGETARCH` para escolher:

- Arquivo de Terraform correto (`terraform_<ver>_<arch>.zip`)
- Instalador AWS CLI (`awscli-exe-<arch>-<ver>.zip`)
- Binário `kubectl` apropriado

## Verificação interna (debug rápido)

```powershell
docker run --rm --entrypoint sh ghcr.io/tooark/terraform-aws:latest -c "terraform -version; aws --version; kubectl version --client --short; dpkg -l | grep -E 'ca-certificates'"
```

## Build local (exemplo PowerShell)

```powershell
$tf = "1.14.0"              # Terraform
$aws = "2.31.38"            # AWS CLI v2
$kube = "1.34.2"            # kubectl
$bundle = "$tf-$aws-$kube"  # Versão agregada

docker build `
  --build-arg TERRAFORM_VERSION=$tf `
  --build-arg AWSCLI_VERSION=$aws `
  --build-arg KUBECTL_VERSION=$kube `
  --build-arg TF_AWS_VERSION=$bundle `
  -t terraform-aws:$bundle `
  -t terraform-aws:$tf `
  -t terraform-aws:latest `
  ./terraform-aws
```

Adapte a estratégia de tags conforme sua política (por exemplo, manter só a agregada + `latest`).

## ARGs obrigatórios

| ARG                 | Obrigatório  | Exemplo          | Comentário                             |
| ------------------- | ------------ | ---------------- | -------------------------------------- |
| `TF_AWS_VERSION`    | Sim          | `1.32.34`        | Usado em label/metadados               |
| `TERRAFORM_VERSION` | Sim          | `1.14.0`         | Versão HashiCorp oficial               |
| `AWSCLI_VERSION`    | Sim          | `2.31.38`        | Versão AWS CLI v2 completa             |
| `KUBECTL_VERSION`   | Sim          | `1.34.2`         | Versão cliente Kubernetes              |
| `BASE_IMAGE`        | Não (padrão) | `debian:12-slim` | Pode ser ajustado p/ imagem compatível |

## Segurança & execução

- Usuário não-root `app` minimiza risco em pipelines.
- Apenas pacotes mínimos: reduz superfície de ataque.
- Sem `bash`; scripts devem ser POSIX sh ou binários.

## Documentação oficial

- [TERRAFORM](https://developer.hashicorp.com/terraform/install#linux)
  - [Notas de lançamento](https://github.com/hashicorp/terraform/releases)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [Notas de lançamento](https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Notas de lançamento](https://kubernetes.io/releases/)

## Licença

MIT – ver arquivo `LICENSE` na raiz do repositório.
