#!/usr/bin/env python3
"""Gera o site do GitHub Pages: copia docs/ para um diretório de saída e preenche os marcadores de versão do HTML
a partir das tags de release das imagens.

Uso:
  python3 script/render-docs.py            # gera _site/
  python3 script/render-docs.py out/dir    # gera out/dir/

O site descreve o que está publicado, não o que o versions.env pede para a próxima build. O image-build.yml cria
a tag <imagem>-<versão> a cada release e builda a imagem com o versions.env daquele commit; por isso os valores
de cada imagem vêm do versions.env na última tag de release dela. Um bump que ainda não foi buildado (ou cuja
build falhou) não chega ao site, e ninguém copia daqui um `docker pull` de uma tag que não existe.

Marcadores:
  {{imagem}}          versão da última release            {{aws-cli}}                 -> 2.37.4
  {{imagem:MINOR}}    tag flutuante MAJOR.MINOR           {{aws-cli:MINOR}}           -> 2.37
  {{imagem:MAJOR}}    tag flutuante MAJOR                 {{aws-cli:MAJOR}}           -> 2
  {{imagem:DATE}}     data da release (AAAA-MM-DD)        {{aws-cli:DATE}}            -> 2026-09-26
  {{imagem:CHAVE}}    CHAVE do versions.env na release    {{aws-cli:KUBECTL_VERSION}} -> 1.36.1
  {{CHAVE}}           CHAVE do versions.env no HEAD       {{BASE_IMAGE}}              -> debian:13-slim

A build falha quando sobra um marcador sem valor ou quando uma pasta de imagem (com Dockerfile) não tem a seção
id="img-<imagem>" em docs/index.html: imagem nova entra no site junto com o código. Requer as tags no clone
(no CI, checkout com fetch-depth: 0). Abrir docs/index.html direto mostra os marcadores crus.
"""
import html
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
PAGE = DOCS / "index.html"

VERSION_RE = re.compile(r"^\d+(\.\d+)*$")
# Só estes dois formatos contam como marcador. Expressões de CI nos exemplos (${{ secrets.X }}, $[[ inputs.x ]])
# têm espaço ou ponto e passam intactas.
PLACEHOLDER_RE = re.compile(r"\{\{([a-z0-9][a-z0-9-]*(?::[A-Z][A-Z0-9_]*)?|[A-Z][A-Z0-9_]*)\}\}")


def git(*args: str) -> str:
  return subprocess.run(
    ["git", "-C", str(ROOT), *args], check=True, capture_output=True, text=True, encoding="utf-8"
  ).stdout


def parse_env(text: str) -> dict[str, str]:
  values = {}
  for line in text.splitlines():
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line:
      continue
    key, value = line.split("=", 1)
    values[key.strip()] = value.strip()
  return values


def version_key(version: str) -> tuple[int, ...]:
  return tuple(int(part) for part in version.split("."))


def image_values(image: str, tags: list[str], head_env: dict[str, str]) -> dict[str, str]:
  prefix = f"{image}-"
  # "tofu-" também casa com "tofu-aws-1.3.0"; o resto precisa ser só versão para a tag ser desta imagem.
  versions = [t[len(prefix):] for t in tags if t.startswith(prefix) and VERSION_RE.match(t[len(prefix):])]

  if versions:
    version = max(versions, key=version_key)
    tag = f"{image}-{version}"
    env = parse_env(git("show", f"{tag}:versions.env"))
    date = git("for-each-ref", "--format=%(creatordate:short)", f"refs/tags/{tag}").strip()
  else:
    # Imagem que ainda não teve release: cai no HEAD para o site não quebrar, mas avisa no log do CI.
    primary = (ROOT / image / "VERSION").read_text(encoding="utf-8").split()[0]
    version = head_env.get(primary, "")
    env = head_env
    date = git("log", "-1", "--format=%cs").strip()
    print(f"::warning::{image} has no release tag yet; the site shows versions.env at HEAD", file=sys.stderr)

  parts = version.split(".")
  values = {
    image: version,
    f"{image}:MINOR": ".".join(parts[:2]),
    f"{image}:MAJOR": parts[0],
    f"{image}:DATE": date,
  }
  values.update({f"{image}:{key}": value for key, value in env.items()})
  return values


def main() -> int:
  out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "_site"
  out = out if out.is_absolute() else Path.cwd() / out

  head_env = parse_env((ROOT / "versions.env").read_text(encoding="utf-8"))
  tags = git("tag", "--list").split()
  images = sorted(p.parent.name for p in ROOT.glob("*/Dockerfile"))

  values = dict(head_env)
  for image in images:
    values.update(image_values(image, tags, head_env))

  errors = []
  source = PAGE.read_text(encoding="utf-8")
  for image in images:
    if f'id="img-{image}"' not in source:
      errors.append(f'docs/index.html has no section id="img-{image}" for the {image}/ image')

  # Os .md de docs/ são notas para quem mantém o site (origem dos logos), não páginas.
  shutil.copytree(DOCS, out, dirs_exist_ok=True, ignore=shutil.ignore_patterns("*.md"))

  for page in sorted(out.rglob("*.html")):
    lines = page.read_text(encoding="utf-8").split("\n")
    for number, line in enumerate(lines, 1):
      for name in PLACEHOLDER_RE.findall(line):
        if name not in values:
          # A renderização mantém cada linha no lugar, então o erro aponta para o arquivo de origem.
          errors.append(f"docs/{page.relative_to(out).as_posix()}:{number}: no value for {{{{{name}}}}}")
      lines[number - 1] = PLACEHOLDER_RE.sub(lambda m: html.escape(values.get(m[1], m[0])), line)
    page.write_text("\n".join(lines), encoding="utf-8", newline="\n")

  if errors:
    print("\n".join(errors), file=sys.stderr)
    return 1

  print(f"rendered docs/ into {out}")
  for image in images:
    print(f"  {image:<22} {values[image]:<12} {values[f'{image}:DATE']}")
  return 0


if __name__ == "__main__":
  sys.exit(main())
