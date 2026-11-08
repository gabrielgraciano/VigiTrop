# Pipeline de dados do VigiTrop

Baixa os microdados do SINAN com o PySUS 2.x (versão fixa) e a população do IBGE. Depois prepara tudo para o app.
Roda em Docker. Os dados ficam em `data/`, na raiz do repo, que está no `.gitignore`.

```
SINAN (catálogo S3 do PySUS) ─baixar─▶ data/cache + data/bronze/manifesto.csv
                                        │
                                        ├─inspecionar─▶ data/relatorios/ (schema, contagens)
                                        │
                                        └─silver─▶ data/silver/casos/<doenca>/<ano>.parquet
                                                    │
IBGE (projeção revisão 2024) ─populacao─────────────┤
                                                    └─gold─▶ data/gold/  (o que o app lê)
                                                              │
                                                              └─validar─▶ data/relatorios/validacao_tcc.csv
```

## Uso (Windows, PowerShell, Docker Desktop)

Para rodar tudo, em ordem:

```powershell
cd $HOME\tcc-vigitrop\vigitrop
git pull
docker compose build pipeline
docker compose run --rm pipeline executar
```

- Na primeira vez, baixa cerca de 0,8 GB (170 arquivos) e leva alguns minutos.
- Nas próximas, só baixa e reprocessa o que mudou.
- Cada execução grava um log em `data/logs/`.

| Comando | O que faz | Rede? |
|---|---|---|
| `listar` | Mostra os anos de cada doença e se cada um é FINAL ou PRELIM. Não baixa nada. Saída: `relatorios/catalogo.csv`. | sim |
| `baixar` | Baixa os arquivos brutos para `cache/`, confere o sha256 e atualiza `bronze/manifesto.csv`. Tenta até 4 vezes. | sim |
| `populacao` | Baixa a projeção do IBGE (uma vez só) e gera `gold/populacao.parquet`. | 1ª vez |
| `silver` | Bruto → um registro por notificação, num schema único. Incremental: só refaz o que mudou. | não |
| `gold` | Silver → tabelas agregadas do app, mais os metadados. | não |
| `validar` | Compara o gold com a Tabela 1 do TCC. | não |
| `inspecionar` | Relatório de schema, valores e contagens por definição de caso. | não |
| `executar` | `baixar`, `populacao`, `silver`, `gold` e `validar`, nessa ordem. | sim |

Opções:
- `--doencas RAIV CHAG`: aceita código SINAN ou nome do config. Vale para `listar`, `baixar`, `inspecionar` e `silver`.
- `--anos 2007-2024`: aceita também `2024` ou `2019,2021-2023`. Vale para os mesmos comandos.
- `--forcar`: refaz mesmo sem mudança. Vale para `silver` e `populacao`.

## O gold (`data/gold/`)

O app lê só estes arquivos, via DuckDB. Juntos ocupam cerca de 1,3 MB.

| Arquivo | Colunas |
|---|---|
| `casos.parquet` | `doenca`, `definicao`, `ano`, `uf`, `sexo`, `faixa_etaria`, `raca`, `casos` |
| `populacao.parquet` | `ano`, `uf`, `sexo`, `faixa_etaria`, `populacao` (2000-2070) |
| `doencas.parquet` | `doenca`, `codigo`, `nome`, `definicao`, `expressao`, `padrao`, `filtro`, `notas` |
| `arquivos.parquet` | `doenca`, `codigo`, `ano`, `status` (FINAL/PRELIM), `data_coleta`, `linhas`, `aviso` |
| `meta.json` | data de geração, versões, fontes, ano de referência |

Regras de leitura:
- **Sem linhas agregadas.** Não existe linha "Brasil" nem faixa "Todos". O total é sempre a soma, que era a causa da contagem dobrada no app antigo.
- **`ano`** é o ano de notificação (`NU_ANO`), como no TCC.
- **`uf`** é o código IBGE da UF de residência. `NULL` quer dizer ignorada.
- **`sexo`** vale `M`, `F` ou `I`. **`raca`** vai de `1` a `5`, e `9` é ignorada. **`faixa_etaria`** vai de `0-4` a `90 ou mais`, mais `Ignorado`.
- **Definições:** uma notificação entra em todas as definições que satisfaz. O app filtra `definicao` e usa a marcada como `padrao` em `doencas.parquet`.

## Definições de caso

As definições ficam em `config/doencas.yaml`. Cada uma é uma expressão SQL (DuckDB) aplicada sobre o bruto normalizado:
- os códigos viram texto sem espaços;
- vazio vira `NULL`;
- as datas viram `DATE`.

O campo `padrao` diz qual definição o app usa. As regras que o TCC usou ficam como `legado_tcc`, e o `validar` usa essas.

Para mudar uma definição, edite o YAML e rode `silver` e `gold`. A silver percebe a mudança sozinha e refaz só a doença alterada.

## Validação (08/11/2026)

O `validar` comparou o gold com a Tabela 1 do TCC. Nos arquivos que o DataSUS não revisou depois da coleta do TCC (15/10/2024), a incidência bate **exatamente**, com 2 casas decimais: raiva, Chagas, as duas leishmanioses, esquistossomose e hanseníase.

Dengue, chikungunya e serpente não batem exatamente porque todos os arquivos dessas doenças foram revisados depois do TCC. A diferença mediana fica abaixo de 2%.

## Detalhes

- **PySUS:** versão `2.11.7`. As dependências estão travadas em `requirements.txt`; para atualizar, veja `requirements.in`.
- **Status FINAL ou PRELIM:** vem do caminho original do arquivo no FTP do DataSUS (`.../DADOS/FINAIS/` ou `.../DADOS/PRELIM/`).
- **Rede:** precisa de HTTPS liberado para os hosts abaixo.
  - `nbg1.your-objectstorage.com`: catálogo do PySUS;
  - `ftp.ibge.gov.br`: população;
  - `extensions.duckdb.org`: só no build da imagem.
- **Fora do Docker** (Python ≥ 3.11):

  ```bash
  pip install -r pipeline/requirements.txt
  cd pipeline
  python -m vigitrop_pipeline --dados ../data executar
  ```
