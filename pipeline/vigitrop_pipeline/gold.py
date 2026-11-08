"""Camada gold: o que o app lê (via DuckDB, sem MySQL).

data/gold/
  casos.parquet      doenca, definicao, ano, uf, sexo, faixa_etaria, raca, casos
                     - ano = ano de notificação (NU_ANO), como no TCC
                     - uf = código IBGE da UF de RESIDÊNCIA; NULL = ignorada
                     - sexo M/F/I; raca 1-5, 9 = ignorada; faixa '0-4'..'90 ou mais', 'Ignorado'
                     - sem linhas agregadas ("Brasil", "Todos"): o total é sempre a soma
                     - uma linha conta em todas as definições que satisfaz; o app filtra
                       `definicao` (padrão em doencas.parquet)
  populacao.parquet  gerado por populacao.py
  doencas.parquet    doenca, codigo, nome, definicao, expressao, padrao, filtro, notas
  arquivos.parquet   doenca, codigo, ano, status (FINAL/PRELIM), data_coleta, linhas, aviso
  meta.json          data de geração, versões, fontes
"""

from __future__ import annotations

import json
import logging
from datetime import datetime
from importlib import metadata
from pathlib import Path

import duckdb

from . import __version__
from .ambiente import Pastas
from .catalogo import ler_manifesto
from .config import Config
from .normalizacao import literal, nomes_definicoes, q
from .silver import SILVER_VERSAO, pasta_casos

log = logging.getLogger("vigitrop.gold")


def pasta(pastas: Pastas) -> Path:
    return pastas.raiz / "gold"


def _copiar(con: duckdb.DuckDBPyConnection, sql: str, destino: Path) -> None:
    tmp = destino.with_suffix(".tmp.parquet")
    con.execute(f"COPY ({sql}) TO {literal(str(tmp))} (FORMAT parquet, COMPRESSION zstd)")
    tmp.replace(destino)


def gerar(pastas: Pastas, cfg: Config) -> None:
    g = pasta(pastas)
    g.mkdir(parents=True, exist_ok=True)
    if not (g / "populacao.parquet").exists():
        raise SystemExit("Falta data/gold/populacao.parquet. Rode `populacao` antes.")
    arquivos_silver = sorted(pasta_casos(pastas).glob("*/*.parquet"))
    if not arquivos_silver:
        raise SystemExit("Silver vazia. Rode `silver` antes.")

    manifesto = ler_manifesto(pastas)
    slugs_silver = {p.parent.name for p in arquivos_silver}
    faltando = sorted(d.codigo for d in cfg.doencas.values() if d.slug not in slugs_silver)
    if faltando:
        log.warning("Doenças sem dados na silver (ficam fora do gold): %s", " ".join(faltando))

    con = duckdb.connect()
    lista = "[" + ", ".join(literal(str(p)) for p in arquivos_silver) + "]"
    con.execute(f"CREATE VIEW s AS SELECT * FROM read_parquet({lista}, union_by_name = true)")

    ano_max = con.execute("SELECT max(ano_arquivo) FROM s").fetchone()[0]
    fora = con.execute(
        f"SELECT count(*) FILTER (WHERE ano_notificacao IS NULL), "
        f"count(*) FILTER (WHERE ano_notificacao NOT BETWEEN {cfg.ano_inicio} AND {ano_max}) FROM s"
    ).fetchone()
    log.info("Notificações fora do gold: %d sem NU_ANO, %d com NU_ANO fora de %d-%d", fora[0], fora[1], cfg.ano_inicio, ano_max)

    partes = [
        f"SELECT doenca, {literal(n)} AS definicao, ano_notificacao AS ano, uf_res AS uf, sexo, faixa_etaria, raca "
        f"FROM s WHERE {q('def_' + n)}"
        for n in nomes_definicoes(list(cfg.doencas.values()))
    ]
    _copiar(con, f"""
        SELECT doenca, definicao, ano, uf, sexo, faixa_etaria, raca, CAST(count(*) AS INTEGER) AS casos
        FROM ({' UNION ALL '.join(partes)})
        WHERE ano BETWEEN {cfg.ano_inicio} AND {ano_max}
        GROUP BY ALL
        ORDER BY doenca, definicao, ano, uf, sexo, faixa_etaria, raca""", g / "casos.parquet")

    linhas_def = [
        (d.slug, d.codigo, d.nome, nome, expr, nome == d.padrao, d.filtro, d.notas)
        for d in cfg.doencas.values()
        for nome, expr in d.definicoes.items()
    ]
    con.execute("CREATE TABLE defs (doenca VARCHAR, codigo VARCHAR, nome VARCHAR, definicao VARCHAR, "
                "expressao VARCHAR, padrao BOOLEAN, filtro VARCHAR, notas VARCHAR)")
    con.executemany("INSERT INTO defs VALUES (?, ?, ?, ?, ?, ?, ?, ?)", linhas_def)
    _copiar(con, "SELECT * FROM defs", g / "doencas.parquet")

    con.execute("CREATE TABLE arqs (doenca VARCHAR, codigo VARCHAR, ano SMALLINT, status VARCHAR, "
                "data_coleta VARCHAR, linhas BIGINT, aviso VARCHAR)")
    con.executemany(
        "INSERT INTO arqs VALUES (?, ?, ?, ?, ?, ?, ?)",
        [(r["doenca"], r["codigo"], int(r["ano"]), r["status"], r["data_coleta"], int(r["linhas"]), r.get("aviso") or None) for r in manifesto],
    )
    _copiar(con, "SELECT * FROM arqs ORDER BY doenca, ano", g / "arquivos.parquet")

    resumo = con.execute(f"SELECT count(*), sum(casos) FROM read_parquet({literal(str(g / 'casos.parquet'))})").fetchone()
    con.close()

    meta = {
        "gerado_em": datetime.now().isoformat(timespec="seconds"),
        "versao_pipeline": __version__,
        "versao_silver": SILVER_VERSAO,
        "pysus": metadata.version("pysus"),
        "duckdb": duckdb.__version__,
        "ano_inicio": cfg.ano_inicio,
        "ano_fim": int(ano_max),
        "ano_referencia": "ano de notificação (NU_ANO)",
        "fonte_casos": "SINAN/DataSUS, via catálogo do PySUS (espelho S3 do FTP do DataSUS)",
        "fonte_populacao": cfg.populacao_url,
        "ultima_coleta": max((r["data_coleta"] for r in manifesto), default=None),
    }
    (g / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    tamanho = sum(p.stat().st_size for p in g.glob("*") if p.is_file())
    log.info("Gold: %s linhas em casos.parquet (%s notificações contadas, somando definições); %.1f MB em %s",
             f"{resumo[0]:,}".replace(",", "."), f"{int(resumo[1] or 0):,}".replace(",", "."), tamanho / 1e6, g)
