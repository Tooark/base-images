import json
import re
import urllib.request


def fetch_text(url, headers=None):
  req = urllib.request.Request(url, headers=headers or {
      "User-Agent": "tooark-version-bot"})
  
  with urllib.request.urlopen(req, timeout=30) as resp:
    return resp.read().decode("utf-8")


versions = {}

# AWS CLI v2 (changelog oficial)
aws_changelog = fetch_text(
    "https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst")
m = re.search(r"(?m)^(\d+\.\d+\.\d+)\s*$", aws_changelog)

if not m:
  raise RuntimeError("Could not parse AWSCLI_VERSION from changelog")

versions["AWSCLI_VERSION"] = m.group(1)

# Google Cloud SDK (canal rapid em JSON oficial)
gcloud_components = json.loads(
    fetch_text(
        "https://dl.google.com/dl/cloudsdk/channels/rapid/components-2.json")
)
gcloud_version = gcloud_components.get("version")

if not gcloud_version:
  raise RuntimeError("Could not parse GCLOUD_VERSION from components-2.json")

versions["GCLOUD_VERSION"] = gcloud_version

# Kubernetes kubectl (release estável oficial)
stable_k8s = fetch_text("https://dl.k8s.io/release/stable.txt").strip()
versions["KUBECTL_VERSION"] = stable_k8s.lstrip("v")

# Terraform (API oficial da HashiCorp)
terraform_check = json.loads(
    fetch_text("https://checkpoint-api.hashicorp.com/v1/check/terraform")
)
tf_version = terraform_check.get("current_version")

if not tf_version:
  raise RuntimeError("Could not parse TERRAFORM_VERSION from checkpoint API")

versions["TERRAFORM_VERSION"] = tf_version

# Sonar Scanner CLI (GitHub Releases - latest stable)
sonar_release = json.loads(
    fetch_text(
        "https://api.github.com/repos/SonarSource/sonar-scanner-cli/releases/latest",
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "tooark-version-bot",
        },
    )
)
sonar_tag = sonar_release.get("tag_name", "").lstrip("v")

if not sonar_tag:
  raise RuntimeError("Could not parse SONAR_CLI_VERSION from Sonar Scanner releases")

versions["SONAR_CLI_VERSION"] = sonar_tag

# Docker CLI (GitHub Releases - latest stable)
docker_cli_release = json.loads(
    fetch_text(
        "https://api.github.com/repos/docker/cli/releases/latest",
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "tooark-version-bot",
        },
    )
)
docker_cli_tag = docker_cli_release.get("tag_name", "").lstrip("v")

if not docker_cli_tag:
  raise RuntimeError("Could not parse DOCKER_VERSION from Docker CLI releases")

versions["DOCKER_VERSION"] = docker_cli_tag

# Docker Buildx plugin (GitHub Releases - latest stable)
docker_buildx_release = json.loads(
    fetch_text(
        "https://api.github.com/repos/docker/buildx/releases/latest",
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "tooark-version-bot",
        },
    )
)
docker_buildx_tag = docker_buildx_release.get("tag_name", "").lstrip("v")

if not docker_buildx_tag:
  raise RuntimeError("Could not parse DOCKER_BUILDX_VERSION from Docker Buildx releases")

versions["DOCKER_BUILDX_VERSION"] = docker_buildx_tag

# Trivy (GitHub Releases - latest stable)
trivy_release = json.loads(
    fetch_text(
        "https://api.github.com/repos/aquasecurity/trivy/releases/latest",
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "tooark-version-bot",
        },
    )
)
versions["TRIVY_VERSION"] = trivy_release["tag_name"].lstrip("v")

# Hadolint (GitHub Releases - latest stable)
hadolint_release = json.loads(
    fetch_text(
        "https://api.github.com/repos/hadolint/hadolint/releases/latest",
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "tooark-version-bot",
        },
    )
)
versions["HADOLINT_VERSION"] = hadolint_release["tag_name"].lstrip("v")

with open("latest_versions.json", "w", encoding="utf-8") as f:
  json.dump(versions, f, indent=2, sort_keys=True)

print("Resolved versions:")

for k in sorted(versions):
  print(f"- {k}={versions[k]}")
