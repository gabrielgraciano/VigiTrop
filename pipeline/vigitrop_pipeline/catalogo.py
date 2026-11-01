"""Catálogo do PySUS e download dos arquivos brutos (camada bronze).

O PySUS 2.x lê, por padrão, um espelho em S3/Parquet do FTP do DataSUS
(`source="catalog"`). Cada arquivo do catálogo guarda o caminho original no
FTP (`origin_path`), e é por ele que se sabe se o ano é FINAL ou PRELIM.

Bronze = arquivos do PySUS em data/cache (sem cópia) + data/bronze/manifesto.csv,
uma linha por doença × ano, com status, tamanho, sha256 e data da coleta.
"""

from __future__ import annotations

import asyncio
import csv
import logging
import re
import sys
from dataclasses import dataclass, field, fields
from datetime import datetime
from pathlib import Path
from typing import Any

from .ambiente import Pastas
from .config import Doenca

log = logging.getLogger("vigitrop.catalogo")

COLUNAS_MANIFESTO = [
    "doenca",
    "codigo",
    "ano",
    "status",
    "arquivo_local",
    "caminho_catalogo",
    "caminho_origem",
    "bytes",
    "linhas",
    "sha256",
    "modificado_origem",
    "modificado_catalogo",
    "data_coleta",
]


@dataclass
class ArquivoRemoto:
    doenca: str
    codigo: str
    ano: int
    status: str
    caminho_catalogo: str
    caminho_origem: str | None
    bytes: int
    linhas: int
    sha256: str | None
    modificado_origem: str | None
    modificado_catalogo: str | None
    remoto: Any = field(repr=False, compare=False, default=None)

    def linha(self) -> dict[str, Any]:
        # Sem asdict(): ele faria deepcopy do objeto do PySUS em `remoto`.
        return {f.name: getattr(self, f.name) for f in fields(self) if f.name != "remoto"}


def status_pelo_caminho(caminho_origem: str | None) -> str:
    p = (caminho_origem or "").upper()
    if "/FINAIS/" in p:
        return "FINAL"
    if "/PRELIM/" in p:
        return "PRELIM"
    return "DESCONHECIDO"


def _iso(dt: Any) -> str | None:
    return dt.isoformat(timespec="seconds") if dt is not None else None


def _cliente():
    from pysus.api.client import PySUS
    from pysus.api.progress import disable_progress_bars

    if not sys.stderr.isatty():
        disable_progress_bars()  # log redirecionado: barras do tqdm só poluem
    return PySUS()


_NOME_SINAN = re.compile(r"^([A-Z]+)BR\d{2}$")


def codigo_do_arquivo(grupo: str | None, basename: str) -> str | None:
    """Código do agravo: grupo do catálogo ou, se faltar, o prefixo do nome do arquivo.

    O catálogo tem arquivos sem grupo (ex.: ESQUBR10, group_id NULL em 01/11/2026),
    que somem de uma consulta filtrada por grupo.
    """
    if grupo:
        return grupo.upper()
    m = _NOME_SINAN.match(basename.split(".")[0].upper())
    if not m:
        return None
    prefixo = m.group(1)
    return "LEIV" if prefixo == "LEI" else prefixo  # LEIBR22: nome errado na origem


async def _consultar(cli, doencas: list[Doenca], anos: list[int] | None, ano_inicio: int) -> list[ArquivoRemoto]:
    por_codigo = {d.codigo: d for d in doencas}
    # Sem filtro de grupo de propósito: ver codigo_do_arquivo().
    remotos = await cli.query(client="FTP", dataset="sinan", year=anos)

    escolhidos: dict[tuple[str, int], ArquivoRemoto] = {}
    for f in remotos:
        rec = f.record
        grupo = getattr(getattr(rec, "group", None), "name", None)
        codigo = codigo_do_arquivo(grupo, f.basename)
        if codigo not in por_codigo or rec.year is None:
            continue
        if anos is None and rec.year < ano_inicio:
            continue
        if grupo is None:
            log.warning("Arquivo sem grupo no catálogo, identificado pelo nome: %s -> %s", f.basename, codigo)
        a = ArquivoRemoto(
            doenca=por_codigo[codigo].slug,
            codigo=codigo,
            ano=int(rec.year),
            status=status_pelo_caminho(rec.origin_path),
            caminho_catalogo=str(f.path),
            caminho_origem=rec.origin_path,
            bytes=int(f.size),
            linhas=int(f.rows),
            sha256=f.sha256,
            modificado_origem=_iso(rec.origin_modified),
            modificado_catalogo=_iso(rec.modified),
            remoto=f,
        )
        chave = (codigo, a.ano)
        atual = escolhidos.get(chave)
        if atual is not None:
            log.warning("Dois arquivos para %s %s: %s e %s", codigo, a.ano, atual.caminho_origem, a.caminho_origem)
            if atual.status == "FINAL":
                continue  # FINAL ganha de PRELIM
        escolhidos[chave] = a

    return sorted(escolhidos.values(), key=lambda a: (a.doenca, a.ano))


def _escrever_csv(caminho: Path, colunas: list[str], linhas: list[dict[str, Any]]) -> None:
    caminho.parent.mkdir(parents=True, exist_ok=True)
    tmp = caminho.with_suffix(caminho.suffix + ".tmp")
    with tmp.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=colunas, extrasaction="ignore")
        w.writeheader()
        w.writerows(linhas)
    tmp.replace(caminho)


def ler_manifesto(pastas: Pastas) -> list[dict[str, str]]:
    if not pastas.manifesto.exists():
        return []
    with pastas.manifesto.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


# ---------------------------------------------------------------- comandos


def listar(pastas: Pastas, doencas: list[Doenca], anos: list[int] | None, ano_inicio: int) -> list[ArquivoRemoto]:
    async def _run():
        async with _cliente() as cli:
            return await _consultar(cli, doencas, anos, ano_inicio)

    arquivos = asyncio.run(_run())

    log.info("Catálogo PySUS (SINAN), a partir de %s:", ano_inicio)
    for d in doencas:
        dele = [a for a in arquivos if a.codigo == d.codigo]
        finais = [a.ano for a in dele if a.status == "FINAL"]
        prelim = [a.ano for a in dele if a.status == "PRELIM"]
        outros = [a.ano for a in dele if a.status == "DESCONHECIDO"]
        log.info(
            "  %-4s %-34s FINAL: %-11s PRELIM: %s%s",
            d.codigo,
            d.nome,
            _faixas(finais) or "-",
            _faixas(prelim) or "-",
            f"  ?: {_faixas(outros)}" if outros else "",
        )
    destino = pastas.relatorios / "catalogo.csv"
    _escrever_csv(destino, [c for c in COLUNAS_MANIFESTO if c not in ("arquivo_local", "data_coleta")], [a.linha() for a in arquivos])
    log.info("Lista completa em %s", destino)
    return arquivos


def baixar(pastas: Pastas, doencas: list[Doenca], anos: list[int] | None, ano_inicio: int) -> None:
    antigos = {(r["codigo"], int(r["ano"])): r for r in ler_manifesto(pastas)}
    agora = datetime.now().isoformat(timespec="seconds")

    async def _run() -> list[dict[str, Any]]:
        novas: list[dict[str, Any]] = []
        async with _cliente() as cli:
            arquivos = await _consultar(cli, doencas, anos, ano_inicio)
            if not arquivos:
                log.warning("Nada a baixar para %s", [d.codigo for d in doencas])
            for i, a in enumerate(arquivos, 1):
                log.info("[%d/%d] %s %s (%s, %.1f MB, %s linhas)", i, len(arquivos), a.codigo, a.ano, a.status, a.bytes / 1e6, f"{a.linhas:,}".replace(",", "."))
                local = await cli.download(a.remoto)
                caminho = Path(local.path)
                if not await a.remoto.verify(caminho):
                    raise RuntimeError(f"sha256 não confere: {caminho}")

                anterior = antigos.get((a.codigo, a.ano))
                mesmo = anterior is not None and anterior.get("sha256") == (a.sha256 or "") and anterior.get("bytes") == str(a.bytes)
                if anterior is None:
                    log.info("    novo")
                elif mesmo:
                    log.info("    sem mudança desde %s", anterior["data_coleta"])
                else:
                    log.info("    ATUALIZADO (antes: %s, %s)", anterior.get("status"), anterior.get("data_coleta"))

                linha = a.linha()
                linha["arquivo_local"] = pastas.relativo(caminho)
                linha["data_coleta"] = anterior["data_coleta"] if mesmo else agora
                novas.append(linha)
        return novas

    novas = asyncio.run(_run())

    todas = {(r["codigo"], int(r["ano"])): r for r in antigos.values()}
    for r in novas:
        todas[(r["codigo"], int(r["ano"]))] = r
    ordenadas = sorted(todas.values(), key=lambda r: (r["doenca"], int(r["ano"])))
    _escrever_csv(pastas.manifesto, COLUNAS_MANIFESTO, ordenadas)
    log.info("Manifesto: %s (%d arquivos)", pastas.manifesto, len(ordenadas))


def _faixas(anos: list[int]) -> str:
    """[2007, 2008, 2009, 2012] -> '2007-2009,2012'"""
    anos = sorted(set(anos))
    if not anos:
        return ""
    partes: list[str] = []
    ini = fim = anos[0]
    for a in anos[1:]:
        if a == fim + 1:
            fim = a
            continue
        partes.append(f"{ini}-{fim}" if fim > ini else f"{ini}")
        ini = fim = a
    partes.append(f"{ini}-{fim}" if fim > ini else f"{ini}")
    return ",".join(partes)
