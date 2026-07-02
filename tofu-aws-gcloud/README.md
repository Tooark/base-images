# tofu-aws-gcloud

Imagem base com `tofu` (OpenTofu CLI), `aws` (AWS CLI v2), `gcloud`, `gsutil`, `bq` e `kubectl`, pronta para uso em pipelines e execuções ad-hoc em container.

> Esta é a substituta direta de `terraform-aws-gcloud`. A família `terraform-aws-gcloud` ficou legada e deve ser evitada em novos fluxos.

<!-- markdownlint-disable MD060 -->

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

- **OpenTofu** com **AWS CLI**, **Google Cloud SDK** e **kubectl** na mesma imagem
- Base Debian minimalista com usuário não-root
- Compatível com linux/amd64 e linux/arm64

---

## Tags da imagem

| Tag                                                   | Descrição       |
| ----------------------------------------------------- | --------------- |
| `ghcr.io/tooark/tofu-aws-gcloud:<MAJOR.MINOR.PATCH>`  | Versão completa |
| `ghcr.io/tooark/tofu-aws-gcloud:<MAJOR.MINOR>`        | Versão curta    |
| `ghcr.io/tooark/tofu-aws-gcloud:<MAJOR>`              | Major track     |
| `ghcr.io/tooark/tofu-aws-gcloud:latest`               | Última estável  |

---

## Conteúdo da imagem

| Item                  | Descrição                                                       |
| --------------------- | --------------------------------------------------------------- |
| Base                  | `debian:13-slim`                                                |
| OpenTofu CLI         | `/usr/local/bin/tofu`                                            |
| AWS CLI v2            | `/usr/local/aws-cli/v2/current/bin/aws`                         |
| Google Cloud SDK      | `/opt/google-cloud-sdk`                                         |
| kubectl               | `/usr/local/bin/kubectl`                                        |
| Symlink               | `/usr/local/bin/aws` -> `/usr/local/aws-cli/v2/current/bin/aws` |
| Symlink               | `gcloud`, `gsutil`, `bq` -> `/opt/google-cloud-sdk/bin/gcloud`  |
| Runtime deps          | `ca-certificates`, `bash`, `python3`, `gosu`                    |
| Usuário padrão        | `app` (não-root)                                                |
| Identificador família | `ARK_IMAGE_FAMILY=tofu-aws-gcloud`                              |

---

## Início rápido

Verificar versões instaladas:

```bash
docker run --rm ghcr.io/tooark/tofu-aws-gcloud:latest tofu version
docker run --rm ghcr.io/tooark/tofu-aws-gcloud:latest aws --version
docker run --rm ghcr.io/tooark/tofu-aws-gcloud:latest gcloud --version
docker run --rm ghcr.io/tooark/tofu-aws-gcloud:latest kubectl version --client
```

Inicializar um diretório OpenTofu (monte seu código):

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu-aws-gcloud:latest tofu init
```

Executar plan:

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu-aws-gcloud:latest tofu plan
```

Listar projetos GCP (requer autenticação prévia):

```bash
docker run --rm \
  -v ${HOME}/.config/gcloud:/home/app/.config/gcloud:ro \
  ghcr.io/tooark/tofu-aws-gcloud:latest gcloud projects list --format="table(projectId,name)"
```

Usar kubectl com kubeconfig montado:

```bash
docker run --rm \
  -v ${HOME}/.kube/config:/home/app/.kube/config:ro \
  ghcr.io/tooark/tofu-aws-gcloud:latest kubectl get nodes --request-timeout=10s
```

### Passando credenciais ao container

Por variáveis de ambiente:

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID=$env:AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$env:AWS_SECRET_ACCESS_KEY \
  -e AWS_SESSION_TOKEN=$env:AWS_SESSION_TOKEN \
  -e AWS_REGION=us-east-1 \
  ghcr.io/tooark/tofu-aws-gcloud:latest aws sts get-caller-identity --no-cli-pager
```

Em ambientes CI/CD, prefira contas de serviço. Duas formas comuns:

Variável `GOOGLE_APPLICATION_CREDENTIALS` apontando para um arquivo JSON montado:

```bash
docker run --rm \
  -e GOOGLE_APPLICATION_CREDENTIALS=/home/app/key.json \
  -v "$HOME/tmp/sa.json:/home/app/key.json:ro" \
  ghcr.io/tooark/tofu-aws-gcloud:latest gcloud auth activate-service-account --key-file=/home/app/key.json
```

Definir projeto/região/zone via variáveis de ambiente:

```bash
docker run --rm \
  -e CLOUDSDK_CORE_PROJECT=meu-projeto \
  -e CLOUDSDK_COMPUTE_REGION=us-central1 \
  -e CLOUDSDK_COMPUTE_ZONE=us-central1-a \
  ghcr.io/tooark/tofu-aws-gcloud:latest gcloud config list
```

---

## Variáveis de ambiente

### AWS CLI

| Variável                | Default     | Descrição              |
| ----------------------- | ----------- | ---------------------- |
| `AWS_ACCESS_KEY_ID`     | -           | Chave de acesso da AWS |
| `AWS_SECRET_ACCESS_KEY` | -           | Chave secreta da AWS   |
| `AWS_SESSION_TOKEN`     | -           | Token de sessão da AWS |
| `AWS_REGION`            | `us-east-1` | Região padrão da AWS   |

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
name: OpenTofu MultiCloud

on:
  push:
    branches: [main]
  pull_request:

jobs:
  opentofu:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu-aws-gcloud:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Auth GCP
        run: |
          echo "$GOOGLE_CREDENTIALS" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud config set project ${{ vars.GCP_PROJECT }}

      - name: OpenTofu Init
        run: tofu init

      - name: OpenTofu Plan
        run: tofu plan -out=tfplan

      - name: OpenTofu Apply
        if: github.ref == 'refs/heads/main'
        run: tofu apply tfplan
```

### Exemplo com deploy em EKS e GKE (GH)

```yaml
name: Deploy MultiCluster

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu-aws-gcloud:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Auth GCP
        run: |
          echo "$GOOGLE_CREDENTIALS" > /tmp/sa.json
          gcloud auth activate-service-account --key-file=/tmp/sa.json
          gcloud config set project ${{ vars.GCP_PROJECT }}

      - name: OpenTofu Init
        run: tofu init

      - name: OpenTofu Plan
        run: tofu plan -out=tfplan

      - name: OpenTofu Apply
        if: github.ref == 'refs/heads/main'
        run: tofu apply tfplan

      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER }}
          kubectl apply -f k8s/

      - name: Deploy to GKE
        run: |
          gcloud container clusters get-credentials ${{ vars.GKE_CLUSTER }} --zone ${{ vars.GKE_ZONE }}
          kubectl apply -f k8s/
```

---

## Build local

```bash
version="1.0.0"   # tofu-aws-gcloud
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg TOFU_AWS_GCLOUD_VERSION=$version \
  --build-arg OPENTOFU_VERSION=1.12.1 \
  --build-arg AWSCLI_VERSION=2.34.60 \
  --build-arg GCLOUD_VERSION=571.0.0 \
  --build-arg KUBECTL_VERSION=1.36.1 \
  -t tofu-aws-gcloud:$version \
  -t tofu-aws-gcloud:$short \
  -t tofu-aws-gcloud:latest \
  ./tofu-aws-gcloud
```

---

## Documentação oficial

- [OpenTofu](https://opentofu.org/docs/)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)

---

## Licença

MIT - ver arquivo [LICENSE](../LICENSE) na raiz do repositório.

<!-- markdownlint-enable MD060 -->