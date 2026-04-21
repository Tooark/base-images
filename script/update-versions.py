import json
import os
import re


def parse_semver(version):
  m = re.match(r"^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$", version)
  if not m:
    return None
  return tuple(int(part) for part in m.groups())


def detect_change_level(old_version, new_version):
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
  priority = {"patch": 1, "minor": 2, "major": 3}
  valid_levels = [level for level in levels if level in priority]
  if not valid_levels:
    return None
  return max(valid_levels, key=lambda level: priority[level])


COMPOSITE_VERSION_RULES = {
  "TF_AWS_VERSION": ["TERRAFORM_VERSION", "AWSCLI_VERSION"],
  "TF_GCLOUD_VERSION": ["TERRAFORM_VERSION", "GCLOUD_VERSION"],
  "TF_AWS_GCLOUD_VERSION": ["TERRAFORM_VERSION", "AWSCLI_VERSION", "GCLOUD_VERSION"],
  "TRIVY_HADOLINT_VERSION": ["TRIVY_VERSION", "HADOLINT_VERSION"],
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

# Track change level for base tool versions updated from latest_versions.json.
base_change_levels = {}

for key, new_val in latest.items():
  if key in key_line_idx:
    old_val = key_current_val[key]
    if old_val != new_val:
      lines[key_line_idx[key]] = f"{key}={new_val}\n"
      changed.append((key, old_val, new_val))
      base_change_levels[key] = detect_change_level(old_val, new_val)
  else:
    # If the key does not exist yet in versions.env, append at the end.
    if lines and not lines[-1].endswith("\n"):
      lines[-1] += "\n"
    lines.append(f"{key}={new_val}\n")
    changed.append((key, "<absent>", new_val))

# Composite image versions are bumped based on dependency version changes.
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

  # Skip invalid/non-semver values silently to avoid breaking workflow runs.
  if not composite_new_val or composite_new_val == composite_old_val:
    continue

  lines[key_line_idx[composite_key]] = f"{composite_key}={composite_new_val}\n"
  changed.append((composite_key, composite_old_val, composite_new_val))

if changed:
  with open("versions.env", "w", encoding="utf-8") as f:
    f.writelines(lines)

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
