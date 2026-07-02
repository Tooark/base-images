# samples

🌐 **[English](README.md)** | **Português**

Exemplos de uso das imagens em três cenários:

- uso local
- GitHub Actions
- GitLab CI

## Imagens cobertas

- ghcr.io/tooark/dockerx:latest
- ghcr.io/tooark/aws-cli:latest
- ghcr.io/tooark/gcloud-cli:latest
- ghcr.io/tooark/terraform:latest
- ghcr.io/tooark/terraform-aws:latest
- ghcr.io/tooark/terraform-gcloud:latest
- ghcr.io/tooark/terraform-aws-gcloud:latest
- ghcr.io/tooark/sonar-scanner:latest
- ghcr.io/tooark/trivy-hadolint:latest
- ghcr.io/tooark/security-scanner:latest

## Exemplos dedicados: security-scanner

Arquivos completos para a imagem `security-scanner`:

- Uso local completo: [security-scanner-local.sh](security-scanner-local.sh)
- GitHub Actions completo: [security-scanner-github-actions.yml](security-scanner-github-actions.yml)
- GitLab CI completo: [security-scanner-gitlab-ci.yml](security-scanner-gitlab-ci.yml)

Esses exemplos cobrem:

- Todos os comandos principais (`image-scan`, `filesystem-scan`, `config-scan`, `repo-scan`, `dockerfile-lint`, `secret-scan`, `full-scan`)
- Flags de metadata (`--branch`, `--commit`, `--user`, `--repository|--repo`, `--tag`)
- Parâmetros específicos (`--sbom`, `--sbom-format`, `--no-git`, `--baseline`, `--path`, `--dockerfiles`, `--scan-mode`, `--skip-*`)
- Variáveis de ambiente de Trivy, Hadolint, Betterleaks, SBOM, Full-scan e Webhook

## 1) Uso local (docker run)

### docker (dockerx)

```bash
docker run --rm ghcr.io/tooark/dockerx:latest docker --version
docker run --rm ghcr.io/tooark/dockerx:latest docker buildx version
```

### aws-cli

```bash
docker run --rm ghcr.io/tooark/aws-cli:latest aws --version
docker run --rm ghcr.io/tooark/aws-cli:latest kubectl version --client
docker run --rm ghcr.io/tooark/aws-cli:latest docker --version
docker run --rm ghcr.io/tooark/aws-cli:latest docker buildx version
```

### gcloud-cli

```bash
docker run --rm ghcr.io/tooark/gcloud-cli:latest gcloud --version
docker run --rm ghcr.io/tooark/gcloud-cli:latest kubectl version --client
docker run --rm ghcr.io/tooark/gcloud-cli:latest docker --version
docker run --rm ghcr.io/tooark/gcloud-cli:latest docker buildx version
```

### terraform

```bash
docker run --rm ghcr.io/tooark/terraform:latest terraform version
```

### terraform-aws

```bash
docker run --rm ghcr.io/tooark/terraform-aws:latest terraform version
docker run --rm ghcr.io/tooark/terraform-aws:latest aws --version
docker run --rm ghcr.io/tooark/terraform-aws:latest kubectl version --client
```

### terraform-gcloud

```bash
docker run --rm ghcr.io/tooark/terraform-gcloud:latest terraform version
docker run --rm ghcr.io/tooark/terraform-gcloud:latest gcloud --version
docker run --rm ghcr.io/tooark/terraform-gcloud:latest kubectl version --client
```

### terraform-aws-gcloud

```bash
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest terraform version
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest aws --version
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest gcloud --version
docker run --rm ghcr.io/tooark/terraform-aws-gcloud:latest kubectl version --client
```

### sonar-scanner

```bash
docker run --rm ghcr.io/tooark/sonar-scanner:latest sonar-scanner --version
docker run --rm ghcr.io/tooark/sonar-scanner:latest java -version
```

### trivy-hadolint

```bash
docker run --rm ghcr.io/tooark/trivy-hadolint:latest version
docker run --rm \
  -v "$PWD/scan-reports":/reports \
  -e TRIVY_SEVERITY=HIGH,CRITICAL \
  -e TRIVY_SEVERITY_FAIL=HIGH,CRITICAL \
  ghcr.io/tooark/trivy-hadolint:latest \
  image-scan nginx:latest
docker run --rm \
  -v "$PWD":/workspace:ro \
  -v "$PWD/scan-reports":/reports \
  ghcr.io/tooark/trivy-hadolint:latest \
  container nginx:latest \
    --path /workspace \
    --branch "$(git rev-parse --abbrev-ref HEAD)" \
    --commit "$(git rev-parse HEAD)" \
    --repository "tooark/base-images"
```

## 2) GitHub Actions

Arquivo completo de exemplo para as 9 imagens:

- [github-actions-images.yml](github-actions-images.yml)

Como usar:

1. Copie o arquivo para .github/workflows/base-images-sample.yml
2. Ajuste segredos e variáveis se for executar comandos autenticados (AWS/GCP)
3. Execute por push ou workflow_dispatch

## 3) GitLab CI

Arquivo completo de exemplo para as 9 imagens:

- [gitlab-ci-images.yml](gitlab-ci-images.yml)

Como usar:

1. Copie o conteúdo para .gitlab-ci.yml (ou inclua como template)
2. Ajuste variáveis protegidas para credenciais AWS/GCP
3. Rode a pipeline

## Observações

- Os exemplos usam latest para simplificar. Em produção, prefira tags fixas.
- Para comandos autenticados, injete credenciais via variáveis do CI.
- Os exemplos de trivy-hadolint agora mostram como definir severidade/gate, persistir relatórios e informar metadata quando o comando roda via docker run.
- O exemplo de trivy-hadolint pode baixar banco de vulnerabilidades na primeira execução.
