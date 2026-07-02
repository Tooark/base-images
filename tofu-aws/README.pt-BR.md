# tofu-aws

Imagem base com `tofu` (OpenTofu CLI), `aws` (AWS CLI v2) e `kubectl`, pronta para uso em pipelines e execuções ad-hoc em container.

> Esta é a substituta direta de `terraform-aws`. A família `terraform-aws` ficou legada e deve ser evitada em novos fluxos.

🌍 **Idiomas:** [![USA Flag](https://flagcdn.com/w20/us.png) English](https://github.com/Tooark/base-images/blob/main/tofu-aws/README.md) · ![Brazil Flag](https://flagcdn.com/w20/br.png) **Português (este arquivo)**

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

- **OpenTofu**, **AWS CLI v2** e **kubectl** na mesma imagem
- Base Debian minimalista com usuário não-root
- Compatível com linux/amd64 e linux/arm64

---

## Tags da imagem

| Tag                                           | Descrição       |
| --------------------------------------------- | --------------- |
| `ghcr.io/tooark/tofu-aws:<MAJOR.MINOR.PATCH>` | Versão completa |
| `ghcr.io/tooark/tofu-aws:<MAJOR.MINOR>`       | Versão curta    |
| `ghcr.io/tooark/tofu-aws:<MAJOR>`             | Major track     |
| `ghcr.io/tooark/tofu-aws:latest`              | Última estável  |

---

## Conteúdo da imagem

| Item                  | Descrição                                                       |
| --------------------- | --------------------------------------------------------------- |
| Base                  | `debian:13-slim`                                                |
| OpenTofu CLI          | `/usr/local/bin/tofu`                                           |
| AWS CLI v2            | `/usr/local/aws-cli/v2/current/bin/aws`                         |
| kubectl               | `/usr/local/bin/kubectl`                                        |
| Symlink               | `/usr/local/bin/aws` -> `/usr/local/aws-cli/v2/current/bin/aws` |
| Runtime deps          | `ca-certificates`, `gosu`                                       |
| Usuário padrão        | `app` (não-root)                                                |
| Identificador família | `ARK_IMAGE_FAMILY=tofu-aws`                                     |

---

## Início rápido

Verificar versões instaladas:

```bash
docker run --rm ghcr.io/tooark/tofu-aws:latest tofu version
docker run --rm ghcr.io/tooark/tofu-aws:latest aws --version
docker run --rm ghcr.io/tooark/tofu-aws:latest kubectl version --client
```

Inicializar um diretório OpenTofu (monte seu código):

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu-aws:latest tofu init
```

Executar plan:

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu-aws:latest tofu plan
```

### Passando credenciais ao container

Por variáveis de ambiente:

```bash
docker run --rm \
  -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  -e AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
  -e AWS_REGION=us-east-1 \
  ghcr.io/tooark/tofu-aws:latest aws sts get-caller-identity --no-cli-pager
```

Usar `kubectl get` com kubeconfig montado:

```bash
docker run --rm \
  -v "$HOME/.kube/config:/home/app/.kube/config:ro" \
  ghcr.io/tooark/tofu-aws:latest kubectl get nodes --request-timeout=10s
```

Para usar `kubectl`, você também pode montar um kubeconfig em `/home/app/.kube/config`.

---

## Variáveis de ambiente

### AWS CLI

| Variável                | Default     | Descrição              |
| ----------------------- | ----------- | ---------------------- |
| `AWS_ACCESS_KEY_ID`     | -           | Chave de acesso da AWS |
| `AWS_SECRET_ACCESS_KEY` | -           | Chave secreta da AWS   |
| `AWS_SESSION_TOKEN`     | -           | Token de sessão da AWS |
| `AWS_REGION`            | `us-east-1` | Região padrão da AWS   |

---

## Pipelines

### GitHub Actions

#### Exemplo básico (GH)

```yaml
name: Tofu Deploy

on:
  push:
    branches: [main]
  pull_request:

jobs:
  tofu:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu-aws:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_REGION: us-east-1
    steps:
      - uses: actions/checkout@v4

      - name: Tofu Init
        run: tofu init

      - name: Tofu Plan
        run: tofu plan -out=tfplan

      - name: Tofu Apply
        if: github.ref == 'refs/heads/main'
        run: tofu apply tfplan
```

#### Exemplo com deployment em EKS (GH)

```yaml
name: Deploy to EKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu-aws:latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_REGION: us-east-1
    steps:
      - uses: actions/checkout@v4

      - name: Tofu Init
        run: tofu init

      - name: Tofu Plan
        run: tofu plan -out=tfplan

      - name: Tofu Apply
        if: github.ref == 'refs/heads/main'
        run: tofu apply tfplan

      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER }}
          kubectl apply -f k8s/

      - name: Verify deployment
        run: kubectl rollout status deployment/${{ vars.APP_NAME }} --timeout=120s
```

### GitLab CI

#### Exemplo básico (GL)

```yaml
stages:
  - validate
  - deploy

variables:
  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
  AWS_REGION: us-east-1

tofu_plan:
  stage: validate
  image: ghcr.io/tooark/tofu-aws:latest
  script:
    - tofu init
    - tofu validate
    - tofu plan -out=tfplan
  artifacts:
    paths:
      - tfplan
  only:
    - merge_requests
    - main

tofu_apply:
  stage: deploy
  image: ghcr.io/tooark/tofu-aws:latest
  script:
    - tofu init
    - tofu apply tfplan
  dependencies:
    - tofu_plan
  only:
    - main
  when: manual
```

---

## Build local

```bash
version="1.0.0"   # tofu-aws
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg TOFU_AWS_VERSION=$version \
  --build-arg OPENTOFU_VERSION=1.12.1 \
  --build-arg AWSCLI_VERSION=2.34.60 \
  --build-arg KUBECTL_VERSION=1.36.1 \
  -t tofu-aws:$version \
  -t tofu-aws:$short \
  -t tofu-aws:latest \
  ./tofu-aws
```

---

## Documentação oficial

- [OpenTofu](https://opentofu.org/docs/)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)

---

## Licença

MIT - ver arquivo [LICENSE](../LICENSE) na raiz do repositório.

<!-- markdownlint-enable MD060 -->
