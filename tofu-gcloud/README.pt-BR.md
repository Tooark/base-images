# tofu-gcloud

Imagem base com `tofu` (OpenTofu CLI), `gcloud`, `gsutil`, `bq` e `kubectl`, pronta para uso em pipelines e execuções ad-hoc em container.

> Esta é a substituta direta de `terraform-gcloud`. A família `terraform-gcloud` ficou legada e deve ser evitada em novos fluxos.

🌍 **Idiomas:** [![USA Flag](https://flagcdn.com/w20/us.png) English](https://github.com/Tooark/base-images/blob/main/tofu-gcloud/README.md) · ![Brazil Flag](https://flagcdn.com/w20/br.png) **Português (este arquivo)**

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

- **OpenTofu**, **Google Cloud SDK** e **kubectl** na mesma imagem
- Base Debian minimalista com usuário não-root
- Compatível com linux/amd64 e linux/arm64

---

## Tags da imagem

| Tag                                              | Descrição       |
| ------------------------------------------------ | --------------- |
| `ghcr.io/tooark/tofu-gcloud:<MAJOR.MINOR.PATCH>` | Versão completa |
| `ghcr.io/tooark/tofu-gcloud:<MAJOR.MINOR>`       | Versão curta    |
| `ghcr.io/tooark/tofu-gcloud:<MAJOR>`             | Major track     |
| `ghcr.io/tooark/tofu-gcloud:latest`              | Última estável  |

---

## Conteúdo da imagem

| Item                  | Descrição                                                      |
| --------------------- | -------------------------------------------------------------- |
| Base                  | `debian:13-slim`                                               |
| OpenTofu CLI          | `/usr/local/bin/tofu`                                          |
| Google Cloud SDK      | `/opt/google-cloud-sdk`                                        |
| kubectl               | `/usr/local/bin/kubectl`                                       |
| Symlink               | `gcloud`, `gsutil`, `bq` -> `/opt/google-cloud-sdk/bin/gcloud` |
| Runtime deps          | `ca-certificates`, `bash`, `python3`, `gosu`                   |
| Usuário padrão        | `app` (não-root)                                               |
| Identificador família | `ARK_IMAGE_FAMILY=tofu-gcloud`                                 |

---

## Início rápido

Verificar versões instaladas:

```bash
docker run --rm ghcr.io/tooark/tofu-gcloud:latest tofu version
docker run --rm ghcr.io/tooark/tofu-gcloud:latest gcloud --version
docker run --rm ghcr.io/tooark/tofu-gcloud:latest kubectl version --client
```

Inicializar diretório OpenTofu (monte seu código):

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu-gcloud:latest tofu init
```

Executar plan OpenTofu:

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu-gcloud:latest tofu plan
```

Listar projetos GCP (requer autenticação prévia):

```bash
docker run --rm \
  -v ${HOME}/.config/gcloud:/home/app/.config/gcloud:ro \
  ghcr.io/tooark/tofu-gcloud:latest gcloud projects list --format="table(projectId,name)"
```

Usar kubectl com kubeconfig montado:

```bash
docker run --rm \
  -v ${HOME}/.kube/config:/home/app/.kube/config:ro \
  ghcr.io/tooark/tofu-gcloud:latest kubectl get nodes --request-timeout=10s
```

---

## Variáveis de ambiente

### GCLOUD CLI

| Variável                         | Default | Descrição                                       |
| -------------------------------- | ------- | ----------------------------------------------- |
| `GOOGLE_APPLICATION_CREDENTIALS` | -       | Caminho para o arquivo JSON da conta de serviço |
| `CLOUDSDK_CORE_PROJECT`          | -       | Projeto padrão do GCP                           |
| `CLOUDSDK_COMPUTE_REGION`        | -       | Região padrão do GCP                            |
| `CLOUDSDK_COMPUTE_ZONE`          | -       | Zona padrão do GCP                              |

---

## Pipelines

### GitHub Actions

#### Exemplo básico (GH)

```yaml
name: Tofu GCP

on:
  push:
    branches: [main]
  pull_request:

jobs:
  tofu:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu-gcloud:latest
    env:
      GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Autenticar no GCP
        run: |
          echo "$GOOGLE_CREDENTIALS" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud config set project ${{ vars.GCP_PROJECT }}

      - name: Tofu Init
        run: tofu init

      - name: Tofu Plan
        run: tofu plan -out=tfplan

      - name: Tofu Apply
        if: github.ref == 'refs/heads/main'
        run: tofu apply tfplan
```

#### Exemplo com deployment em GKE (GH)

```yaml
name: Deploy to GKE

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu-gcloud:latest
    env:
      GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Auth + OpenTofu
        run: |
          echo "$GOOGLE_CREDENTIALS" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud config set project ${{ vars.GCP_PROJECT }}
          tofu init
          tofu apply -auto-approve

      - name: Configure kubectl and deploy
        run: |
          gcloud container clusters get-credentials ${{ vars.GKE_CLUSTER }} --zone ${{ vars.GKE_ZONE }}
          kubectl apply -f k8s/
```

---

## Build local

```bash
version="1.0.0"   # tofu-gcloud
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg TOFU_GCLOUD_VERSION=$version \
  --build-arg OPENTOFU_VERSION=1.12.1 \
  --build-arg GCLOUD_VERSION=571.0.0 \
  --build-arg KUBECTL_VERSION=1.36.1 \
  -t tofu-gcloud:$version \
  -t tofu-gcloud:$short \
  -t tofu-gcloud:latest \
  ./tofu-gcloud
```

---

## Documentação oficial

- [OpenTofu](https://opentofu.org/docs/)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)

---

## Licença

MIT - ver arquivo [LICENSE](../LICENSE) na raiz do repositório.

<!-- markdownlint-enable MD060 -->
