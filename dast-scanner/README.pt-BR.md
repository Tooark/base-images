# dast-scanner

Imagem base com **OWASP ZAP** e **Nuclei** para testes dinâmicos de segurança
de aplicações (DAST) autorizados. Segue as convenções da imagem
`security-scanner` do repositório, mantendo os testes web em runtime separados
dos scans de código-fonte e imagens.

🌍 **Idiomas:** [![USA Flag](https://flagcdn.com/w20/us.png) English](https://github.com/Tooark/base-images/blob/main/dast-scanner/README.md) · ![Brazil Flag](https://flagcdn.com/w20/br.png) **Português (este arquivo)**

---

## Recursos

- **Nuclei** para reconhecimento de tecnologias e verificações baseadas em templates
- **OWASP ZAP** para crawling e testes passivos/ativos de aplicações web
- Runtime Debian 13 slim; usuário não-root `app`
- linux/amd64 e linux/arm64
- Versões pinadas; checksum do release do Nuclei verificado
- Envelopes `ark-report-tools` v1.4 com identidade da imagem do scanner e referências aos relatórios nativos
- Nenhum alvo é escaneado ao iniciar o container; o Nuclei pode buscar templates
  quando o operador o executa explicitamente, conforme o comportamento padrão

## Conteúdo da imagem

| Item | Descrição |
| ---- | --------- |
| Base | `debian:13-slim` |
| OWASP ZAP | comando `zap` |
| Nuclei | comando `nuclei` |
| CLI | `/usr/local/bin/dast-tools` |
| Dependências runtime | Java 21, `bash`, `curl`, `ca-certificates`, `gosu`, `jq`, `unzip` |
| Schema de relatório | `/usr/local/share/dast-tools/ark-report-tools.schema.v1.4.json` |
| Usuário padrão | `app` (não-root) |
| `WORKDIR` | `/workspace` |
| Diretório de relatórios | `/reports` |

## Uso responsável e modos de scan

Use as ferramentas somente em sistemas próprios ou com autorização explícita.
Antes do scan, confirme com o responsável os hosts e paths autorizados, janela
de teste, taxa de requisições e regras de tratamento de dados. Prefira ambientes
de staging com dados de teste.

O Nuclei pode apoiar o reconhecimento (por exemplo, com templates marcados para
tecnologias), mas também é um scanner de vulnerabilidades; o impacto depende
dos templates selecionados. A análise passiva do ZAP observa tráfego via proxy,
enquanto scans ativos enviam requisições construídas e podem alterar dados ou
afetar a disponibilidade. Prefira verificações passivas quando possível e
reserve scans ativos para alvos e janelas aprovados.

A imagem não inicia scans sozinha. Executar um comando é uma ação explícita do
operador. Quando o Nuclei é executado, seu comportamento padrão pode buscar ou
atualizar templates; fixe ou pré-carregue um conjunto revisado de templates
quando precisar de resultados reproduzíveis. O diretório de relatórios montado
é gravável pelo usuário não-root.

## Início rápido

Faça o build local e confira as ferramentas sem escanear alvos:

```bash
bash ./script/build-and-run-local.sh build dast-scanner
docker run --rm ghcr.io/tooark/dast-scanner:latest help
docker run --rm ghcr.io/tooark/dast-scanner:latest version
```

Para uma aplicação de staging autorizada, defina o alvo exato e persista os relatórios:

```bash
export DAST_TARGET="https://staging.example.test"
mkdir -p "$PWD/dast-reports"

docker run --rm \
  -v "$PWD/dast-reports:/reports" \
  ghcr.io/tooark/dast-scanner:latest \
  nuclei-scan "$DAST_TARGET" -tags tech
```

Esse comando grava o JSONL nativo do Nuclei em `nuclei.jsonl` e o envelope
padronizado em `nuclei-report.json`. O envelope identifica a imagem do scanner e
inclui caminho, formato, media type, SHA-256 e tamanho do artefato nativo.

O quick scan do OWASP ZAP faz crawling da URL e executa verificações **ativas**.
A flag explícita `--active` é obrigatória:

```bash
docker run --rm \
  -v "$PWD/dast-reports:/reports" \
  ghcr.io/tooark/dast-scanner:latest \
  zap-scan "$DAST_TARGET" --active
```

Para executar as duas ferramentas, use o comando combinado; a etapa ativa do
ZAP também exige autorização explícita:

```bash
docker run --rm \
  -v "$PWD/dast-reports:/reports" \
  ghcr.io/tooark/dast-scanner:latest \
  dast-scan "$DAST_TARGET" --active -tags tech
```

Use somente alvo e perfil de scan aprovados pelo responsável pela aplicação.
Ajuste templates e taxa de scan do Nuclei ao escopo; um scan não prova que uma
aplicação é segura.

O comando combinado preserva `nuclei.jsonl` e `zap-active.html`, gera
`nuclei-report.json` e `zap-report.json` e cria `dast-scan-report.json` com os
dois envelopes individuais. O consolidado referencia os dois arquivos nativos.
Os comandos `nuclei` e `zap` continuam repassando diretamente para as CLIs
upstream e não geram envelopes.

A exportação usa o mesmo schema `ark-report-tools` v1.4 do
`security-scanner`. O arquivo compartilhado está em
[`schemas/ark-report-tools.schema.v1.4.json`](schemas/ark-report-tools.schema.v1.4.json)
e também fica disponível na imagem pela variável `ARK_REPORT_SCHEMA`.

## Comandos

```text
dast-tools help
dast-tools version
dast-tools nuclei [opções do Nuclei]
dast-tools zap [opções do ZAP]
dast-tools nuclei-scan <http(s)://alvo> [opções do Nuclei]
dast-tools zap-scan <http(s)://alvo> --active [opções do ZAP]
dast-tools dast-scan <http(s)://alvo> --active [opções do Nuclei]
```

`nuclei-scan` gerencia o alvo e as opções de saída JSONL; o repasse direto para a
CLI nativa continua disponível via `nuclei`. No Nuclei, os templates podem ser
atualizados durante a execução; use um conjunto revisado e pinado quando
precisar de resultados reproduzíveis. Os comandos de scan do ZAP são ativos e
exigem `--active`.

## Versionamento e build local

As versões das ferramentas e da imagem são centralizadas em `versions.env`.
O arquivo `VERSION` controla as tags de release da imagem.

```bash
bash ./script/build-and-run-local.sh build dast-scanner
docker run --rm dast-scanner:latest version
```

## Licença

A definição desta imagem usa licença MIT. OWASP ZAP e Nuclei mantêm suas
respectivas licenças upstream.
