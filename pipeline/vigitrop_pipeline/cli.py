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
    com_filtro = {
        "listar": "lista o que o catálogo do PySUS tem (anos FINAL/PRELIM), sem baixar",
        "baixar": "baixa os arquivos brutos para data/cache e atualiza data/bronze/manifesto.csv",
        "inspecionar": "relatório de schema e contagens por definição de caso (offline)",
        "silver": "bruto -> data/silver/casos (um registro por notificação; incremental)",
    }
    sem_filtro = {
        "populacao": "baixa a projeção do IBGE (revisão 2024) e gera data/gold/populacao.parquet",
        "gold": "silver -> data/gold/casos.parquet + doencas, arquivos, meta",
        "tendencia": "tendência da incidência Brasil (joinpoint): data/gold/tendencia.parquet "
                     "+ comparação com o TCC (data/relatorios/tendencia_tcc.csv)",
        "validar": "compara o gold com a Tabela 1 do TCC (data/relatorios/validacao_tcc.csv)",
        "executar": "tudo, em ordem: baixar, populacao, silver, gold, tendencia, validar",
    }
    for nome, texto in {**com_filtro, **sem_filtro}.items():
        s = sub.add_parser(nome, help=texto, description=texto)
        if nome in com_filtro:
            s.add_argument("--doencas", nargs="+", metavar="DOENCA",
                           help="códigos SINAN ou nomes do config (ex.: RAIV CHAG). Padrão: todas")
            s.add_argument("--anos", type=_anos, metavar="ANOS",
                           help="ex.: 2024 | 2007-2024 | 2019,2021-2023. Padrão: do ano_inicio do config em diante")
        if nome in ("silver", "populacao"):
            s.add_argument("--forcar", action="store_true", help="refaz mesmo sem mudança")
    return p


def _erro_de_rede(e: BaseException | None) -> bool:
    while e is not None:
        if isinstance(e, OSError) or type(e).__module__.split(".")[0] in ("httpx", "httpcore", "botocore", "aioftp"):
            return True
        e = e.__cause__ or e.__context__
    return False


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    cfg = carregar(args.config)
    doencas = cfg.selecionar(getattr(args, "doencas", None))
    anos = getattr(args, "anos", None)
    forcar = getattr(args, "forcar", False)
    todas = list(cfg.doencas.values())

    pastas = Pastas(args.dados)
    pastas.criar()
    arquivo_log = configurar_log(pastas, args.comando)
    configurar_pysus(pastas)
    log.info("vigitrop_pipeline %s | %s | doenças: %s | anos: %s", __version__, args.comando,
             " ".join(d.codigo for d in doencas), anos or f">= {cfg.ano_inicio}")

    try:
        c = args.comando
        if c == "listar":
            from .catalogo import listar
            listar(pastas, doencas, anos, cfg.ano_inicio)
        if c in ("baixar", "executar"):
            from .catalogo import baixar
            baixar(pastas, doencas, anos, cfg.ano_inicio)
        if c == "inspecionar":
            from .inspecao import inspecionar
            inspecionar(pastas, doencas, anos)
        if c in ("populacao", "executar"):
            from . import populacao
            populacao.gerar(pastas, cfg.populacao_url, forcar)
        if c in ("silver", "executar"):
            from . import silver
            silver.gerar(pastas, todas, doencas, anos, forcar)
        if c in ("gold", "executar"):
            from . import gold
            gold.gerar(pastas, cfg)
        if c in ("tendencia", "executar"):
            from . import tendencia
            tendencia.gerar(pastas, cfg)
        if c in ("validar", "executar"):
            from .validacao import validar
            validar(pastas, cfg)
    except SystemExit:
        raise
    except Exception as e:
        log.exception("Falhou. Log completo em %s", arquivo_log)
        if args.comando in ("listar", "baixar", "executar") and _erro_de_rede(e):
            log.error("Se o erro for de rede/proxy: o catálogo do PySUS fica em "
                      "https://nbg1.your-objectstorage.com/pysus/ (precisa de HTTPS liberado para esse host).")
        return 1
    log.info("Pronto. Log em %s", arquivo_log)
    return 0
