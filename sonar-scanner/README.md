# sonar-scanner

Esta imagem fornece o comando `sonar-scanner` pronto para uso em pipelines CI/CD com SonarQube, voltada para linguagens como Go, PHP e outras que utilizam o scanner CLI diretamente.

## Nome e tags da imagem

- Nome da imagem: `sonar-scanner` (nome da pasta)
- Tags publicadas por versão:
  - Versão completa: `sonar-scanner:<major.minor.patch>`
  - Versão curta (major.minor): `sonar-scanner:<major.minor>`
  - Versão menor (major): `sonar-scanner:<major>`
  - Última estável: `sonar-scanner:latest`

Substitua os números acima pelos valores da sua build.

## O que existe na imagem

| Item              | Descrição                                      |
| ----------------- | ---------------------------------------------- |
| Base              | `debian:12-slim` (padrão)                      |
| Sonar Scanner CLI | Instalado em `/opt/sonar-scanner`              |
| Java (JRE)        | OpenJDK 17 (pacote `openjdk-17-jre-headless`)  |
| Binários          | `sonar-scanner`, `java` disponíveis via `PATH` |
| Pacotes           | `ca-certificates`, `bash`, `git`               |
| Usuário padrão    | `app` (não-root)                               |

Observações:

- A imagem final usa build em múltiplos estágios (`builder` + `runtime mínimo`), copiando apenas `/opt/sonar-scanner` para reduzir acoplamento e manter o runtime enxuto.
- O usuário padrão é `app` e o HOME é `/home/app`.
- O cache do scanner fica em `/home/app/.sonar/cache`.
- A imagem é compatível com `linux/amd64` e `linux/arm64`.

## Uso rápido

Verificar versão do scanner:

```powershell
docker run --rm ghcr.io/tooark/sonar-scanner:latest sonar-scanner --version
```

Executar scan em um projeto (montando o diretório de trabalho):

```powershell
docker run --rm \
  -e SONAR_HOST_URL="https://sonarqube.exemplo.com" \
  -e SONAR_TOKEN="seu-token" \
  -v $(pwd):/usr/src \
  -w /usr/src \
  ghcr.io/tooark/sonar-scanner:latest \
  sonar-scanner -Dsonar.projectKey="meu-projeto"
```

## Uso no GitLab CI (via sonarqube-template-include)

```yaml
include:
  - remote: "https://raw.githubusercontent.com/Tooark/sonarqube-template-include/main/.gitlab-ci.yml"
    inputs:
      language: "go" # ou "php", "other"
      image: "ghcr.io/tooark/sonar-scanner:latest"
```

## Variantes de tag

- `sonar-scanner:<major>.<minor>.<patch>`: versão exata do Sonar Scanner CLI.
- `sonar-scanner:<major>.<minor>`: acompanha a última patch da série.
- `sonar-scanner:<major>`: acompanha a última minor da série.
- `sonar-scanner:latest`: aponta para a última versão estável construída.

Para pipelines reprodutíveis, prefira a versão completa.

## Como verificar versões dentro da imagem

```powershell
docker run --rm ghcr.io/tooark/sonar-scanner:latest sonar-scanner --version
docker run --rm ghcr.io/tooark/sonar-scanner:latest java -version
```
