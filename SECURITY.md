# Security Policy

## Reporting a vulnerability

The Tooark base-images maintainers take security seriously — these images run
inside CI/CD pipelines with access to cloud credentials and Docker sockets. If
you believe you have found a security vulnerability in any base image, its
entrypoint, the `ark-tools` wrapper, the automation scripts, or the CI
workflows, please report it **privately** so we can address it before public
disclosure.

### How to report

**Do NOT** open a public GitHub issue for security vulnerabilities.

Instead, use one of the following channels:

1. **Preferred** — GitHub Security Advisories:
   [Report a vulnerability](https://github.com/Tooark/base-images/security/advisories/new)
2. **Email** — `security@tooark.com` (PGP key available on request)

Please include:

- A description of the vulnerability and its impact
- Steps to reproduce (proof of concept if possible)
- The affected image(s) and tag(s) (e.g. `ghcr.io/tooark/security-scanner:1.5.0`)
- The environment where you ran it (GitHub Actions, GitLab CI, local Docker…)
- Your name / handle for credit (optional)

### What to expect

| Milestone                            | Target time                                             |
| ------------------------------------ | ------------------------------------------------------- |
| Acknowledgment of report             | Within **72 hours**                                     |
| Initial triage & severity assessment | Within **5 business days**                              |
| Fix and coordinated disclosure plan  | Within **30 days** (may be extended for complex issues) |
| Public advisory (if applicable)      | After a fixed release is published                      |

We follow the principles of
[Coordinated Vulnerability Disclosure (CVD)](https://en.wikipedia.org/wiki/Coordinated_vulnerability_disclosure).

## Supported versions

Each image is versioned and released independently. Only the **latest published
tag** of each image receives security fixes — older tags remain available on
`ghcr.io` for reproducibility but are not patched.

Always update to the latest tag of the image before reporting a bug or
vulnerability.

## Known CVEs and `.trivyignore`

Every image is scanned with **Trivy**, **Hadolint**, and **BetterLeaks** in CI
before publication. CVEs that are assessed and accepted (e.g. no fix available
upstream, not exploitable in the image's usage context) are documented in the
image's `.trivyignore` file with a review date, and listed in the GitHub
Release notes. If you believe an accepted exception is actually exploitable,
report it through the private channels above.

## Scope

In scope:

- Vulnerabilities introduced by the image definitions (Dockerfiles, entrypoint
  scripts, `ark-tools.sh`)
- Privilege-escalation issues in the non-root/`gosu`/`docker.sock` handling
- Supply-chain issues in how tools are downloaded and verified during build
- Vulnerabilities in the CI/CD workflows and automation scripts of this
  repository (e.g. secret exposure, tag/release spoofing)

Out of scope:

- CVEs in the upstream tools bundled in the images (AWS CLI, Google Cloud SDK,
  OpenTofu, Terraform, Trivy, kubectl, etc.) — report those upstream; here they
  are handled via version bumps and `.trivyignore` review
- Vulnerabilities in Docker, the container runtime, or the CI platform itself
- Social engineering, physical attacks, and denial of service

## Safe harbor

We support security research conducted in good faith. If you follow this policy,
we will:

- Not pursue legal action against you
- Work with you to understand and resolve the issue
- Publicly credit you (if you wish) in the security advisory

## Bounties

Tooark base-images is an open-source project maintained by volunteers. **No
monetary bounty program is currently offered**, but we deeply appreciate
responsible disclosure and will credit reporters publicly.
