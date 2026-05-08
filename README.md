# base-images

Repositório com imagens base para CI/CD e automação de infraestrutura.

Cada subprojeto possui Dockerfile, versionamento e documentação própria.

## Subprojetos

| Subprojeto             | O que contém                                                  | Documentação                                                     |
| ---------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------- |
| `aws-cli`              | AWS CLI v2 + kubectl                                          | [aws-cli/README.md](aws-cli/README.md)                           |
| `gcloud-cli`           | Google Cloud SDK (`gcloud`, `gsutil`, `bq`) + kubectl         | [gcloud-cli/README.md](gcloud-cli/README.md)                     |
| `terraform`            | Terraform CLI                                                 | [terraform/README.md](terraform/README.md)                       |
| `terraform-aws`        | Terraform + AWS CLI v2 + kubectl                              | [terraform-aws/README.md](terraform-aws/README.md)               |
| `terraform-gcloud`     | Terraform + Google Cloud SDK + kubectl                        | [terraform-gcloud/README.md](terraform-gcloud/README.md)         |
| `terraform-aws-gcloud` | Terraform + AWS CLI v2 + Google Cloud SDK + kubectl           | [terraform-aws-gcloud/README.md](terraform-aws-gcloud/README.md) |
| `sonar-scanner`        | Sonar Scanner CLI para análises em pipelines CI/CD            | [sonar-scanner/README.md](sonar-scanner/README.md)               |
| `trivy-hadolint`       | Trivy + Hadolint + wrapper `ci-tools` para scans e relatórios | [trivy-hadolint/README.md](trivy-hadolint/README.md)             |
| `docker`               | Docker CLI + Buildx plugin para build multi-arquitetura       | [docker/README.md](docker/README.md)                             |

## Estrutura

- Cada pasta de subprojeto contém:
  - `Dockerfile`: definição da imagem
  - `VERSION`: versão do subprojeto
  - `DESCRIPTION`: resumo curto da imagem
  - `README.md`: uso, variáveis e exemplos
  - `.trivyignore`: exceções de CVE aceitas para o scan de segurança da imagem

## Versionamento e `.trivyignore`

O arquivo [versions.env](versions.env) centraliza as versões de todas as ferramentas e imagens.

A pasta `script/` contém os scripts de automação:

| Script                            | Função                                                        |
| --------------------------------- | ------------------------------------------------------------- |
| `fetch-latest-stable-versions.py` | Consulta as versões estáveis mais recentes de cada ferramenta |
| `update-versions.py`              | Atualiza `versions.env` e gerencia os arquivos `.trivyignore` |

### Gestão automática de `.trivyignore`

Quando o script `update-versions.py` detecta uma nova versão de ferramenta, ele:

1. **Limpa** o `.trivyignore` da imagem base atualizada (as exceções de CVE da versão anterior podem não ser mais válidas).
2. **Reconstrói** o `.trivyignore` das imagens compostas concatenando o conteúdo dos `.trivyignore` das suas dependências base.

| Imagem composta        | Dependências base                      |
| ---------------------- | -------------------------------------- |
| `terraform-aws`        | `terraform` + `aws-cli`                |
| `terraform-gcloud`     | `terraform` + `gcloud-cli`             |
| `terraform-aws-gcloud` | `terraform` + `aws-cli` + `gcloud-cli` |
| `trivy-hadolint`       | `trivy` + `hadolint`                   |

> Exemplo: se apenas `GCLOUD_VERSION` muda, o `.trivyignore` de `gcloud-cli/` é limpo. O `.trivyignore` de `terraform-gcloud/` é reconstruído apenas com o conteúdo de `terraform/.trivyignore` (gcloud agora está vazio).

## Observações

- A pasta `samples` pode conter exemplos auxiliares de uso para pipelines.
- Licença do projeto: [LICENSE](LICENSE).

## Exemplos prontos

- Guia com exemplos locais e instruções de uso: [samples/README.md](samples/README.md)
- Pipeline exemplo para GitHub Actions: [samples/github-actions-images.yml](samples/github-actions-images.yml)
- Pipeline exemplo para GitLab CI: [samples/gitlab-ci-images.yml](samples/gitlab-ci-images.yml)
