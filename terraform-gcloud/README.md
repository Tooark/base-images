# terraform-gcloud

Imagem base para pipelines que precisam de Terraform, Google Cloud SDK (gcloud, gsutil, bq) e kubectl juntos, em ambiente mínimo (Debian slim) multi-arquitetura (`linux/amd64` e `linux/arm64`). Este README reflete o conteúdo do `Dockerfile` da pasta `terraform-gcloud`.

## Nome e tags

- Nome da imagem: `terraform-gcloud` (nome da pasta)
- Tags sugeridas (exemplos):
  - Composta agregada: `terraform-gcloud:1.547.34`
  - Focada em Terraform: `terraform-gcloud:1.14.0`
  - Última estável: `terraform-gcloud:latest`

O `Dockerfile` aceita um ARG agregador `TF_GCLOUD_VERSION` usado para a label `org.opencontainers.image.version`. Defina uma política de versionamento consistente (ex.: `terraformVersion-gcloudVersion-kubectlVersion`).

## Conteúdo da imagem

| Item / ferramenta         | Observação / versão (exemplo)                       | ARG (build)         |
| ------------------------- | --------------------------------------------------- | ------------------- |
| Base (Debian)             | `debian:12-slim` (padrão, configurável)             | `BASE_IMAGE`        |
| Terraform                 | Versão exata (ex.: `1.14.0`)                        | `TERRAFORM_VERSION` |
| Google Cloud SDK (gcloud) | Versão exata (ex.: `547.0.0`)                       | `GCLOUD_VERSION`    |
| kubectl                   | Versão exata (ex.: `1.34.2`)                        | `KUBECTL_VERSION`   |
| Label agregada            | Versão p/ metadados (ex.: `1.547.34`)               | `TF_GCLOUD_VERSION` |
| Pacotes runtime           | `ca-certificates bash python3`                      | N/A                 |
| Binários                  | `terraform`, `gcloud`, `gsutil`, `bq`, `kubectl`    | N/A                 |
| Symlinks                  | `gcloud`, `gsutil`, `bq` apontam para SDK em `/opt` | N/A                 |
| Usuário padrão            | `app` (não-root)                                    | N/A                 |
| Shell padrão (runtime)    | `/bin/bash`                                         | N/A                 |

Observações:

- Terraform é instalado como binário único em `/usr/local/bin/terraform`.
- Google Cloud SDK extraído para `/opt/google-cloud-sdk` (symlinks em `/usr/local/bin`).
- kubectl baixado diretamente para arquitetura alvo em `/usr/local/bin/kubectl`.

## Variáveis de ambiente (pré-configuradas)

| Variável                        | Valor                    | Finalidade                          |
| ------------------------------- | ------------------------ | ----------------------------------- |
| `TF_IN_AUTOMATION`              | `1`                      | Ajusta saída para modo automação    |
| `TF_INPUT`                      | `0`                      | Prevê não-interatividade            |
| `TF_CLI_ARGS`                   | `-input=false -no-color` | Flags extras globais do Terraform   |
| `CLOUDSDK_CORE_DISABLE_PROMPTS` | `1`                      | Evita prompts interativos do gcloud |
| `CLOUDSDK_PYTHON`               | `/usr/bin/python3`       | Força Python do sistema para SDK    |

Você pode sobrescrever qualquer variável com `docker run -e NOME=valor` conforme necessário.

## Uso rápido

Versões das ferramentas:

```powershell
docker run --rm ghcr.io/tooark/terraform-gcloud:latest terraform -version
docker run --rm ghcr.io/tooark/terraform-gcloud:latest gcloud --version
docker run --rm ghcr.io/tooark/terraform-gcloud:latest kubectl version --client --short
```

Inicializar diretório Terraform (montando código local):

```powershell
docker run --rm -v C:\caminho\para\infra:/work -w /work ghcr.io/tooark/terraform-gcloud:latest terraform init
```

Plano Terraform não interativo:

```powershell
docker run --rm
  -v C:\caminho\para\infra:/work
  -w /work
  ghcr.io/tooark/terraform-gcloud:latest terraform plan -no-color
```

Listar projetos GCP (requer autenticação prévia):

```powershell
docker run --rm `
  -v $env:USERPROFILE\.config\gcloud:/home/app/.config/gcloud:ro `
  ghcr.io/tooark/terraform-gcloud:latest gcloud projects list --format="table(projectId,name)"
```

kubectl com kubeconfig montado:

```powershell
docker run --rm `
-v C:\caminho\para\kubeconfig:/home/app/.kube/config:ro `
ghcr.io/tooark/terraform-gcloud:latest kubectl get nodes --request-timeout=10s
```

## Credenciais & volumes

- GCP: monte `${env:USERPROFILE}\.config\gcloud` em `/home/app/.config/gcloud` para reusar tokens e configurações (recomendado modo leitura se só consumir APIs).
- Terraform state remoto: configure via backend nos `.tf` (nenhuma alteração extra na imagem).
- kubeconfig: `/home/app/.kube/config`.

## Multi-arquitetura

Suporta `linux/amd64` e `linux/arm64`. O `Dockerfile` usa `TARGETARCH` para selecionar:

- Arquivo Terraform correto (`terraform_<ver>_linux_amd64|linux_arm64.zip`).
- Tarball do Google Cloud SDK (`google-cloud-sdk-<vers>-linux-x86_64|linux-arm.tar.gz`).
- Binário do kubectl (`.../bin/linux/amd64|arm64/kubectl`).

## Verificação interna (debug rápido)

```powershell
docker run --rm --entrypoint bash ghcr.io/tooark/terraform-gcloud:latest -c "terraform -version; gcloud --version; kubectl version --client --short; dpkg -l | grep -E 'ca-certificates'"
```

## Build local (exemplo PowerShell)

```powershell
$tf = "1.14.0"        # Terraform
$gcloud = "547.0.0"   # Google Cloud SDK
$kube = "1.34.2"      # kubectl
$bundle = "$tf-$gcloud-$kube"  # Versão agregada (TF_GCLOUD_VERSION)

docker build `
  --build-arg TERRAFORM_VERSION=$tf `
  --build-arg GCLOUD_VERSION=$gcloud `
  --build-arg KUBECTL_VERSION=$kube `
  --build-arg TF_GCLOUD_VERSION=$bundle `
  -t terraform-gcloud:$bundle `
  -t terraform-gcloud:$tf `
  -t terraform-gcloud:latest `
  ./terraform-gcloud
```

Adapte a estratégia de tags conforme sua política (ex.: manter só agregada + `latest`).

## ARGs obrigatórios

| ARG                 | Obrigatório | Exemplo          | Comentário                                 |
| ------------------- | ----------- | ---------------- | ------------------------------------------ |
| `TF_GCLOUD_VERSION` | Sim         | `1.547.34`       | Usado em label/metadados                   |
| `TERRAFORM_VERSION` | Sim         | `1.14.0`         | Versão HashiCorp oficial                   |
| `GCLOUD_VERSION`    | Sim         | `547.0.0`        | Versão exata do Google Cloud SDK           |
| `KUBECTL_VERSION`   | Sim         | `1.34.2`         | Versão cliente Kubernetes                  |
| `BASE_IMAGE`        | Não         | `debian:12-slim` | Pode ajustar para imagem compatível mínima |

## Segurança & execução

- Usuário não-root `app` reduz risco em pipelines.
- Pacotes mínimos instalados; menor superfície de ataque.
- Shell padrão é `bash` (útil para scripts do gcloud); manter scripts portáveis quando possível.

## Documentação oficial

- [Terraform](https://developer.hashicorp.com/terraform/install#linux)
  - [Notas de lançamento](https://github.com/hashicorp/terraform/releases)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
  - [Notas de lançamento](https://cloud.google.com/sdk/docs/release-notes)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Notas de lançamento](https://kubernetes.io/releases/)

## Licença

MIT – ver arquivo `LICENSE` na raiz do repositório.
