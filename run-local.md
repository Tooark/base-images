# Comandos

## Security Scanner

### Build the security scanner image

```bash
version="1.0.0"      # Security Scanner
trivy="0.72.0"       # Trivy
hadolint="2.14.0"    # Hadolint
betterleaks="1.6.1"  # Betterleaks
short="1"

docker build \
  --build-arg TRIVY_VERSION=$trivy \
  --build-arg HADOLINT_VERSION=$hadolint \
  --build-arg BETTERLEAKS_VERSION=$betterleaks \
  --build-arg SECURITY_SCANNER_VERSION=$version \
  -t "security-scanner:$short" \
  ./security-scanner
```

### Run the security scanner

```bash
docker run --rm -v "$PWD":/workspace \
  security-scanner:latest \
  full-scan myapp:latest --path /workspace
```

## AWS CLI

### Build the AWS CLI image

```bash
# Variables for versions of tools
aws_cli="2.35.13"         # AWS CLI
gcloud_cli="575.0.0"      # GCloud CLI
kubectl="1.36.2"          # kubectl
terraform="1.15.7"        # Terraform
tofu="1.12.3"             # OpenTofu
trivy="0.72.0"            # Trivy
hadolint="2.14.0"         # Hadolint
sonar="8.1.0.6389"        # Sonar Scanner
docker="29.6.1"           # Docker CLI
buildx="0.35.0"           # Buildx
betterleaks="1.6.1"       # Betterleaks
tf_aws="1.7.0"            # Terraform AWS Provider
tofu_aws="1.7.0"          # OpenTofu AWS Provider
tf_gcloud="4.70.0"        # Terraform GCloud Provider
tofu_gcloud="4.70.0"      # OpenTofu GCloud Provider
tf_aws_gcloud="1.7.0"     # Terraform AWS + GCloud Provider
tofu_aws_gcloud="1.7.0"   # OpenTofu AWS + GCloud Provider
trivy_hadolint="0.72.0"   # Trivy + Hadolint
dockerx="29.6.1"          # Docker CLI + Buildx
security_scanner="1.0.0"  # Security Scanner

# Image AWS CLI
docker build \
  --build-arg AWSCLI_VERSION=$aws_cli \
  --build-arg KUBECTL_VERSION=$kubectl \
  --build-arg DOCKER_VERSION=$docker \
  --build-arg DOCKER_BUILDX_VERSION=$buildx \
  -t aws-cli:latest \
  ./aws-cli

# Image DockerX
docker build \
  --build-arg DOCKERX_VERSION=$dockerx \
  --build-arg DOCKER_VERSION=$docker \
  --build-arg DOCKER_BUILDX_VERSION=$buildx \
  -t dockerx:latest \
  ./dockerx

# Image GCloud CLI
docker build \
  --build-arg GCLOUD_VERSION=$gcloud_cli \
  --build-arg KUBECTL_VERSION=$kubectl \
  --build-arg DOCKER_VERSION=$docker \
  --build-arg DOCKER_BUILDX_VERSION=$buildx \
  -t gcloud-cli:latest \
  ./gcloud-cli

# Image OpenTofu
docker build \
  --build-arg OPENTOFU_VERSION=$tofu \
  -t tofu:latest \
  ./tofu`

# Image Security Scanner
docker build \
  --build-arg TRIVY_VERSION=$trivy \
  --build-arg HADOLINT_VERSION=$hadolint \
  --build-arg BETTERLEAKS_VERSION=$betterleaks \
  --build-arg SECURITY_SCANNER_VERSION=$security_scanner \
  -t security-scanner:latest \
  ./security-scanner

# Image Sonar Scanner
docker build \
  --build-arg SONAR_CLI_VERSION="$sonar" \
  -t sonar-scanner:latest \
  ./sonar-scanner

# Image Terraform
docker build \
  --build-arg TERRAFORM_VERSION=$terraform \
  -t terraform:latest \
  ./terraform

# Image Terraform + AWS CLI
docker build \
  --build-arg TF_AWS_VERSION=$tf_aws \
  --build-arg TERRAFORM_VERSION=$terraform \
  --build-arg AWSCLI_VERSION=$aws_cli \
  --build-arg KUBECTL_VERSION=$kubectl \
  -t terraform-aws:latest \
  ./terraform-aws

# Image Terraform + GCloud CLI
docker build \
  --build-arg TF_GCLOUD_VERSION=$tf_gcloud \
  --build-arg TERRAFORM_VERSION=$terraform \
  --build-arg GCLOUD_VERSION=$gcloud_cli \
  --build-arg KUBECTL_VERSION=$kubectl \
  -t terraform-gcloud:latest \
  ./terraform-gcloud

# Image Terraform + AWS CLI + GCloud CLI
docker build \
  --build-arg TF_AWS_GCLOUD_VERSION=$tf_aws_gcloud \
  --build-arg TERRAFORM_VERSION=$terraform \
  --build-arg AWSCLI_VERSION=$aws_cli \
  --build-arg GCLOUD_VERSION=$gcloud_cli \
  --build-arg KUBECTL_VERSION=$kubectl \
  -t terraform-aws-gcloud:latest \
  ./terraform-aws-gcloud

# Image OpenTofu + AWS CLI
docker build \
  --build-arg TF_AWS_VERSION=$tf_aws \
  --build-arg OPENTOFU_VERSION=$tofu \
  --build-arg AWSCLI_VERSION=$aws_cli \
  --build-arg KUBECTL_VERSION=$kubectl \
  -t tofu-aws:latest \
  ./tofu-aws

# Image OpenTofu + GCloud CLI
docker build \
  --build-arg TF_GCLOUD_VERSION=$tf_gcloud \
  --build-arg OPENTOFU_VERSION=$tofu \
  --build-arg GCLOUD_VERSION=$gcloud_cli \
  --build-arg KUBECTL_VERSION=$kubectl \
  -t tofu-gcloud:latest \
  ./tofu-gcloud

# Image OpenTofu + AWS CLI + GCloud CLI
docker build \
  --build-arg TF_AWS_GCLOUD_VERSION=$tf_aws_gcloud \
  --build-arg OPENTOFU_VERSION=$tofu \
  --build-arg AWSCLI_VERSION=$aws_cli \
  --build-arg GCLOUD_VERSION=$gcloud_cli \
  --build-arg KUBECTL_VERSION=$kubectl \
  -t tofu-aws-gcloud:latest \
  ./tofu-aws-gcloud

# Image Trivy + Hadolint
docker build \
  --build-arg TRIVY_VERSION=$trivy \
  --build-arg HADOLINT_VERSION=$hadolint \
  --build-arg SECURITY_SCANNER_VERSION=$security_scanner \
  -t trivy-hadolint:latest \
  ./trivy-hadolint
```

### Run the scanner in the AWS CLI image

```bash
  image="aws-cli:latest"
  folder="${image##*/}"     # pega ultimo segmento (ex.: aws-cli:latest)
  folder="${folder%%:*}"    # remove tag (fica aws-cli)
  cache_dir="$HOME/.cache/trivy-base-images"

  mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$cache_dir":/home/app/.cache/trivy \
    -v "$PWD/$folder":/workspace:ro \
    -v "$PWD/scan-reports/$folder":/reports \
    -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
    -e TRIVY_FORMAT=table \
    security-scanner:1 \
    full-scan "$image" --path /workspace
```

### Run the scanner in the DockerX

```bash
image="dockerx:latest"
folder="${image##*/}"     # pega ultimo segmento (ex.: dockerx:latest)
folder="${folder%%:*}"    # remove tag (fica dockerx)
cache_dir="$HOME/.cache/trivy-base-images"

mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$cache_dir":/home/app/.cache/trivy \
  -v "$PWD/$folder":/workspace:ro \
  -v "$PWD/scan-reports/$folder":/reports \
  -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
  -e TRIVY_FORMAT=table \
  security-scanner:1 \
  full-scan "$image" --path /workspace
```

### Run the scanner in the GCloud CLI

```bash
image="gcloud-cli:latest"
folder="${image##*/}"     # pega ultimo segmento (ex.: gcloud-cli:latest)
folder="${folder%%:*}"    # remove tag (fica gcloud-cli)
cache_dir="$HOME/.cache/trivy-base-images"

mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$cache_dir":/home/app/.cache/trivy \
  -v "$PWD/$folder":/workspace:ro \
  -v "$PWD/scan-reports/$folder":/reports \
  -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
  -e TRIVY_FORMAT=table \
  security-scanner:1 \
  full-scan "$image" --path /workspace
```

### Run the scanner in the OpenTofu

```bash
image="tofu:latest"
folder="${image##*/}"     # pega ultimo segmento (ex.: tofu:latest)
folder="${folder%%:*}"    # remove tag (fica tofu)
cache_dir="$HOME/.cache/trivy-base-images"

mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$cache_dir":/home/app/.cache/trivy \
  -v "$PWD/$folder":/workspace:ro \
  -v "$PWD/scan-reports/$folder":/reports \
  -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
  -e TRIVY_FORMAT=table \
  security-scanner:1 \
  full-scan "$image" --path /workspace
```

### Run the scanner in the Security Scanner

```bash
image="security-scanner:latest"
folder="${image##*/}"     # pega ultimo segmento (ex.: security-scanner:latest)
folder="${folder%%:*}"    # remove tag (fica security-scanner)
cache_dir="$HOME/.cache/trivy-base-images"

mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$cache_dir":/home/app/.cache/trivy \
  -v "$PWD/$folder":/workspace:ro \
  -v "$PWD/scan-reports/$folder":/reports \
  -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
  -e TRIVY_FORMAT=table \
  security-scanner:1 \
  full-scan "$image" --path /workspace
```

### Run the scanner in the Sonar Scanner

```bash
image="sonar-scanner:latest"
folder="${image##*/}"     # pega ultimo segmento (ex.: sonar-scanner:latest)
folder="${folder%%:*}"    # remove tag (fica sonar-scanner)
cache_dir="$HOME/.cache/trivy-base-images"

mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$cache_dir":/home/app/.cache/trivy \
  -v "$PWD/$folder":/workspace:ro \
  -v "$PWD/scan-reports/$folder":/reports \
  -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
  -e TRIVY_FORMAT=table \
  security-scanner:1 \
  full-scan "$image" --path /workspace
```

### Run the scanner in the Terraform

```bash
  image="terraform:latest"
  folder="${image##*/}"     # pega ultimo segmento (ex.: terraform:latest)
  folder="${folder%%:*}"    # remove tag (fica terraform)
  cache_dir="$HOME/.cache/trivy-base-images"

  mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$cache_dir":/home/app/.cache/trivy \
    -v "$PWD/$folder":/workspace:ro \
    -v "$PWD/scan-reports/$folder":/reports \
    -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
    -e TRIVY_FORMAT=table \
    security-scanner:1 \
    full-scan "$image" --path /workspace
```

### Run the scanner in the Terraform and AWS CLI

```bash
  image="terraform-aws:latest"
  folder="${image##*/}"     # pega ultimo segmento (ex.: terraform-aws:latest)
  folder="${folder%%:*}"    # remove tag (fica terraform-aws)
  cache_dir="$HOME/.cache/trivy-base-images"

  mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$cache_dir":/home/app/.cache/trivy \
    -v "$PWD/$folder":/workspace:ro \
    -v "$PWD/scan-reports/$folder":/reports \
    -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
    -e TRIVY_FORMAT=table \
    security-scanner:1 \
    full-scan "$image" --path /workspace
```

### Run the scanner in the Terraform and GCloud CLI

```bash
  image="terraform-gcloud:latest"
  folder="${image##*/}"     # pega ultimo segmento (ex.: terraform-gcloud:latest)
  folder="${folder%%:*}"    # remove tag (fica terraform-gcloud)
  cache_dir="$HOME/.cache/trivy-base-images"

  mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$cache_dir":/home/app/.cache/trivy \
    -v "$PWD/$folder":/workspace:ro \
    -v "$PWD/scan-reports/$folder":/reports \
    -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
    -e TRIVY_FORMAT=table \
    security-scanner:1 \
    full-scan "$image" --path /workspace
```

### Run the scanner in the Terraform, AWS CLI and GCloud CLI

```bash
  image="terraform-aws-gcloud:latest"
  folder="${image##*/}"     # pega ultimo segmento (ex.: terraform-aws-gcloud:latest)
  folder="${folder%%:*}"    # remove tag (fica terraform-aws-gcloud)
  cache_dir="$HOME/.cache/trivy-base-images"

  mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$cache_dir":/home/app/.cache/trivy \
    -v "$PWD/$folder":/workspace:ro \
    -v "$PWD/scan-reports/$folder":/reports \
    -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
    -e TRIVY_FORMAT=table \
    security-scanner:1 \
    full-scan "$image" --path /workspace
```

### Run the scanner in the OpenTofu and AWS CLI

```bash
  image="tofu-aws:latest"
  folder="${image##*/}"     # pega ultimo segmento (ex.: tofu-aws:latest)
  folder="${folder%%:*}"    # remove tag (fica tofu-aws)
  cache_dir="$HOME/.cache/trivy-base-images"

  mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$cache_dir":/home/app/.cache/trivy \
    -v "$PWD/$folder":/workspace:ro \
    -v "$PWD/scan-reports/$folder":/reports \
    -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
    -e TRIVY_FORMAT=table \
    security-scanner:1 \
    full-scan "$image" --path /workspace
```

### Run the scanner in the OpenTofu and GCloud CLI

```bash
  image="tofu-gcloud:latest"
  folder="${image##*/}"     # pega ultimo segmento (ex.: tofu-gcloud:latest)
  folder="${folder%%:*}"    # remove tag (fica tofu-gcloud)
  cache_dir="$HOME/.cache/trivy-base-images"

  mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$cache_dir":/home/app/.cache/trivy \
    -v "$PWD/$folder":/workspace:ro \
    -v "$PWD/scan-reports/$folder":/reports \
    -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
    -e TRIVY_FORMAT=table \
    security-scanner:1 \
    full-scan "$image" --path /workspace
```

### Run the scanner in the OpenTofu, AWS CLI and GCloud CLI

```bash
  image="tofu-aws-gcloud:latest"
  folder="${image##*/}"     # pega ultimo segmento (ex.: tofu-aws-gcloud:latest)
  folder="${folder%%:*}"    # remove tag (fica tofu-aws-gcloud)
  cache_dir="$HOME/.cache/trivy-base-images"

  mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$cache_dir":/home/app/.cache/trivy \
    -v "$PWD/$folder":/workspace:ro \
    -v "$PWD/scan-reports/$folder":/reports \
    -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
    -e TRIVY_FORMAT=table \
    security-scanner:1 \
    full-scan "$image" --path /workspace
```

### Run the scanner in the Trivy and Hadolint

```bash
  image="trivy-hadolint:latest"
  folder="${image##*/}"     # pega ultimo segmento (ex.: trivy-hadolint:latest)
  folder="${folder%%:*}"    # remove tag (fica trivy-hadolint)
  cache_dir="$HOME/.cache/trivy-base-images"

  mkdir -p "$cache_dir" "$PWD/scan-reports/$folder"

  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$cache_dir":/home/app/.cache/trivy \
    -v "$PWD/$folder":/workspace:ro \
    -v "$PWD/scan-reports/$folder":/reports \
    -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
    -e TRIVY_FORMAT=table \
    security-scanner:1 \
    full-scan "$image" --path /workspace
```
