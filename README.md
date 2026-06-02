# base-images

Repositório com imagens base para CI/CD e automação de infraestrutura.

Cada subprojeto possui Dockerfile, versionamento e documentação própria.

---

## Sumário

- [Visão geral](#visão-geral)
- [Documentações das imagens](#documentações-das-imagens)
- [Exemplos prontos](#exemplos-prontos)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Versionamento e automação](#versionamento-e-automação)
- [Fluxo recomendado](#fluxo-recomendado)
- [Licença](#licença)

---

## Visão geral

Este repositório centraliza imagens Docker para uso em pipelines e automações de infraestrutura.

Cada imagem mantém:

- Dockerfile com build reproduzível
- arquivo VERSION para controle de release
- DESCRIPTION com resumo funcional
- README com conteúdo da imagem, início rápido, exemplos de pipelines e build local

---

## Documentações das imagens

| Subprojeto             | O que contém                                                                 | Documentação                                                     |
| ---------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `aws-cli`              | AWS CLI v2 + kubectl                                                         | [aws-cli/README.md](aws-cli/README.md)                           |
| `dockerx`              | Docker CLI + Buildx plugin para build multi-arquitetura                      | [dockerx/README.md](dockerx/README.md)                           |
| `gcloud-cli`           | Google Cloud SDK (`gcloud`, `gsutil`, `bq`) + kubectl                        | [gcloud-cli/README.md](gcloud-cli/README.md)                     |
| `security-scanner`     | Trivy + Hadolint + BetterLeaks + wrapper `ark-tools` para scans e relatórios | [security-scanner/README.md](security-scanner/README.md)         |
| `sonar-scanner`        | Sonar Scanner CLI para análises em pipelines CI/CD                           | [sonar-scanner/README.md](sonar-scanner/README.md)               |
| `terraform`            | Terraform CLI                                                                | [terraform/README.md](terraform/README.md)                       |
| `terraform-aws`        | Terraform + AWS CLI v2 + kubectl                                             | [terraform-aws/README.md](terraform-aws/README.md)               |
| `terraform-gcloud`     | Terraform + Google Cloud SDK + kubectl                                       | [terraform-gcloud/README.md](terraform-gcloud/README.md)         |
| `terraform-aws-gcloud` | Terraform + AWS CLI v2 + Google Cloud SDK + kubectl                          | [terraform-aws-gcloud/README.md](terraform-aws-gcloud/README.md) |
| `trivy-hadolint`       | Trivy + Hadolint + wrapper `ark-tools` para scans e relatórios               | [trivy-hadolint/README.md](trivy-hadolint/README.md)             |

---

## Exemplos prontos

Use estes arquivos como ponto de partida para validação local e pipelines:

- Guia com exemplos locais e instruções de uso: [samples/README.md](samples/README.md)
- Pipeline de build/publicação no GitHub Actions: [samples/github-actions-images.yml](samples/github-actions-images.yml)
- Pipeline de build/publicação no GitLab CI: [samples/gitlab-ci-images.yml](samples/gitlab-ci-images.yml)

Exemplos dedicados para security-scanner:

- Execução local completa: [samples/security-scanner-local.sh](samples/security-scanner-local.sh)
- Pipeline completo no GitHub Actions: [samples/security-scanner-github-actions.yml](samples/security-scanner-github-actions.yml)
- Pipeline completo no GitLab CI: [samples/security-scanner-gitlab-ci.yml](samples/security-scanner-gitlab-ci.yml)

---

## Estrutura do repositório

- Cada pasta de subprojeto contém:
  - `Dockerfile`: definição da imagem
  - `VERSION`: versão do subprojeto
  - `DESCRIPTION`: resumo curto da imagem
  - `README.md`: uso, variáveis e exemplos
  - `.trivyignore`: exceções de CVE aceitas para o scan de segurança da imagem

---

## Versionamento e automação

O arquivo [versions.env](versions.env) centraliza as versões de todas as ferramentas e imagens.

A pasta `script/` contém os scripts de automação:

| Script                            | Função                                                        |
| --------------------------------- | ------------------------------------------------------------- |
| `fetch-latest-stable-versions.py` | Consulta as versões estáveis mais recentes de cada ferramenta |
| `update-versions.py`              | Atualiza `versions.env` e gerencia os arquivos `.trivyignore` |

### Gestão automática de .trivyignore

Quando o script `update-versions.py` detecta uma nova versão de ferramenta, ele:

1. **Limpa** o `.trivyignore` da imagem base atualizada (as exceções de CVE da versão anterior podem não ser mais válidas).
2. **Reconstrói** o `.trivyignore` das imagens compostas concatenando o conteúdo dos `.trivyignore` das suas dependências base.

| Imagem composta        | Dependências base                      |
| ---------------------- | -------------------------------------- |
| `security-scanner`     | `trivy` + `hadolint` + `betterleaks`   |
| `terraform-aws`        | `terraform` + `aws-cli`                |
| `terraform-gcloud`     | `terraform` + `gcloud-cli`             |
| `terraform-aws-gcloud` | `terraform` + `aws-cli` + `gcloud-cli` |
| `trivy-hadolint`       | `trivy` + `hadolint`                   |

> Exemplo: se apenas `GCLOUD_VERSION` muda, o `.trivyignore` de `gcloud-cli/` é limpo. O `.trivyignore` de `terraform-gcloud/` é reconstruído apenas com o conteúdo de `terraform/.trivyignore` (gcloud agora está vazio).

---

## Fluxo recomendado

1. Escolha a imagem pelo catálogo em [Documentações das imagens](#documentações-das-imagens).
2. Siga o início rápido e as variáveis no README da imagem escolhida.
3. Use os exemplos em [samples/README.md](samples/README.md) e os arquivos dedicados do security-scanner para integração inicial.
4. Para releases e atualizações de versão, use os scripts da pasta [script/](script/fetch-latest-stable-versions.py).

---

## Licença

MIT - ver arquivo [LICENSE](LICENSE) na raiz do repositório.
