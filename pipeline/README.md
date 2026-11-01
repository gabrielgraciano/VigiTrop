# Pipeline de dados do VigiTrop

Baixa os microdados do SINAN com o PySUS 2.x (versão fixa) e os prepara para o app.
Tudo roda em Docker. Os dados ficam em `data/`, na raiz do repositório, que é ignorada pelo git.

```
SINAN (espelho S3 do PySUS) ──baixar──▶ data/cache + data/bronze/manifesto.csv
                                         │
                                         ├─inspecionar─▶ data/relatorios/  (schema, contagens)
                                         │
                                         └─(próximo)──▶ silver ──▶ gold (lido pelo app)
```

| Comando | O que faz | Precisa de rede? |
|---|---|---|
| `listar` | Mostra quais anos existem para cada doença, e se cada um é FINAL ou PRELIM. Não baixa nada. Grava `data/relatorios/catalogo.csv`. | sim |
| `baixar` | Baixa os arquivos brutos para `data/cache`, confere o sha256 e atualiza `data/bronze/manifesto.csv`. Arquivo que não mudou não é baixado de novo. | sim |
| `inspecionar` | Gera um relatório com o schema de cada arquivo, os valores das colunas-chave e as contagens por definição de caso. Saídas: `data/relatorios/inspecao_*.md` e `contagens.csv`. | não |

Opções comuns:
- `--doencas RAIV CHAG`: código SINAN ou nome usado em `config/doencas.yaml`. Sem essa opção, roda para todas as doenças.
- `--anos 2007-2024`: também aceita `2024` ou `2019,2021-2023`. O padrão é do `ano_inicio` do config em diante.

Cada execução grava um log em `data/logs/`.

## Primeiro teste (Windows, PowerShell, Docker Desktop)

```powershell
cd $HOME\tcc-vigitrop\vigitrop
git pull
docker compose build pipeline
docker compose run --rm pipeline listar
docker compose run --rm pipeline baixar --doencas RAIV CHAG
docker compose run --rm pipeline inspecionar --doencas RAIV CHAG
```

Depois, mande de volta:
- `data\logs\` (os três logs);
- `data\relatorios\inspecao_*.md`;
- `data\relatorios\contagens.csv`;
- `data\relatorios\catalogo.csv`.

Esses arquivos só têm agregados, nenhum dado individual.

## Definições de caso

As definições ficam em `config/doencas.yaml`. Cada uma é uma expressão SQL (DuckDB) aplicada sobre o arquivo bruto normalizado:
- os códigos viram texto sem espaços, então `'1 '` vira `'1'`;
- vazio vira `NULL`.

Por enquanto, todas as definições estão **a validar**. O `inspecionar` existe justamente para comparar com o dump antigo e com a Tabela 1 do TCC.

## Detalhes

- **PySUS:** versão `2.11.7`. As dependências estão travadas em `requirements.txt`. Para atualizar, veja o cabeçalho de `requirements.in`.
- **Status do ano:** vem do caminho original no FTP do DataSUS (`.../DADOS/FINAIS/` ou `.../DADOS/PRELIM/`), que o catálogo guarda em `caminho_origem`.
- **Rede:** o catálogo fica em `https://nbg1.your-objectstorage.com/pysus/`. Se esse host estiver bloqueado, `listar` e `baixar` falham com erro de proxy/conexão.
- **Fora do Docker** (Python ≥ 3.11):

  ```bash
  pip install -r pipeline/requirements.txt
  cd pipeline
  python -m vigitrop_pipeline --dados ../data listar
  ```
