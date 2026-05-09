# samples

Exemplos de uso das 9 imagens em tres cenários:

- uso local
- GitHub Actions
- GitLab CI

## Imagens cobertas

- ghcr.io/tooark/docker:latest
- ghcr.io/tooark/aws-cli:latest
- ghcr.io/tooark/gcloud-cli:latest
- ghcr.io/tooark/terraform:latest
- ghcr.io/tooark/terraform-aws:latest
- ghcr.io/tooark/terraform-gcloud:latest
- ghcr.io/tooark/terraform-aws-gcloud:latest
- ghcr.io/tooark/sonar-scanner:latest
- ghcr.io/tooark/trivy-hadolint:latest

## 1) Uso local (docker run)

### docker (dockerx)

```bash
docker run --rm ghcr.io/tooark/docker:latest docker --version
docker run --rm ghcr.io/tooark/docker:latest docker buildx version
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
docker run --rm ghcr.io/tooark/trivy-hadolint:latest ci-tools version
docker run --rm ghcr.io/tooark/trivy-hadolint:latest ci-tools image-scan nginx:latest
```

## 2) GitHub Actions

Arquivo completo de exemplo para as 9 imagens:

- [github-actions-images.yml](github-actions-images.yml)

Como usar:

1. Copie o arquivo para .github/workflows/base-images-sample.yml
2. Ajuste segredos e variaveis se for executar comandos autenticados (AWS/GCP)
3. Execute por push ou workflow_dispatch

## 3) GitLab CI

Arquivo completo de exemplo para as 9 imagens:

- [gitlab-ci-images.yml](gitlab-ci-images.yml)

Como usar:

1. Copie o conteudo para .gitlab-ci.yml (ou inclua como template)
2. Ajuste variaveis protegidas para credenciais AWS/GCP
3. Rode a pipeline

## Observacoes

- Os exemplos usam latest para simplificar. Em producao, prefira tags fixas.
- Para comandos autenticados, injete credenciais via variaveis do CI.
- O exemplo de trivy-hadolint pode baixar banco de vulnerabilidades na primeira execucao.
