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
| `trivy-hadolint`       | Trivy + Hadolint + wrapper `ci-tools` para scans e relatórios | [trivy-hadolint/README.md](trivy-hadolint/README.md)             |

## Estrutura

- Cada pasta de subprojeto contém:
  - `Dockerfile`: definição da imagem
  - `VERSION`: versão do subprojeto
  - `DESCRIPTION`: resumo curto da imagem
  - `README.md`: uso, variáveis e exemplos

## Observações

- O arquivo [versions.env](versions.env) centraliza versões usadas no repositório.
- A pasta `samples` pode conter exemplos auxiliares de uso para pipelines.
- Licença do projeto: [LICENSE](LICENSE).

## Exemplos prontos

- Guia com exemplos locais e instruções de uso: [samples/README.md](samples/README.md)
- Pipeline exemplo para GitHub Actions (7 imagens): [samples/github-actions-7-images.yml](samples/github-actions-7-images.yml)
- Pipeline exemplo para GitLab CI (7 imagens): [samples/gitlab-ci-7-images.yml](samples/gitlab-ci-7-images.yml)
