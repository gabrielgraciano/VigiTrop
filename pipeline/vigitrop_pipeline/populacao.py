"""População: projeção do IBGE, revisão 2024 (UF × sexo × idade simples, 2000-2070).

É o mesmo denominador do TCC: bate exato com a tabela `populacao_brasil` do
dump antigo (conferido em 2010, 2015, 2020, 2022 e 2024).

Saídas:
  data/bronze/ibge/<arquivo>.xlsx    planilha original (baixada uma vez)
  data/gold/populacao.parquet        ano, uf, sexo (M/F), faixa_etaria, populacao
                                     só UFs: o Brasil é a soma (sem linha agregada)
"""

from __future__ import annotations

import hashlib
import logging
import time
from pathlib import Path

import duckdb

from .ambiente import Pastas
from .normalizacao import FAIXA_FINAL, UFS, literal

log = logging.getLogger("vigitrop.populacao")

SEXOS = {"Homens": "M", "Mulheres": "F"}


def baixar(pastas: Pastas, url: str, forcar: bool = False) -> Path:
    import httpx

    destino = pastas.bronze / "ibge" / url.rsplit("/", 1)[-1]
    if destino.exists() and not forcar:
        log.info("Planilha do IBGE já baixada: %s", destino)
        return destino
    destino.parent.mkdir(parents=True, exist_ok=True)
    tmp = destino.with_suffix(destino.suffix + ".tmp")
    for tentativa in range(1, 5):
        try:
            with httpx.stream("GET", url, timeout=120, follow_redirects=True) as resp:
                resp.raise_for_status()
                with tmp.open("wb") as fh:
                    for bloco in resp.iter_bytes(1 << 20):
                        fh.write(bloco)
            break
        except httpx.HTTPError as e:
            if tentativa == 4:
                raise
            log.warning("Falhou (%s); tentativa %d/4 em %d s", e, tentativa + 1, 5 * tentativa)
            time.sleep(5 * tentativa)
    tmp.replace(destino)
    sha = hashlib.sha256(destino.read_bytes()).hexdigest()
    log.info("Baixado %s (%.1f MB, sha256 %s…)", destino, destino.stat().st_size / 1e6, sha[:12])
    return destino


def _ler_planilha(xlsx: Path) -> tuple[list[tuple[int, int, str, int, int]], dict[int, int]]:
    """Retorna (linhas [ano, uf, sexo, idade, pop] só de UFs e H/M, total Brasil 'Ambos' por ano)."""
    import openpyxl

    wb = openpyxl.load_workbook(xlsx, read_only=True, data_only=True)
    ws = wb.worksheets[0]
    linhas: list[tuple[int, int, str, int, int]] = []
    brasil: dict[int, int] = {}
    anos: list[int] | None = None
    for row in ws.iter_rows(values_only=True):
        if anos is None:
            if row and row[0] == "IDADE":
                # Cabeçalho: IDADE, SEXO, CÓD., SIGLA, LOCAL, 2000, 2001, ...
                # (no arquivo, os anos depois do primeiro são fórmulas =F6+1).
                inicio = int(row[5])
                anos = [inicio + i for i in range(len(row) - 5)]
                if any(isinstance(v, int) and v != a for v, a in zip(row[5:], anos)):
                    raise ValueError("cabeçalho de anos inesperado na planilha do IBGE")
            continue
        idade, sexo, cod = row[0], row[1], row[2]
        if idade is None or sexo is None or cod is None:
            continue
        valores = row[5 : 5 + len(anos)]
        if cod == 0 and sexo == "Ambos":
            for a, v in zip(anos, valores):
                brasil[a] = brasil.get(a, 0) + int(v)
        elif cod in UFS and sexo in SEXOS:
            for a, v in zip(anos, valores):
                linhas.append((a, int(cod), SEXOS[sexo], int(idade), int(v)))
    if anos is None:
        raise ValueError("cabeçalho IDADE/SEXO não encontrado na planilha do IBGE")
    return linhas, brasil


def gerar(pastas: Pastas, url: str, forcar: bool = False) -> Path:
    xlsx = baixar(pastas, url, forcar)
    linhas, brasil = _ler_planilha(xlsx)
    log.info("Planilha lida: %s linhas (UF × sexo × idade × ano)", f"{len(linhas):,}".replace(",", "."))

    import pyarrow as pa

    colunas = list(zip(*linhas))
    tabela = pa.table({
        "ano": pa.array(colunas[0], pa.int16()),
        "uf": pa.array(colunas[1], pa.int16()),
        "sexo": pa.array(colunas[2], pa.string()),
        "idade": pa.array(colunas[3], pa.int16()),
        "populacao": pa.array(colunas[4], pa.int64()),
    })
    con = duckdb.connect()
    con.register("p_arrow", tabela)
    con.execute("CREATE TABLE p AS SELECT * FROM p_arrow")

    # Conferência: soma das UFs (H + M) = linha Brasil "Ambos" da própria planilha.
    somas = dict(con.execute("SELECT ano, sum(populacao) FROM p GROUP BY 1").fetchall())
    diferentes = {a: (somas.get(a), brasil[a]) for a in brasil if somas.get(a) != brasil[a]}
    if diferentes:
        raise ValueError(f"soma das UFs diferente do total Brasil: {diferentes}")
    idades = con.execute("SELECT min(idade), max(idade) FROM p").fetchone()
    if idades != (0, 90):
        raise ValueError(f"idades inesperadas na planilha: {idades} (esperado 0 a 90, 90 = 90 ou mais)")

    destino = pastas.raiz / "gold" / "populacao.parquet"
    destino.parent.mkdir(parents=True, exist_ok=True)
    tmp = destino.with_suffix(".tmp.parquet")
    con.execute(f"""
        COPY (
          SELECT ano, uf, sexo,
                 CASE WHEN idade >= 90 THEN {literal(FAIXA_FINAL)}
                      ELSE CAST(idade // 5 * 5 AS VARCHAR) || '-' || CAST(idade // 5 * 5 + 4 AS VARCHAR) END AS faixa_etaria,
                 CAST(sum(populacao) AS BIGINT) AS populacao
          FROM p GROUP BY ALL ORDER BY ALL
        ) TO {literal(str(tmp))} (FORMAT parquet, COMPRESSION zstd)""")
    tmp.replace(destino)
    con.close()
    log.info("População: %s (%d a %d; Brasil 2024 = %s)", destino, min(brasil), max(brasil), f"{brasil.get(2024, 0):,}".replace(",", "."))
    return destino
