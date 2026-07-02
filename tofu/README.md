# tofu

Imagem base com `tofu` (OpenTofu CLI) pronta para uso em pipelines e execuções ad-hoc em container.

> Esta é a imagem recomendada para novos fluxos. A família `terraform` ficou legada e será mantida apenas para compatibilidade.

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

- **OpenTofu CLI** pronto para execução em CI/CD
- Base Debian minimalista com usuário não-root
- Compatível com linux/amd64 e linux/arm64
- Mantém as variáveis de automação compatíveis com o fluxo de Terraform

---

## Tags da imagem

| Tag                                            | Descrição       |
| ---------------------------------------------- | --------------- |
| `ghcr.io/tooark/tofu:<MAJOR.MINOR.PATCH>`  | Versão completa |
| `ghcr.io/tooark/tofu:<MAJOR.MINOR>`        | Versão curta    |
| `ghcr.io/tooark/tofu:<MAJOR>`              | Major track     |
| `ghcr.io/tooark/tofu:latest`               | Última estável  |

## Conteúdo da imagem

| Item                  | Descrição                   |
| --------------------- | --------------------------- |
| Base                  | `debian:13-slim`            |
| OpenTofu CLI          | `/usr/local/bin/tofu`       |
| Runtime deps          | `ca-certificates`, `gosu`   |
| Usuário padrão        | `app` (não-root)            |
| Identificador família | `ARK_IMAGE_FAMILY=tofu` |

---

## Início rápido

Verificar a versão do OpenTofu:

```bash
docker run --rm ghcr.io/tooark/tofu:latest tofu version
```

Inicializar um diretório de trabalho (monte seu código):

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu:latest tofu init
```

Executar plan:

```bash
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  ghcr.io/tooark/tofu:latest tofu plan
```

> Dica: Para cache de providers entre execuções, monte um diretório persistente em `/home/app/.terraform.d`.

---

## Pipelines

### GitHub Actions

#### Exemplo básico (GH)

```yaml
name: OpenTofu

on:
  push:
    branches: [main]
  pull_request:

jobs:
  plan:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/tooark/tofu:latest
    steps:
      - uses: actions/checkout@v4

      - name: OpenTofu Init
        run: tofu init

      - name: OpenTofu Plan
        run: tofu plan -out=tfplan

      - name: OpenTofu Apply
        if: github.ref == 'refs/heads/main'
        run: tofu apply tfplan
```

### GitLab CI

#### Exemplo básico (GL)

```yaml
stages:
  - validate
  - deploy

opentofu_plan:
  stage: validate
  image: ghcr.io/tooark/tofu:latest
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

opentofu_apply:
  stage: deploy
  image: ghcr.io/tooark/tofu:latest
  script:
    - tofu init
    - tofu apply tfplan
  dependencies:
    - opentofu_plan
  only:
    - main
  when: manual
```

---

## Build local

```bash
version="1.12.1"   # OpenTofu
short="$(echo "$version" | cut -d. -f1,2)"

docker build \
  --build-arg OPENTOFU_VERSION=$version \
  -t tofu:$version \
  -t tofu:$short \
  -t tofu:latest \
  ./tofu
```

---

## Documentação oficial

- [OpenTofu](https://opentofu.org/docs/)
  - [Releases](https://github.com/opentofu/opentofu/releases)

---

## Licença

MIT - ver arquivo `LICENSE` na raiz do repositório.
