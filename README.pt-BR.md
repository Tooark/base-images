# Imagens Base

Repositório com imagens base para CI/CD e automação de infraestrutura.

Cada subprojeto possui Dockerfile, versionamento e documentação própria.

🌍 **Idiomas:** [![USA Flag](https://flagcdn.com/w20/us.png) English](https://github.com/Tooark/base-images/blob/main/README.md) · ![Brazil Flag](https://flagcdn.com/w20/br.png) **Português (este arquivo)**

---

## Sumário

- [Visão geral](#visão-geral)
- [Documentações das imagens](#documentações-das-imagens)
- [Exemplos prontos](#exemplos-prontos)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Versionamento e automação](#versionamento-e-automação)
- [Fluxo recomendado](#fluxo-recomendado)
- [Comunidade](#comunidade)
- [Licença](#licença)

---

## Visão geral

Este repositório centraliza imagens Docker para uso em pipelines e automações de infraestrutura.

Cada imagem mantém:

- Dockerfile com build reproduzível
- arquivo VERSION para controle de release
- DESCRIPTION com resumo funcional
- README com conteúdo da imagem, início rápido, exemplos de pipelines e build local

Todas as imagens compartilham a mesma base (`debian:13-slim`), rodam como usuário não-root (`app`) e usam o mesmo `docker-entrypoint.sh`, que ajusta o GID do `docker.sock` e faz o drop de privilégios via `gosu` em runtime.

---

## Documentações das imagens

| Subprojeto             | O que contém                                                                 | Documentação                                                     |
| ---------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `aws-cli`              | AWS CLI v2 + kubectl + Docker CLI + Buildx                                   | [aws-cli/README.md](aws-cli/README.md)                           |
| `dockerx`              | Docker CLI + Buildx plugin para build multi-arquitetura                      | [dockerx/README.md](dockerx/README.md)                           |
| `gcloud-cli`           | Google Cloud SDK (`gcloud`, `gsutil`, `bq`) + kubectl + Docker CLI + Buildx  | [gcloud-cli/README.md](gcloud-cli/README.md)                     |
| `tofu`                 | OpenTofu CLI                                                                 | [tofu/README.md](tofu/README.md)                                 |
| `tofu-aws`             | OpenTofu + AWS CLI v2 + kubectl                                              | [tofu-aws/README.md](tofu-aws/README.md)                         |
| `tofu-gcloud`          | OpenTofu + Google Cloud SDK + kubectl                                        | [tofu-gcloud/README.md](tofu-gcloud/README.md)                   |
| `tofu-aws-gcloud`      | OpenTofu + AWS CLI v2 + Google Cloud SDK + kubectl                           | [tofu-aws-gcloud/README.md](tofu-aws-gcloud/README.md)           |
| `security-scanner`     | Trivy + Hadolint + BetterLeaks + wrapper `ark-tools` para scans e relatórios | [security-scanner/README.md](security-scanner/README.md)         |
| `sonar-scanner`        | Sonar Scanner CLI para análises em pipelines CI/CD                           | [sonar-scanner/README.md](sonar-scanner/README.md)               |
| `terraform`            | Terraform CLI (deprecated)                                                   | [terraform/README.md](terraform/README.md)                       |
| `terraform-aws`        | Terraform + AWS CLI v2 + kubectl (deprecated)                                | [terraform-aws/README.md](terraform-aws/README.md)               |
| `terraform-gcloud`     | Terraform + Google Cloud SDK + kubectl (deprecated)                          | [terraform-gcloud/README.md](terraform-gcloud/README.md)         |
| `terraform-aws-gcloud` | Terraform + AWS CLI v2 + Google Cloud SDK + kubectl (deprecated)             | [terraform-aws-gcloud/README.md](terraform-aws-gcloud/README.md) |
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
  - `README.md`: uso, variáveis e exemplos (inglês)
  - `README.pt-BR.md`: a mesma documentação em português (mantida em sincronia)
  - `.trivyignore`: exceções de CVE aceitas para o scan de segurança da imagem

---

## Versionamento e automação

O arquivo [versions.env](versions.env) centraliza as versões de todas as ferramentas e imagens.

A pasta `script/` contém os scripts de automação:

| Script                            | Função                                                        |
| --------------------------------- | ------------------------------------------------------------- |
| `fetch-latest-stable-versions.py` | Consulta as versões estáveis mais recentes de cada ferramenta |
| `update-versions.py`              | Atualiza `versions.env` e gerencia os arquivos `.trivyignore` |

### Workflows de automação

Dois workflows do GitHub Actions conduzem o ciclo de release:

| Workflow                                                               | Função                                                                                                                                                                               |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [update-tool-versions.yml](.github/workflows/update-tool-versions.yml) | Roda semanalmente: consulta as versões estáveis mais recentes, atualiza `versions.env`, reseta os `.trivyignore` impactados e dispara o build das imagens                            |
| [image-build.yml](.github/workflows/image-build.yml)                   | Faz o build de cada imagem nova (amd64 + arm64), roda o scan completo de segurança, publica em `ghcr.io/tooark`, assina com **Cosign (keyless)** e cria a tag git e o GitHub Release |

Todas as imagens publicadas são assinadas com [Cosign](https://docs.sigstore.dev/cosign/verifying/verify/) via OIDC do GitHub Actions — consumidores podem verificar a assinatura antes de usar.

### Gestão automática de .trivyignore

Quando o script `update-versions.py` detecta uma nova versão de ferramenta, ele:

1. **Limpa e reinicializa** o `.trivyignore` de **todas as imagens impactadas** pela versão alterada.
2. **Não reconstrói nem herda automaticamente** exceções entre imagens.
3. Recria o arquivo com um cabeçalho padrão e data de revisão automática para o mantenedor adicionar manualmente apenas as CVEs aceitas para aquela versão.

> Exemplo: se `GCLOUD_VERSION` muda, o script limpa e recria `.trivyignore` de `gcloud-cli/`, `tofu-gcloud/`, `terraform-gcloud/` e `terraform-aws-gcloud/`. Nenhum desses arquivos recebe CVEs automaticamente.

---

## Fluxo recomendado

1. Escolha a imagem pelo catálogo em [Documentações das imagens](#documentações-das-imagens).
2. Siga o início rápido e as variáveis no README da imagem escolhida.
3. Use os exemplos em [samples/README.md](samples/README.md) e os arquivos dedicados do security-scanner para integração inicial.
4. Para releases e atualizações de versão, use os scripts da pasta [script/](script/).

---

## Comunidade

- 🤝 [Guia de contribuição](CONTRIBUTING.md) — como propor mudanças, build e scan local
- 📜 [Código de Conduta](CODE_OF_CONDUCT.md) — comportamento esperado dos contribuidores
- 🔒 [Política de segurança](SECURITY.md) — **reporte vulnerabilidades em privado**, nunca via issue pública
- 🙋 [Suporte](SUPPORT.md) — onde tirar dúvidas e pedir ajuda
- 💖 Apoie o projeto — [GitHub Sponsors](https://github.com/sponsors/paulosfjunior) · [Ko-fi](https://ko-fi.com/paulosfjunior)

---

## Licença

MIT - ver arquivo [LICENSE](LICENSE) na raiz do repositório.
