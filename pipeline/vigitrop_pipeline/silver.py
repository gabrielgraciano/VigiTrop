"""Camada silver: um registro por notificação, num schema único para as 9 doenças.

Saída: data/silver/casos/<doenca>/<ano_arquivo>.parquet (um por arquivo bruto).
Colunas: ver normalizacao.sql_silver(). As definições de caso viram colunas
booleanas `def_<nome>` (NULL quando a doença não tem aquela definição).

Incremental: refaz um arquivo só se o bruto mudou (sha256 do manifesto) ou se
a configuração da doença / a versão da silver mudou. Estado em
data/silver/estado.json.
"""

from __future__ import annotations

import dataclasses
import hashlib
import json
import logging
from pathlib import Path

import duckdb

from .ambiente import Pastas
from .catalogo import ler_manifesto
from .config import Doenca
from .normalizacao import abrir, literal, nomes_definicoes, sql_silver

log = logging.getLogger("vigitrop.silver")

# Mude ao alterar a lógica de normalizacao.sql_silver(): força refazer tudo.
SILVER_VERSAO = 1


def pasta_casos(pastas: Pastas) -> Path:
    return pastas.raiz / "silver" / "casos"


def _assinatura(doenca: Doenca, todas: list[str]) -> str:
    bruto = json.dumps({"v": SILVER_VERSAO, "doenca": dataclasses.asdict(doenca), "definicoes": todas}, sort_keys=True)
    return hashlib.sha256(bruto.encode()).hexdigest()[:16]


def gerar(pastas: Pastas, todas_doencas: list[Doenca], doencas: list[Doenca], anos: list[int] | None, forcar: bool = False) -> None:
    todas = nomes_definicoes(todas_doencas)  # schema igual para todas, mesmo rodando só algumas
    por_codigo = {d.codigo: d for d in doencas}
    manifesto = [r for r in ler_manifesto(pastas) if r["codigo"] in por_codigo and (anos is None or int(r["ano"]) in anos)]
    if not manifesto:
        raise SystemExit("Nada no manifesto para processar. Rode `baixar` antes.")

    arq_estado = pastas.raiz / "silver" / "estado.json"
    estado: dict[str, dict[str, str]] = json.loads(arq_estado.read_text()) if arq_estado.exists() else {}

    con = duckdb.connect()
    feitos = pulados = 0
    for r in sorted(manifesto, key=lambda r: (r["doenca"], int(r["ano"]))):
        d = por_codigo[r["codigo"]]
        ano = int(r["ano"])
        chave = f"{d.codigo}/{ano}"
        destino = pasta_casos(pastas) / d.slug / f"{ano}.parquet"
        alvo = {"sha256": r["sha256"], "assinatura": _assinatura(d, todas)}
        if not forcar and destino.exists() and estado.get(chave) == alvo:
            pulados += 1
            continue

        abrir(con, pastas.raiz / r["arquivo_local"], d)
        destino.parent.mkdir(parents=True, exist_ok=True)
        tmp = destino.with_suffix(".tmp.parquet")
        con.execute(f"COPY ({sql_silver(d, ano, todas)}) TO {literal(str(tmp))} (FORMAT parquet, COMPRESSION zstd)")
        tmp.replace(destino)
        linhas = con.execute(f"SELECT count(*) FROM read_parquet({literal(str(destino))})").fetchone()[0]
        log.info("  %s %s: %s linhas", d.codigo, ano, f"{linhas:,}".replace(",", "."))
        estado[chave] = alvo
        arq_estado.write_text(json.dumps(estado, indent=1, sort_keys=True))
        feitos += 1
    con.close()
    log.info("Silver: %d arquivo(s) gerado(s), %d sem mudança. Pasta: %s", feitos, pulados, pasta_casos(pastas))
