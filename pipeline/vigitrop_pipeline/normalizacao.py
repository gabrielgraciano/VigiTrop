"""Normalização dos arquivos brutos do SINAN (comum a `inspecionar` e `silver`).

`abrir()` cria duas views no DuckDB para um arquivo:
  bruto  o parquet como veio
  norm   colunas do config: códigos como VARCHAR limpo, datas como DATE,
         coluna ausente no arquivo = NULL

`sql_silver()` monta, sobre `norm`, a linha da camada silver: um registro por
notificação, num schema único para todas as doenças.
"""

from __future__ import annotations

from pathlib import Path

import duckdb

from .config import Doenca

INTEIROS = {"TINYINT", "SMALLINT", "INTEGER", "BIGINT", "HUGEINT", "UTINYINT", "USMALLINT", "UINTEGER", "UBIGINT"}
DECIMAIS = ("FLOAT", "DOUBLE", "REAL", "DECIMAL")

UFS = (11, 12, 13, 14, 15, 16, 17, 21, 22, 23, 24, 25, 26, 27, 28, 29, 31, 32, 33, 35, 41, 42, 43, 50, 51, 52, 53)
IDADE_MAX = 120
FAIXA_IGNORADA = "Ignorado"
FAIXA_FINAL = "90 ou mais"


def q(nome: str) -> str:
    """Identificador SQL entre aspas."""
    return '"' + nome.replace('"', '""') + '"'


def literal(texto: str) -> str:
    """Literal de texto SQL."""
    return "'" + texto.replace("'", "''") + "'"


def expr_codigo(coluna: str, tipo: str) -> str:
    """Código como VARCHAR limpo: '1 ' -> '1'; 10 (inteiro) -> '10'; '' -> NULL."""
    t = tipo.upper()
    if t in INTEIROS:
        return f"CAST({q(coluna)} AS VARCHAR)"
    if t.startswith(DECIMAIS):
        return f"CAST(TRY_CAST({q(coluna)} AS BIGINT) AS VARCHAR)"
    return f"NULLIF(TRIM(CAST({q(coluna)} AS VARCHAR)), '')"


def expr_data(coluna: str, tipo: str) -> str:
    """Data como DATE. Texto 'AAAAMMDD' (formato do catálogo) ou 'AAAA-MM-DD'.

    Datas fora de 1990..ano seguinte viram NULL (há lixo como '01221203').
    """
    t = tipo.upper()
    if t == "DATE":
        d = q(coluna)
    elif t.startswith("TIMESTAMP"):
        d = f"CAST({q(coluna)} AS DATE)"
    else:
        txt = f"NULLIF(TRIM(CAST({q(coluna)} AS VARCHAR)), '')"
        d = f"CAST(COALESCE(TRY_STRPTIME({txt}, '%Y%m%d'), TRY_STRPTIME({txt}, '%Y-%m-%d')) AS DATE)"
    return f"(CASE WHEN {d} BETWEEN DATE '1990-01-01' AND current_date + INTERVAL 366 DAY THEN {d} END)"


def abrir(con: duckdb.DuckDBPyConnection, caminho: Path, doenca: Doenca) -> tuple[dict[str, str], list[str]]:
    """Cria as views `bruto` e `norm`. Retorna (schema bruto, colunas do config ausentes)."""
    rel = con.read_parquet(str(caminho))
    rel.create_view("bruto", replace=True)
    schema = {c: str(t) for c, t in zip(rel.columns, rel.types)}
    por_maiuscula = {c.upper(): c for c in schema}

    selecoes: list[str] = []
    ausentes: list[str] = []
    for col in doenca.colunas_codigo:
        real = por_maiuscula.get(col)
        if real is None:
            ausentes.append(col)
            selecoes.append(f"NULL::VARCHAR AS {q(col)}")
        else:
            selecoes.append(f"{expr_codigo(real, schema[real])} AS {q(col)}")
    for col in doenca.colunas_data:
        real = por_maiuscula.get(col)
        if real is None:
            ausentes.append(col)
            selecoes.append(f"NULL::DATE AS {q(col)}")
        else:
            selecoes.append(f"{expr_data(real, schema[real])} AS {q(col)}")
    con.execute(f"CREATE OR REPLACE TEMP VIEW norm AS SELECT {', '.join(selecoes)} FROM bruto")
    return schema, ausentes


# ------------------------------------------------------------------ silver

# NU_IDADE_N: 4 dígitos = unidade + valor (1 hora, 2 dia, 3 mês, 4 ano); menos
# de 1 ano conta como 0. Com 1 a 3 dígitos, já é a idade em anos (visto em
# DENGBR22 etc.: bate com NU_ANO - ANO_NASC).
_IDADE = f"""
CASE
  WHEN NOT regexp_full_match(COALESCE(NU_IDADE_N, ''), '[0-9]{{1,4}}') THEN NULL
  WHEN length(NU_IDADE_N) = 4 THEN
    CASE left(NU_IDADE_N, 1)
      WHEN '4' THEN CAST(substr(NU_IDADE_N, 2) AS INTEGER)
      WHEN '1' THEN 0 WHEN '2' THEN 0 WHEN '3' THEN 0
    END
  ELSE CAST(NU_IDADE_N AS INTEGER)
END"""


def _uf(coluna: str) -> str:
    return f"(CASE WHEN TRY_CAST({coluna} AS SMALLINT) IN ({', '.join(map(str, UFS))}) THEN TRY_CAST({coluna} AS SMALLINT) END)"


def nomes_definicoes(doencas: list[Doenca]) -> list[str]:
    """União dos nomes de definição de todas as doenças (`confirmado` primeiro)."""
    nomes = ["confirmado"]
    for d in doencas:
        nomes += [n for n in d.definicoes if n not in nomes]
    return nomes


def sql_silver(doenca: Doenca, ano_arquivo: int, todas_definicoes: list[str]) -> str:
    """SELECT da camada silver sobre a view `norm` (depois de `abrir`)."""
    filtro = f"({doenca.filtro})" if doenca.filtro else "TRUE"
    defs = []
    for nome in todas_definicoes:
        expr = doenca.definicoes.get(nome)
        valor = f"COALESCE(({expr}), FALSE)" if expr else "NULL::BOOLEAN"
        defs.append(f"{valor} AS {q('def_' + nome)}")
    dt_diag = "DT_DIAG" if "DT_DIAG" in doenca.colunas_data else "NULL::DATE"
    return f"""
SELECT
  {literal(doenca.slug)} AS doenca,
  CAST({int(ano_arquivo)} AS SMALLINT) AS ano_arquivo,
  ano_notificacao, dt_notific, dt_sin_pri, dt_diag, semana_sin_pri,
  uf_res, uf_not, mun_res, idade_anos,
  CASE
    WHEN idade_anos IS NULL THEN {literal(FAIXA_IGNORADA)}
    WHEN idade_anos >= 90 THEN {literal(FAIXA_FINAL)}
    ELSE CAST(idade_anos // 5 * 5 AS VARCHAR) || '-' || CAST(idade_anos // 5 * 5 + 4 AS VARCHAR)
  END AS faixa_etaria,
  sexo, raca, classi_fin, criterio, evolucao,
  {', '.join(q('def_' + n) for n in todas_definicoes)}
FROM (
  SELECT
    TRY_CAST(NU_ANO AS SMALLINT) AS ano_notificacao,
    DT_NOTIFIC AS dt_notific,
    DT_SIN_PRI AS dt_sin_pri,
    {dt_diag} AS dt_diag,
    CASE WHEN length(SEM_PRI) = 6 THEN TRY_CAST(SEM_PRI AS INTEGER) END AS semana_sin_pri,
    {_uf('SG_UF')} AS uf_res,
    {_uf('SG_UF_NOT')} AS uf_not,
    CASE WHEN regexp_full_match(COALESCE(ID_MN_RESI, ''), '[0-9]{{6,7}}') THEN left(ID_MN_RESI, 6) END AS mun_res,
    CASE WHEN ({_IDADE}) BETWEEN 0 AND {IDADE_MAX} THEN ({_IDADE}) END AS idade_anos,
    CASE CS_SEXO WHEN 'M' THEN 'M' WHEN 'F' THEN 'F' ELSE 'I' END AS sexo,
    CASE WHEN CS_RACA IN ('1','2','3','4','5') THEN CS_RACA ELSE '9' END AS raca,
    CLASSI_FIN AS classi_fin,
    CRITERIO AS criterio,
    EVOLUCAO AS evolucao,
    {', '.join(defs)}
  FROM norm
  WHERE {filtro}
)"""
