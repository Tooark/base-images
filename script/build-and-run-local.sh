#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/versions.env"

IMAGES=(
  aws-cli
  dockerx
  gcloud-cli
  tofu
  security-scanner
  sonar-scanner
  terraform
  terraform-aws
  terraform-gcloud
  terraform-aws-gcloud
  tofu-aws
  tofu-gcloud
  tofu-aws-gcloud
  trivy-hadolint
)

log() {
  printf '[base-images] %s\n' "$*"
}

usage() {
  cat <<'EOF'
Uso:
  ./script/build-and-run-local.sh [build|scan|all] [imagem|all]

Exemplos:
  ./script/build-and-run-local.sh all all
  ./script/build-and-run-local.sh build aws-cli
  ./script/build-and-run-local.sh scan terraform-aws

Imagens suportadas:
  aws-cli, dockerx, gcloud-cli, tofu, security-scanner, sonar-scanner,
  terraform, terraform-aws, terraform-gcloud, terraform-aws-gcloud,
  tofu-aws, tofu-gcloud, tofu-aws-gcloud, trivy-hadolint
EOF
}

is_valid_image() {
  local target="$1"
  local image

  for image in "${IMAGES[@]}"; do
    if [[ "${image}" == "${target}" ]]; then
      return 0
    fi
  done

  return 1
}

build_image() {
  local image="$1"

  case "${image}" in
    aws-cli)
      docker build \
        --build-arg AWSCLI_VERSION="${AWSCLI_VERSION}" \
        --build-arg KUBECTL_VERSION="${KUBECTL_VERSION}" \
        --build-arg DOCKER_VERSION="${DOCKER_VERSION}" \
        --build-arg DOCKER_BUILDX_VERSION="${DOCKER_BUILDX_VERSION}" \
        -t aws-cli:latest \
        "${ROOT_DIR}/aws-cli"
      ;;
    dockerx)
      docker build \
        --build-arg DOCKERX_VERSION="${DOCKERX_VERSION}" \
        --build-arg DOCKER_VERSION="${DOCKER_VERSION}" \
        --build-arg DOCKER_BUILDX_VERSION="${DOCKER_BUILDX_VERSION}" \
        -t dockerx:latest \
        "${ROOT_DIR}/dockerx"
      ;;
    gcloud-cli)
      docker build \
        --build-arg GCLOUD_VERSION="${GCLOUD_VERSION}" \
        --build-arg KUBECTL_VERSION="${KUBECTL_VERSION}" \
        --build-arg DOCKER_VERSION="${DOCKER_VERSION}" \
        --build-arg DOCKER_BUILDX_VERSION="${DOCKER_BUILDX_VERSION}" \
        -t gcloud-cli:latest \
        "${ROOT_DIR}/gcloud-cli"
      ;;
    tofu)
      docker build \
        --build-arg OPENTOFU_VERSION="${OPENTOFU_VERSION}" \
        -t tofu:latest \
        "${ROOT_DIR}/tofu"
      ;;
    security-scanner)
      docker build \
        --build-arg TRIVY_VERSION="${TRIVY_VERSION}" \
        --build-arg HADOLINT_VERSION="${HADOLINT_VERSION}" \
        --build-arg BETTERLEAKS_VERSION="${BETTERLEAKS_VERSION}" \
        --build-arg SECURITY_SCANNER_VERSION="${SECURITY_SCANNER_VERSION}" \
        -t security-scanner:latest \
        "${ROOT_DIR}/security-scanner"
      ;;
    sonar-scanner)
      docker build \
        --build-arg SONAR_CLI_VERSION="${SONAR_CLI_VERSION}" \
        -t sonar-scanner:latest \
        "${ROOT_DIR}/sonar-scanner"
      ;;
    terraform)
      docker build \
        --build-arg TERRAFORM_VERSION="${TERRAFORM_VERSION}" \
        -t terraform:latest \
        "${ROOT_DIR}/terraform"
      ;;
    terraform-aws)
      docker build \
        --build-arg TF_AWS_VERSION="${TF_AWS_VERSION}" \
        --build-arg TERRAFORM_VERSION="${TERRAFORM_VERSION}" \
        --build-arg AWSCLI_VERSION="${AWSCLI_VERSION}" \
        --build-arg KUBECTL_VERSION="${KUBECTL_VERSION}" \
        -t terraform-aws:latest \
        "${ROOT_DIR}/terraform-aws"
      ;;
    terraform-gcloud)
      docker build \
        --build-arg TF_GCLOUD_VERSION="${TF_GCLOUD_VERSION}" \
        --build-arg TERRAFORM_VERSION="${TERRAFORM_VERSION}" \
        --build-arg GCLOUD_VERSION="${GCLOUD_VERSION}" \
        --build-arg KUBECTL_VERSION="${KUBECTL_VERSION}" \
        -t terraform-gcloud:latest \
        "${ROOT_DIR}/terraform-gcloud"
      ;;
    terraform-aws-gcloud)
      docker build \
        --build-arg TF_AWS_GCLOUD_VERSION="${TF_AWS_GCLOUD_VERSION}" \
        --build-arg TERRAFORM_VERSION="${TERRAFORM_VERSION}" \
        --build-arg AWSCLI_VERSION="${AWSCLI_VERSION}" \
        --build-arg GCLOUD_VERSION="${GCLOUD_VERSION}" \
        --build-arg KUBECTL_VERSION="${KUBECTL_VERSION}" \
        -t terraform-aws-gcloud:latest \
        "${ROOT_DIR}/terraform-aws-gcloud"
      ;;
    tofu-aws)
      docker build \
        --build-arg TOFU_AWS_VERSION="${TOFU_AWS_VERSION}" \
        --build-arg OPENTOFU_VERSION="${OPENTOFU_VERSION}" \
        --build-arg AWSCLI_VERSION="${AWSCLI_VERSION}" \
        --build-arg KUBECTL_VERSION="${KUBECTL_VERSION}" \
        -t tofu-aws:latest \
        "${ROOT_DIR}/tofu-aws"
      ;;
    tofu-gcloud)
      docker build \
        --build-arg TOFU_GCLOUD_VERSION="${TOFU_GCLOUD_VERSION}" \
        --build-arg OPENTOFU_VERSION="${OPENTOFU_VERSION}" \
        --build-arg GCLOUD_VERSION="${GCLOUD_VERSION}" \
        --build-arg KUBECTL_VERSION="${KUBECTL_VERSION}" \
        -t tofu-gcloud:latest \
        "${ROOT_DIR}/tofu-gcloud"
      ;;
    tofu-aws-gcloud)
      docker build \
        --build-arg TOFU_AWS_GCLOUD_VERSION="${TOFU_AWS_GCLOUD_VERSION}" \
        --build-arg OPENTOFU_VERSION="${OPENTOFU_VERSION}" \
        --build-arg AWSCLI_VERSION="${AWSCLI_VERSION}" \
        --build-arg GCLOUD_VERSION="${GCLOUD_VERSION}" \
        --build-arg KUBECTL_VERSION="${KUBECTL_VERSION}" \
        -t tofu-aws-gcloud:latest \
        "${ROOT_DIR}/tofu-aws-gcloud"
      ;;
    trivy-hadolint)
      docker build \
        --build-arg TRIVY_VERSION="${TRIVY_VERSION}" \
        --build-arg HADOLINT_VERSION="${HADOLINT_VERSION}" \
        --build-arg TRIVY_HADOLINT_VERSION="${TRIVY_HADOLINT_VERSION}" \
        -t trivy-hadolint:latest \
        "${ROOT_DIR}/trivy-hadolint"
      ;;
    *)
      log "Imagem invalida: ${image}"
      return 1
      ;;
  esac
}

ensure_scanner_image() {
  if ! docker image inspect security-scanner:latest >/dev/null 2>&1; then
    log "Imagem security-scanner:latest nao encontrada. Buildando automaticamente..."
    build_image security-scanner
  fi
}

scan_image() {
  local image_name="$1"
  local image_ref="${image_name}:latest"
  local folder="${image_name}"
  local cache_dir="${HOME}/.cache/trivy-base-images"
  local reports_dir="${ROOT_DIR}/scan-reports/${folder}"

  mkdir -p "${cache_dir}" "${reports_dir}"

  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${cache_dir}":/home/app/.cache/trivy \
    -v "${ROOT_DIR}/${folder}":/workspace:ro \
    -v "${reports_dir}":/reports \
    -e TRIVY_CACHE_DIR=/home/app/.cache/trivy \
    -e TRIVY_FORMAT=table \
    -e TRIVY_EXIT_CODE=0 \
    security-scanner:latest \
    full-scan "${image_ref}" --path /workspace
}

main() {
  local action="${1:-all}"
  local selected="${2:-all}"
  local targets=()
  local image

  case "${action}" in
    build|scan|all)
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      log "Acao invalida: ${action}"
      usage
      exit 1
      ;;
  esac

  if [[ "${selected}" == "all" ]]; then
    targets=("${IMAGES[@]}")
  else
    if ! is_valid_image "${selected}"; then
      log "Imagem invalida: ${selected}"
      usage
      exit 1
    fi
    targets=("${selected}")
  fi

  case "${action}" in
    build)
      for image in "${targets[@]}"; do
        log "Buildando ${image}:latest"
        build_image "${image}"
      done
      ;;
    scan)
      ensure_scanner_image
      for image in "${targets[@]}"; do
        log "Executando scan local em ${image}:latest"
        scan_image "${image}"
      done
      ;;
    all)
      for image in "${targets[@]}"; do
        log "Buildando ${image}:latest"
        build_image "${image}"
      done
      ensure_scanner_image
      for image in "${targets[@]}"; do
        log "Executando scan local em ${image}:latest"
        scan_image "${image}"
      done
      ;;
  esac

  log "Concluido."
}

main "$@"
