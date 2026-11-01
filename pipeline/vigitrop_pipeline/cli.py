"""Linha de comando: python -m vigitrop_pipeline <comando> [opções]."""

from __future__ import annotations

import argparse
import logging
import os
from pathlib import Path

from . import __version__
from .ambiente import Pastas, configurar_log, configurar_pysus
from .config import carregar

log = logging.getLogger("vigitrop")


def _anos(texto: str) -> list[int]:
    """'2024' | '2007-2024' | '2019,2021-2023'"""
    anos: set[int] = set()
    for parte in texto.split(","):
        parte = parte.strip()
        if "-" in parte:
            ini, fim = (int(x) for x in parte.split("-", 1))
            if fim < ini:
                raise argparse.ArgumentTypeError(f"intervalo invertido: {parte}")
            anos.update(range(ini, fim + 1))
        elif parte:
            anos.add(int(parte))
    return sorted(anos)


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="vigitrop_pipeline", description=__doc__)
    p.add_argument("--dados", type=Path, default=Path(os.environ.get("VIGITROP_DADOS", "data")),
                   help="pasta de dados (padrão: $VIGITROP_DADOS ou ./data)")
    p.add_argument("--config", type=Path, default=None, help="config/doencas.yaml alternativo")
    p.add_argument("--version", action="version", version=__version__)

    sub = p.add_subparsers(dest="comando", required=True)
    ajuda = {
        "listar": "lista o que o catálogo do PySUS tem (anos FINAL/PRELIM), sem baixar",
        "baixar": "baixa os arquivos brutos para data/cache e atualiza data/bronze/manifesto.csv",
        "inspecionar": "relatório de schema e contagens por definição de caso (offline)",
    }
    for nome, texto in ajuda.items():
        s = sub.add_parser(nome, help=texto, description=texto)
        s.add_argument("--doencas", nargs="+", metavar="DOENCA",
                       help="códigos SINAN ou nomes do config (ex.: RAIV CHAG). Padrão: todas")
        s.add_argument("--anos", type=_anos, metavar="ANOS",
                       help="ex.: 2024 | 2007-2024 | 2019,2021-2023. Padrão: do ano_inicio do config em diante")
    return p


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    cfg = carregar(args.config)
    doencas = cfg.selecionar(args.doencas)

    pastas = Pastas(args.dados)
    pastas.criar()
    arquivo_log = configurar_log(pastas, args.comando)
    configurar_pysus(pastas)
    log.info("vigitrop_pipeline %s | %s | doenças: %s | anos: %s", __version__, args.comando,
             " ".join(d.codigo for d in doencas), args.anos or f">= {cfg.ano_inicio}")

    try:
        if args.comando == "listar":
            from .catalogo import listar
            listar(pastas, doencas, args.anos, cfg.ano_inicio)
        elif args.comando == "baixar":
            from .catalogo import baixar
            baixar(pastas, doencas, args.anos, cfg.ano_inicio)
        elif args.comando == "inspecionar":
            from .inspecao import inspecionar
            inspecionar(pastas, doencas, args.anos)
    except SystemExit:
        raise
    except Exception:
        log.exception("Falhou. Log completo em %s", arquivo_log)
        if args.comando in ("listar", "baixar"):
            log.error("Se o erro for de rede/proxy: o catálogo do PySUS fica em "
                      "https://nbg1.your-objectstorage.com/pysus/ (precisa de HTTPS liberado para esse host).")
        return 1
    log.info("Pronto. Log em %s", arquivo_log)
    return 0
