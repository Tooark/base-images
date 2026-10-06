# Logos

Logos das ferramentas usados no site (`docs/index.html`). Ficam aqui, e não num CDN, porque a Content Security
Policy de tooark.com só libera imagens da própria origem (`img-src 'self' data:`).

Os logos são marcas dos respectivos donos e aparecem no site só para identificar cada ferramenta. Ao trocar um
arquivo, mantenha o nome: o HTML referencia `logos/<nome>`.

| Arquivo             | Ferramenta     | Origem                                                                                                                  |
| ------------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `aws.svg`           | AWS            | [Devicon](https://github.com/devicons/devicon) `amazonwebservices-original-wordmark.svg` (MIT)                          |
| `betterleaks.png`   | Betterleaks    | [betterleaks.com](https://betterleaks.com) `apple-touch-icon.png`                                                       |
| `cosign.svg`        | Cosign         | [sigstore/community](https://github.com/sigstore/community) `artwork/cosign/icons/color/sigstore_cosign-icon-color.svg` |
| `debian.svg`        | Debian         | [Devicon](https://github.com/devicons/devicon) `debian-original.svg` (MIT)                                              |
| `docker.svg`        | Docker         | [Devicon](https://github.com/devicons/devicon) `docker-original.svg` (MIT)                                              |
| `gcloud.svg`        | Google Cloud   | [Devicon](https://github.com/devicons/devicon) `googlecloud-original.svg` (MIT)                                         |
| `githubactions.svg` | GitHub Actions | [Devicon](https://github.com/devicons/devicon) `githubactions-original.svg` (MIT)                                       |
| `gitlab.svg`        | GitLab         | [Devicon](https://github.com/devicons/devicon) `gitlab-original.svg` (MIT)                                              |
| `hadolint.png`      | Hadolint       | [hadolint/hadolint](https://github.com/hadolint/hadolint) `website/img/cat_container.png`                               |
| `kubernetes.svg`    | Kubernetes     | [Devicon](https://github.com/devicons/devicon) `kubernetes-original.svg` (MIT)                                          |
| `opentofu.svg`      | OpenTofu       | [opentofu/brand-artifacts](https://github.com/opentofu/brand-artifacts) `symbol-only/transparent/SVG/on-light.svg`      |
| `sonarqube.svg`     | SonarQube      | [Simple Icons](https://simpleicons.org) `sonarqubeserver.svg` (CC0), preenchido com `#126ED3`                           |
| `terraform.svg`     | Terraform      | [Devicon](https://github.com/devicons/devicon) `terraform-original.svg` (MIT)                                           |
| `trivy.svg`         | Trivy          | [Simple Icons](https://simpleicons.org) `trivy.svg` (CC0), preenchido com `#1904DA`                                     |

Os logos aparecem sempre sobre um fundo claro (`--tile`), nos dois temas: vários são escuros (AWS, Trivy, Debian)
e sumiriam sobre a superfície do tema escuro.
