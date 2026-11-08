"""Inspeção dos arquivos brutos: schema, valores das colunas-chave e contagens.

Serve para descobrir o que o PySUS 2.x devolve (nomes, tipos, espaços em
CLASSI_FIN, UF como texto ou número...) e para conferir as definições de caso
de config/doencas.yaml contra o dump antigo e a Tabela 1 do TCC.

Saídas em data/relatorios/:
  inspecao_<carimbo>.md   relatório legível (só agregados, sem dado individual)
  contagens.csv           doença × ano × definição, para validação
"""

from __future__ import annotations

import csv
import logging
from datetime import datetime
from pathlib import Path

import duckdb

from .ambiente import Pastas
from .catalogo import ler_manifesto
from .config import Doenca
from .normalizacao import abrir
from .normalizacao import q as _q

log = logging.getLogger("vigitrop.inspecao")

# Quantos valores distintos mostrar por coluna (padrão: 15)
LIMITE_VALORES = {"SG_UF": 30, "SG_UF_NOT": 30, "NU_ANO": 25, "SEM_PRI": 10, "SEM_NOT": 10, "NU_IDADE_N": 10, "ID_MN_RESI": 5}


def contar(con: duckdb.DuckDBPyConnection, doenca: Doenca) -> dict[str, int]:
    filtro = f"({doenca.filtro})" if doenca.filtro else "TRUE"
    partes = ["count(*) AS total", f"count(*) FILTER (WHERE {filtro}) AS recorte"]
    for nome, expr in doenca.definicoes.items():
        partes.append(f"count(*) FILTER (WHERE {filtro} AND ({expr})) AS {_q(nome)}")
    linha = con.execute(f"SELECT {', '.join(partes)} FROM norm").fetchone()
    nomes = ["total", "recorte", *doenca.definicoes]
    return dict(zip(nomes, (int(x) for x in linha)))


def _valores(con: duckdb.DuckDBPyConnection, coluna: str, limite: int) -> tuple[list[tuple[object, int]], int]:
    q = _q(coluna)
    top = con.execute(f"SELECT {q} AS v, count(*) AS n FROM bruto GROUP BY 1 ORDER BY 2 DESC, 1 LIMIT {limite}").fetchall()
    distintos = con.execute(f"SELECT count(DISTINCT {q}) + max(CASE WHEN {q} IS NULL THEN 1 ELSE 0 END) FROM bruto").fetchone()[0]
    return top, int(distintos or 0)


def _fmt(n: int) -> str:
    return f"{n:,}".replace(",", ".")


def inspecionar(pastas: Pastas, doencas: list[Doenca], anos: list[int] | None) -> Path:
    manifesto = ler_manifesto(pastas)
    codigos = {d.codigo: d for d in doencas}
    alvos = [r for r in manifesto if r["codigo"] in codigos and (anos is None or int(r["ano"]) in anos)]
    if not alvos:
        raise SystemExit("Nada no manifesto para inspecionar. Rode `baixar` antes.")

    carimbo = datetime.now().strftime("%Y%m%d_%H%M%S")
    relatorio = pastas.relatorios / f"inspecao_{carimbo}.md"
    md: list[str] = [f"# Inspeção dos arquivos brutos ({carimbo})", ""]
    contagens: list[dict[str, object]] = []

    con = duckdb.connect()
    for d in doencas:
        dele = sorted((r for r in alvos if r["codigo"] == d.codigo), key=lambda r: int(r["ano"]))
        if not dele:
            continue
        log.info("Inspecionando %s (%d arquivos)", d.codigo, len(dele))
        md += [f"## {d.nome} ({d.codigo})", ""]
        if d.filtro:
            md.append(f"Recorte: `{d.filtro}`  ")
        for nome, expr in d.definicoes.items():
            marca = " **(padrão)**" if nome == d.padrao else ""
            md.append(f"Definição `{nome}`{marca}: `{expr}`  ")
        md.append("")

        cab = ["ano", "status", "total", "recorte", *d.definicoes]
        md += ["| " + " | ".join(cab) + " |", "|" + "---|" * len(cab)]
        detalhes: list[str] = []
        schemas: dict[str, tuple[int, list[int]]] = {}

        for r in dele:
            ano = int(r["ano"])
            caminho = pastas.raiz / r["arquivo_local"]
            schema, ausentes = abrir(con, caminho, d)
            assinatura = ", ".join(f"{c} {t}" for c, t in schema.items())
            schemas.setdefault(assinatura, (len(schema), []))[1].append(ano)
            n = contar(con, d)
            contagens.append({"doenca": d.slug, "codigo": d.codigo, "ano": ano, "status": r["status"], "data_coleta": r["data_coleta"], **n})
            md.append("| " + " | ".join([str(ano), r["status"], *(_fmt(n[k]) for k in cab[2:])]) + " |")
            log.info("  %s %s: %s", d.codigo, ano, {k: v for k, v in n.items()})

            detalhes += [f"### {d.codigo} {ano} ({r['status']}, {r['arquivo_local']})", ""]
            if ausentes:
                detalhes += [f"Colunas configuradas AUSENTES no arquivo: {', '.join(ausentes)}", ""]
            por_maiuscula = {c.upper(): c for c in schema}
            for col in d.colunas_codigo:
                real = por_maiuscula.get(col)
                if real is None:
                    continue
                top, distintos = _valores(con, real, LIMITE_VALORES.get(col, 15))
                vals = ", ".join(f"{v!r}: {_fmt(k)}" for v, k in top)
                mais = f" … ({distintos} distintos)" if distintos > len(top) else ""
                detalhes.append(f"- `{col}` {schema[real]} → {vals}{mais}")
                if col == "NU_IDADE_N":
                    unid = con.execute(
                        f"SELECT left(CAST({_q(real)} AS VARCHAR), 1) AS u, count(*) FROM bruto GROUP BY 1 ORDER BY 1"
                    ).fetchall()
                    detalhes.append(f"  - 1º dígito (unidade): {', '.join(f'{u!r}: {_fmt(k)}' for u, k in unid)}")
            for col in d.colunas_data:
                real = por_maiuscula.get(col)
                if real is None:
                    continue
                mn, mx, nulos = con.execute(f"SELECT min({_q(real)}), max({_q(real)}), count(*) - count({_q(real)}) FROM bruto").fetchone()
                detalhes.append(f"- `{col}` {schema[real]} → min {mn!r}, max {mx!r}, nulos {_fmt(nulos)}")
            detalhes.append("")

        md.append("")
        md += ["### Schemas (todas as colunas)", ""]
        for assinatura, (ncol, anos_iguais) in schemas.items():
            md += [f"**Anos {', '.join(map(str, anos_iguais))}** ({ncol} colunas):", "", "```", assinatura, "```", ""]
        md += detalhes

    con.close()
    relatorio.write_text("\n".join(md), encoding="utf-8")

    # contagens.csv acumula entre rodadas: substitui só doença × ano inspecionados agora.
    destino_csv = pastas.relatorios / "contagens.csv"
    linhas: dict[tuple[str, int], dict[str, object]] = {}
    if destino_csv.exists():
        with destino_csv.open(newline="", encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                linhas[(r["codigo"], int(r["ano"]))] = r
    for c in contagens:
        linhas[(str(c["codigo"]), int(c["ano"]))] = c
    colunas = ["doenca", "codigo", "ano", "status", "data_coleta", "total", "recorte"]
    for c in linhas.values():
        colunas += [k for k in c if k not in colunas]
    with destino_csv.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=colunas, restval="")
        w.writeheader()
        w.writerows(sorted(linhas.values(), key=lambda r: (str(r["doenca"]), int(r["ano"]))))

    log.info("Relatório: %s", relatorio)
    log.info("Contagens: %s", destino_csv)
    return relatorio
