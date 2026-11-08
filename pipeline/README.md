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
                                                              ├─tendencia─▶ data/gold/tendencia.parquet
                                                              │             + data/relatorios/tendencia_tcc.csv
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
| `tendencia` | Tendência da incidência Brasil por doença (joinpoint): `gold/tendencia.parquet`. Compara com o Joinpoint do TCC em `relatorios/tendencia_tcc.csv`. | não |
| `validar` | Compara o gold com a Tabela 1 do TCC. | não |
| `inspecionar` | Relatório de schema, valores e contagens por definição de caso. | não |
| `executar` | `baixar`, `populacao`, `silver`, `gold`, `tendencia` e `validar`, nessa ordem. | sim |

Opções:
- `--doencas RAIV CHAG`: aceita código SINAN ou nome do config. Vale para `listar`, `baixar`, `inspecionar` e `silver`.
- `--anos 2007-2024`: aceita também `2024` ou `2019,2021-2023`. Vale para os mesmos comandos.
- `--forcar`: refaz mesmo sem mudança. Vale para `silver` e `populacao`.

## O gold (`data/gold/`)

O app lê só estes arquivos, via DuckDB. Juntos ocupam menos de 2 MB.

| Arquivo | Colunas |
|---|---|
| `casos.parquet` | `doenca`, `definicao`, `ano`, `uf`, `sexo`, `faixa_etaria`, `raca`, `casos` |
| `casos_semana.parquet` | `doenca`, `definicao`, `semana` (AAAASS), `inicio_semana`, `uf`, `casos`: semana epidemiológica de início dos sintomas. Hanseníase e LTA ficam de fora porque não têm o campo. |
| `populacao.parquet` | `ano`, `uf`, `sexo`, `faixa_etaria`, `populacao` (2000-2070) |
| `doencas.parquet` | `doenca`, `codigo`, `nome`, `definicao`, `expressao`, `padrao`, `filtro`, `notas`, `texto_app` |
| `arquivos.parquet` | `doenca`, `codigo`, `ano`, `status` (FINAL/PRELIM), `data_coleta`, `linhas`, `aviso` |
| `tendencia.parquet` | `doenca`, `definicao`, `tipo`, `segmento`, `ano_inicio`, `ano_fim`, `apc`, `apc_ic_inf`, `apc_ic_sup`, `significativo`, `taxa_inicio`, `taxa_fim`, `joinpoints`, `n_anos`, `aviso` |
| `meta.json` | data de geração, versões, fontes, ano de referência |

Regras de leitura:
- **Sem linhas agregadas.** Não existe linha "Brasil" nem faixa "Todos". O total é sempre a soma, que era a causa da contagem dobrada no app antigo.
- **`ano`** é o ano de notificação (`NU_ANO`), como no TCC.
- **`uf`** é o código IBGE da UF de residência. `NULL` quer dizer ignorada.
- **`sexo`** vale `M`, `F` ou `I`. **`raca`** vai de `1` a `5`, e `9` é ignorada. **`faixa_etaria`** vai de `0-4` a `90 ou mais`, mais `Ignorado`.
- **Definições:** uma notificação entra em todas as definições que satisfaz. O app filtra `definicao` e usa a marcada como `padrao` em `doencas.parquet`.
- **`tendencia.parquet`** tem uma linha por segmento (`tipo = 'APC'`, `segmento` 1, 2...) e uma linha do período inteiro (`tipo = 'AAPC'`, `segmento` NULL) por doença. Só a definição padrão. `apc` e o IC estão em % ao ano. `taxa_inicio` e `taxa_fim` são a incidência ajustada pelo modelo (por 100 mil) nos anos-limite: servem para desenhar a linha de tendência. Ver [Tendência](#tendência).

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

## Tendência

O `tendencia` mede a tendência da incidência Brasil de cada doença. Brasil é a soma de todas as UFs, inclusive a UF ignorada. O método segue o Joinpoint (NCI), que o TCC usou.

- **Modelo:** ln(taxa) = b0 + b1·ano + Σ dk·(ano − τk)+, contínuo nos joinpoints τ. Cada τ cai num ano observado. Precisa de pelo menos 2 anos antes do primeiro τ, 2 depois do último e 2 entre dois τ, como o padrão do Joinpoint.
- **Número de joinpoints:** de 0 a 3, ou menos em série curta (regra do Joinpoint: 1 com 7-11 anos, 2 com 12-16). As posições saem de uma busca exaustiva por mínimos quadrados. O número sai do menor BIC na forma do Joinpoint: ln(SQR/n) + (2k+2)·ln(n)/n.
- **APC** = 100·(exp(inclinação) − 1), com IC95% pela t de Student (gl = n − 2k − 2).
- **AAPC** = média das inclinações, ponderada pelos anos de cada segmento. O IC95% usa a normal na escala log, como o Joinpoint. Se o período cabe num segmento só, AAPC = APC.
- **Significativo** quer dizer que o IC95% não contém 0.
- **Ano com zero casos:** soma-se meio caso só nesse ano, e o ano aparece no `aviso`. Excluir o ano puxaria a tendência para cima, porque só os valores mais baixos sairiam.
- **Período do app:** definição padrão, do `ano_inicio` do config até o último ano FINAL da doença. Anos PRELIM ficam de fora.

**Comparação com o TCC (08/11/2026).** Mesma regra de caso do `validar`, mesmos períodos do TCC. A referência fica em `config/tcc_joinpoint.csv` e o detalhe em `relatorios/tendencia_tcc.csv`. Para cada trecho do TCC, o CSV dá a variação média do nosso modelo naquele mesmo trecho.

| Doença | Joinpoints TCC | Joinpoints aqui | AAPC TCC | AAPC aqui |
|---|---|---|---|---|
| Chagas | 2013 | 2013 | +14,0* | +13,4* |
| Chikungunya | — | 2017 | +6,5 | +60,6* |
| Dengue | 2022 | 2021 | +12,5* | +11,7* |
| Esquistossomose | 2021 | 2020 | −12,9* | −13,1* |
| Hanseníase | 2022 | 2018, 2021 | −8,9* | −3,1* |
| Leishmaniose visceral | 2018 | 2018 | −5,6* | −5,5* |
| Leishmaniose tegumentar | — | — | −3,7* | −3,7* |
| Serpente | 2009, 2016, 2019 | 2009, 2016, 2019 | +0,1 | +0,3 |
| Raiva | — | — | +4,4 | +3,7 |

A AAPC tem o mesmo sentido nas 9 doenças e a mesma significância em 8. Em 7 delas os APCs dos segmentos têm o mesmo sentido e uma magnitude parecida. A maior diferença é a dengue em 2022-2024: +87% ao ano aqui contra +149% no TCC, porque o nosso joinpoint caiu em 2021 e não em 2022. As duas doenças que divergem divergem pelos dados, não pelo método:
- **Chikungunya:** a regra do TCC (`CLASSI_FIN = 13`) dá hoje 0,33 por 100 mil em 2015 e 43,5 em 2016. No TCC eram 16,03 e 78,06: em 2015 a codificação era outra, e os arquivos foram revisados em 2026. A série começa muito baixa, e isso cria uma alta enorme em 2015-2017.
- **Hanseníase:** no TCC (coleta de outubro de 2024), 2024 era um ano incompleto, com 3,36 por 100 mil. O arquivo atual dá 13,94. A queda de −37,6% ao ano em 2022-2024 vinha do ano incompleto.

**Limitações:**
- Os ICs daqui são mais estreitos que os do TCC. Eles são paramétricos e não contam a incerteza da posição dos joinpoints, o que pesa sobretudo em segmentos de 3 anos. O TCC usou o IC empírico do Joinpoint, que é assimétrico e mais largo.
- O BIC às vezes acha uma quebra que não existe. Em simulação de séries sem quebra, isso acontece em cerca de 16% das séries de 20 anos e 21% das de 16. O BIC3 do Joinpoint (penalidade 3k+2) erra menos, mas perde as quebras de Chagas, dengue e esquistossomose que o TCC achou. Para trocar, mude `PARAMETROS_POR_JOINPOINT` em `tendencia.py`.
- O ajuste é por mínimos quadrados sem pesos (variância constante no log). Um ano com poucos casos (raiva, Chagas) pesa igual aos outros, embora seja mais ruidoso.
- Mudança de notificação conta como tendência. Exemplo: raiva com inconclusivos tem 52 casos em 2021 e 2 em 2022. O app mostra isso como queda de −64% ao ano em 2020-2024.

## Detalhes

- **PySUS:** versão `2.11.7`. As dependências estão travadas em `requirements.txt`; para atualizar, veja `requirements.in`.
- **Testes** (ajuste de tendência com séries sintéticas): dentro de `pipeline/`, rode `python -m unittest discover tests`.
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
