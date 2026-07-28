# Summary

<!--
Explain what this PR does and why. Reference the issue(s) it closes.
Example: "Closes #42 — bump AWS CLI to 2.37.0 and refresh the aws-cli .trivyignore."
-->

## Affected image(s) / area(s)

- [ ] `aws-cli`
- [ ] `dockerx`
- [ ] `gcloud-cli`
- [ ] `security-scanner`
- [ ] `sonar-scanner`
- [ ] `tofu` / `tofu-aws` / `tofu-gcloud` / `tofu-aws-gcloud`
- [ ] `terraform*` (deprecated images)
- [ ] `trivy-hadolint`
- [ ] Versioning (`versions.env`, `VERSION` files, `script/`)
- [ ] CI/CD (`.github/workflows/`)
- [ ] Samples / docs

## Type of change

- [ ] `feat` — new feature or new image
- [ ] `fix` — bug fix
- [ ] `docs` — documentation only
- [ ] `refactor` — no functional change
- [ ] `build` / `ci` — Dockerfile, workflow, or tooling change
- [ ] `chore` — version bumps, `.trivyignore` maintenance
- [ ] Breaking change (describe it in "Notes for reviewers")

## Checklist

- [ ] Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
- [ ] The image builds locally (`./script/build-and-run-local.sh build <image>`)
- [ ] The local security scan passes (`./script/build-and-run-local.sh all <image>`)
- [ ] New `.trivyignore` entries are justified below
- [ ] Versions changed only through `versions.env` / `VERSION` files
- [ ] `README.md` and `README.pt-BR.md` updated **and in sync** (if docs changed)

## Security notes (`.trivyignore` / scan changes)

<!--
If this PR adds or keeps CVE exceptions, list each CVE with a one-line
justification (no upstream fix, not exploitable in this context, etc.).
-->

## Notes for reviewers

<!-- Anything specific to focus on, alternatives considered, follow-up work, etc. -->
