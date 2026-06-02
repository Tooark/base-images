import json
import os
import re


def parse_semver(version):
  """
  Função para analisar uma versão semântica no formato MAJOR.MINOR.PATCH.

  Args:
    version (str): A string de versão a ser analisada.

  Returns:
    tuple: Uma tupla (MAJOR, MINOR, PATCH) se a versão for válida, ou None se a versão não for válida.
  """

  m = re.match(r"^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$", version)

  if not m:
    return None

  return tuple(int(part) for part in m.groups())


def detect_change_level(old_version, new_version):
  """
  Função para detectar o nível de mudança (major, minor, patch) entre duas versões semânticas.

  Args:
    old_version (str): A versão antiga.
    new_version (str): A versão nova.

  Returns:
    str: O nível de mudança ("major", "minor", "patch") ou None se as versões não forem válidas ou se não houver mudança.
  """

  old_semver = parse_semver(old_version)
  new_semver = parse_semver(new_version)

  if old_semver is None or new_semver is None:
    return None

  old_major, old_minor, old_patch = old_semver
  new_major, new_minor, new_patch = new_semver

  if new_major != old_major:
    return "major"

  if new_minor != old_minor:
    return "minor"

  if new_patch != old_patch:
    return "patch"

  return None


def bump_semver(version, level):
  """
  Função para incrementar uma versão semântica com base no nível de mudança.

  Args:
    version (str): A versão semântica a ser incrementada.
    level (str): O nível de mudança ("major", "minor", "patch") que determina qual parte da versão deve ser incrementada.

  Returns:
    str: A nova versão semântica incrementada de acordo com o nível especificado, ou None se a versão de entrada for inválida ou se o nível for desconhecido.
  """

  semver = parse_semver(version)

  if semver is None:
    return None

  major, minor, patch = semver

  if level == "major":
    return f"{major + 1}.0.0"

  if level == "minor":
    return f"{major}.{minor + 1}.0"

  if level == "patch":
    return f"{major}.{minor}.{patch + 1}"

  return None


def max_change_level(levels):
  """
  Função para determinar o nível de mudança mais significativo a partir de uma lista de níveis.

  Args:
    levels (list of str): Lista de níveis de mudança (ex.: ["patch", "minor", "major"]).

  Returns:
    str: O nível de mudança mais significativo.
  """

  priority = {"patch": 1, "minor": 2, "major": 3}
  valid_levels = [level for level in levels if level in priority]

  if not valid_levels:
    return None

  return max(valid_levels, key=lambda level: priority[level])


# Mapeamento de chaves de versão composta para suas chaves de dependência.
COMPOSITE_VERSION_RULES = {
    "TF_AWS_VERSION": ["TERRAFORM_VERSION", "AWSCLI_VERSION"],
    "TF_GCLOUD_VERSION": ["TERRAFORM_VERSION", "GCLOUD_VERSION"],
    "TF_AWS_GCLOUD_VERSION": ["TERRAFORM_VERSION", "AWSCLI_VERSION", "GCLOUD_VERSION"],
    "TRIVY_HADOLINT_VERSION": ["TRIVY_VERSION", "HADOLINT_VERSION"],
    "DOCKERX_VERSION": ["DOCKER_VERSION", "DOCKER_BUILDX_VERSION"],
    "SECURITY_SCANNER_VERSION": ["TRIVY_VERSION", "HADOLINT_VERSION", "BETTERLEAKS_VERSION"],
}

# Mapeamento de chaves de versão base para seus diretórios de imagem.
VERSION_KEY_TO_DIR = {
    "AWSCLI_VERSION": "aws-cli",
    "GCLOUD_VERSION": "gcloud-cli",
    "TERRAFORM_VERSION": "terraform",
    "SONAR_CLI_VERSION": "sonar-scanner"
}

# Mapeamento de chaves de versão composta para seus diretórios de imagem.
COMPOSITE_KEY_TO_DIR = {
    "TF_AWS_VERSION": "terraform-aws",
    "TF_GCLOUD_VERSION": "terraform-gcloud",
    "TF_AWS_GCLOUD_VERSION": "terraform-aws-gcloud",
    "TRIVY_HADOLINT_VERSION": "trivy-hadolint",
    "DOCKERX_VERSION": "dockerx",
    "SECURITY_SCANNER_VERSION": "security-scanner"
}

with open("latest_versions.json", "r", encoding="utf-8") as f:
  latest = json.load(f)

with open("versions.env", "r", encoding="utf-8") as f:
  lines = f.readlines()

key_line_idx = {}
key_current_val = {}

for idx, line in enumerate(lines):
  m = re.match(r"^([A-Z0-9_]+)=(.*)$", line.rstrip("\n"))

  if m:
    key_line_idx[m.group(1)] = idx
    key_current_val[m.group(1)] = m.group(2)

changed = []

# Acompanha o nível de mudança para as versões base atualizadas a partir de latest_versions.json.
base_change_levels = {}

for key, new_val in latest.items():
  if key in key_line_idx:
    old_val = key_current_val[key]

    if old_val != new_val:
      lines[key_line_idx[key]] = f"{key}={new_val}\n"
      changed.append((key, old_val, new_val))
      base_change_levels[key] = detect_change_level(old_val, new_val)
  else:
    # Se a chave não existir ainda em versions.env, adiciona no final.
    if lines and not lines[-1].endswith("\n"):
      lines[-1] += "\n"

    lines.append(f"{key}={new_val}\n")
    changed.append((key, "<absent>", new_val))

# Composição das versões de imagens compostas é feita com base nas mudanças detectadas nas versões das dependências.
for composite_key, dependency_keys in COMPOSITE_VERSION_RULES.items():
  if composite_key not in key_line_idx:
    continue

  triggered_levels = [
      base_change_levels.get(dep_key)
      for dep_key in dependency_keys
      if dep_key in base_change_levels
  ]
  bump_level = max_change_level(triggered_levels)

  if not bump_level:
    continue

  composite_old_val = key_current_val[composite_key]
  composite_new_val = bump_semver(composite_old_val, bump_level)

  # Pula atualizações de versão composta se a versão antiga não for válida ou se o nível de mudança for desconhecido.
  if not composite_new_val or composite_new_val == composite_old_val:
    continue

  lines[key_line_idx[composite_key]] = f"{composite_key}={composite_new_val}\n"
  changed.append((composite_key, composite_old_val, composite_new_val))

if changed:
  with open("versions.env", "w", encoding="utf-8") as f:
    f.writelines(lines)

  changed_keys = {key for key, _, _ in changed}

  # Limpa o conteúdo de .trivyignore para as imagens base cujas versões foram alteradas.
  for key in changed_keys:
    dir_name = VERSION_KEY_TO_DIR.get(key)
    if dir_name:
      trivyignore_path = os.path.join(dir_name, ".trivyignore")
      if os.path.isfile(trivyignore_path):
        with open(trivyignore_path, "w", encoding="utf-8") as f:
          pass
        print(f"Cleared {trivyignore_path}")

  # Rebuild .trivyignore para diretórios compostos concatenando os conteúdos de .trivyignore de seus diretórios de dependências base.
  for composite_key in changed_keys:
    if composite_key not in COMPOSITE_KEY_TO_DIR:
      continue

    composite_dir = COMPOSITE_KEY_TO_DIR[composite_key]
    dep_keys = COMPOSITE_VERSION_RULES.get(composite_key, [])

    contents = []
    for dep_key in dep_keys:
      dep_dir = VERSION_KEY_TO_DIR.get(dep_key)
      if not dep_dir:
        continue
      dep_trivyignore = os.path.join(dep_dir, ".trivyignore")
      if os.path.isfile(dep_trivyignore):
        with open(dep_trivyignore, "r", encoding="utf-8") as f:
          content = f.read().strip()
        if content:
          contents.append(content)

    trivyignore_path = os.path.join(composite_dir, ".trivyignore")
    with open(trivyignore_path, "w", encoding="utf-8") as f:
      if contents:
        f.write("\n\n".join(contents) + "\n")
    print(f"Updated {trivyignore_path}")

print("Changes:")

if not changed:
  print("- no changes")
else:
  for key, old_val, new_val in changed:
    print(f"- {key}: {old_val} -> {new_val}")

github_output = os.environ.get("GITHUB_OUTPUT")

if github_output:
  with open(github_output, "a", encoding="utf-8") as out:
    out.write(f"changed={'true' if changed else 'false'}\n")
else:
  print("GITHUB_OUTPUT is not set; skipping GitHub Actions output export.")
