# Arquivo docker-bake.hcl
# Define builds declarativos para múltiplas imagens e plataformas usando BuildKit.
# Permite: build multi-arquitetura, reutilização de variáveis, tagging consistente.
# Uso:
#   docker buildx bake               # constrói o grupo default (aws-cli + gcloud-cli)
#   docker buildx bake aws-cli       # constrói só AWS CLI
#   docker buildx bake --set target=aws-cli.args.PACKAGE_VERSION=2.17.45
# Para usar variáveis deste arquivo: altere abaixo ou gere dinamicamente via CLI.

variable "BASE_IMAGE" { default = "debian:12-slim" }
variable "AWSCLI_VERSION" { default = "" }
variable "GCLOUD_VERSION" { default = "" }

# Plataformas suportadas (ajuste conforme necessidade)
variable "PLATFORMS" { default = "linux/amd64,linux/arm64" }

# Convenção de tags:
# - Se versão vazia, gera tag "latest" + sufixo base opcional.
# - Se versão definida, inclui a versão.
function "aws_tags" {
  params = [version]
  result = version != "" ? ["tooark/aws-cli:" + version] : ["tooark/aws-cli:latest"]
}

group "default" {
  targets = ["aws-cli"]
}

target "aws-cli" {
  context    = "."
  dockerfile = "aws-cli/Dockerfile"
  args = {
    BASE_IMAGE      = BASE_IMAGE
    PACKAGE_VERSION = AWSCLI_VERSION
  }
  platforms = [PLATFORMS]
  tags      = aws_tags(AWSCLI_VERSION)
}
