import json
import re
import urllib.request


def fetch_text(url, accept=None, agent=None, headers=None, timeout=30):
  """
  Função para buscar o conteúdo de uma URL como texto.

  Args:
    url (str): A URL a ser buscada.
    headers (dict, opcional): Cabeçalhos HTTP adicionais a serem enviados na requisição.

  Returns:
    str: O conteúdo da resposta como texto.
  """

  head = headers or {"User-Agent": "tooark-version-bot"}

  if accept:
    head["Accept"] = accept
  if agent:
    head["User-Agent"] = agent

  req = urllib.request.Request(url, headers=head)

  with urllib.request.urlopen(req, timeout=timeout) as resp:
    return resp.read().decode("utf-8")


versions = {}

# AWS CLI v2 (changelog oficial)
aws_changelog = fetch_text("https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst")
m = re.search(r"(?m)^(\d+\.\d+\.\d+)\s*$", aws_changelog)

if not m:
  raise RuntimeError("Could not parse AWSCLI_VERSION from changelog")

versions["AWSCLI_VERSION"] = m.group(1)

# Google Cloud SDK (canal rapid em JSON oficial)
gcloud_components = json.loads(fetch_text("https://dl.google.com/dl/cloudsdk/channels/rapid/components-2.json"))
gcloud_version = gcloud_components.get("version")

if not gcloud_version:
  raise RuntimeError("Could not parse GCLOUD_VERSION from components-2.json")

versions["GCLOUD_VERSION"] = gcloud_version

# Kubernetes kubectl (release estável oficial)
stable_k8s = fetch_text("https://dl.k8s.io/release/stable.txt").strip()
versions["KUBECTL_VERSION"] = stable_k8s.lstrip("v")

# OpenTofu (GitHub Releases - latest stable)
response = fetch_text("https://api.github.com/repos/opentofu/opentofu/releases/latest", "application/vnd.github+json")
opentofu_release = json.loads(response)
opentofu_tag = opentofu_release.get("tag_name", "").lstrip("v")

if not opentofu_tag:
  raise RuntimeError("Could not parse OPENTOFU_VERSION from OpenTofu releases")

versions["OPENTOFU_VERSION"] = opentofu_tag

# Sonar Scanner CLI (GitHub Releases - latest stable)
response = fetch_text("https://api.github.com/repos/SonarSource/sonar-scanner-cli/releases/latest", "application/vnd.github+json")
sonar_release = json.loads(response)
sonar_tag = sonar_release.get("tag_name", "").lstrip("v")

if not sonar_tag:
  raise RuntimeError("Could not parse SONAR_CLI_VERSION from Sonar Scanner releases")

versions["SONAR_CLI_VERSION"] = sonar_tag

# Docker CLI (Release notes page - latest stable)
docker_docs = fetch_text("https://docs.docker.com/engine/release-notes/")

# Find the TableOfContents element
toc_match = re.search(r'<div\s+id=TableOfContents[^>]*>.*?</div>\s*</div>', docker_docs, re.DOTALL)

if not toc_match:
  raise RuntimeError("Could not find TableOfContents element in Docker release notes")

toc_content = toc_match.group(0)

# Extract all links text from <a> tags within the TOC
# Pattern: <a ...>VERSION_TEXT</a> where VERSION_TEXT is like 29.4.3
links_pattern = r'<a[^>]*>(\d+\.\d+\.\d+)</a>'
versions_found = re.findall(links_pattern, toc_content)

if not versions_found:
  raise RuntimeError("Could not find version links in TableOfContents")

# Get the first version (latest)
versions["DOCKER_VERSION"] = versions_found[0]

# Docker Buildx plugin (GitHub Releases - latest stable)
response=fetch_text("https://api.github.com/repos/docker/buildx/releases/latest", "application/vnd.github+json")
docker_buildx_release = json.loads(response)
docker_buildx_tag = docker_buildx_release.get("tag_name", "").lstrip("v")

if not docker_buildx_tag:
  raise RuntimeError("Could not parse DOCKER_BUILDX_VERSION from Docker Buildx releases")

versions["DOCKER_BUILDX_VERSION"] = docker_buildx_tag

# Trivy (GitHub Releases - latest stable)
response = fetch_text("https://api.github.com/repos/aquasecurity/trivy/releases/latest", "application/vnd.github+json")
trivy_release = json.loads(response)
versions["TRIVY_VERSION"] = trivy_release["tag_name"].lstrip("v")

# Hadolint (GitHub Releases - latest stable)
response = fetch_text("https://api.github.com/repos/hadolint/hadolint/releases/latest", "application/vnd.github+json")
hadolint_release = json.loads(response)
versions["HADOLINT_VERSION"] = hadolint_release["tag_name"].lstrip("v")

# Betterleaks (GitHub Releases - latest stable)
response = fetch_text("https://api.github.com/repos/betterleaks/betterleaks/releases/latest", "application/vnd.github+json")
betterleaks_release = json.loads(response)
betterleaks_tag = betterleaks_release.get("tag_name", "").lstrip("v")

if not betterleaks_tag:
  raise RuntimeError("Could not parse BETTERLEAKS_VERSION from Betterleaks releases")

versions["BETTERLEAKS_VERSION"] = betterleaks_tag

with open("latest_versions.json", "w", encoding="utf-8") as f:
  json.dump(versions, f, indent=2, sort_keys=True)

print("Resolved versions:")

for k in sorted(versions):
  print(f"- {k}={versions[k]}")
