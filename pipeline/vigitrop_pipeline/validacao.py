"""Validação do gold contra a Tabela 1 do TCC (incidência Brasil por 100 mil).

Para cada doença usa a definição que reproduz a regra do TCC: `legado_tcc` se
existir, senão a definição padrão (nas doenças em que as duas coincidem).

Arquivo revisado pelo DataSUS depois da coleta do TCC (15/10/2024) não precisa
bater exato: a coluna `revisado_apos_tcc` mostra quais são.

Saída: data/relatorios/validacao_tcc.csv
"""

from __future__ import annotations

import csv
import logging
from pathlib import Path

import duckdb

from .ambiente import Pastas
from .catalogo import ler_manifesto
from .config import CONFIG_PADRAO, Config, Doenca
from .normalizacao import literal

log = logging.getLogger("vigitrop.validacao")

TABELA_TCC = CONFIG_PADRAO.parent / "tcc_tabela1.csv"
COLETA_TCC = "2024-10-15"


def definicao_tcc(d: Doenca) -> str:
    return "legado_tcc" if "legado_tcc" in d.definicoes else d.padrao


def validar(pastas: Pastas, cfg: Config) -> Path:
    g = pastas.raiz / "gold"
    tcc = [r for r in csv.DictReader(l for l in TABELA_TCC.open(encoding="utf-8") if not l.startswith("#"))]
    revisao = {(r["codigo"], int(r["ano"])): (r["modificado_origem"] or "")[:10] for r in ler_manifesto(pastas)}
    por_codigo = {d.codigo: d for d in cfg.doencas.values()}

    con = duckdb.connect()
    pop = dict(con.execute(f"SELECT ano, sum(populacao) FROM read_parquet({literal(str(g / 'populacao.parquet'))}) GROUP BY 1").fetchall())
    casos = {
        (doenca, definicao, ano): n
        for doenca, definicao, ano, n in con.execute(
            f"SELECT doenca, definicao, ano, sum(casos) FROM read_parquet({literal(str(g / 'casos.parquet'))}) GROUP BY ALL"
        ).fetchall()
    }
    con.close()

    saida: list[dict[str, object]] = []
    for r in tcc:
        d = por_codigo[r["codigo"]]
        ano = int(r["ano"])
        definicao = definicao_tcc(d)
        n = int(casos.get((d.slug, definicao, ano), 0))
        inc = n * 1e5 / pop[ano]
        ref = float(r["incidencia"])
        mod = revisao.get((d.codigo, ano), "")
        saida.append({
            "codigo": d.codigo, "ano": ano, "definicao": definicao, "casos": n, "populacao": pop[ano],
            "incidencia": round(inc, 2), "tcc": ref, "diferenca": round(inc - ref, 2),
            "diferenca_pct": round(100 * (inc - ref) / ref, 1) if ref else None,
            "bate": round(inc, 2) == ref,
            "arquivo_modificado": mod, "revisado_apos_tcc": mod > COLETA_TCC,
        })

    destino = pastas.relatorios / "validacao_tcc.csv"
    with destino.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(saida[0]))
        w.writeheader()
        w.writerows(saida)

    log.info("Validação contra a Tabela 1 do TCC (incidência Brasil por 100 mil):")
    log.info("  %-4s %-28s %5s %16s  %s", "", "definição", "anos", "bate (2 casas)", "maior diferença em arquivo não revisado (por 100 mil)")
    for cod in dict.fromkeys(r["codigo"] for r in saida):
        dele = [r for r in saida if r["codigo"] == cod]
        sem_rev = [r for r in dele if not r["revisado_apos_tcc"]]
        pior = max(sem_rev, key=lambda r: abs(r["diferenca"]), default=None)
        txt_pior = f"{pior['diferenca']:+.2f} ({pior['ano']})" if pior else "- (todos os arquivos revisados após o TCC)"
        log.info("  %-4s %-28s %5d %9d de %-4d  %s", cod, dele[0]["definicao"], len(dele),
                 sum(r["bate"] for r in dele), len(dele), txt_pior)
    log.info("Detalhes: %s", destino)
    return destino
