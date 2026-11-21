"""Pastas de dados, logging e configuração do PySUS."""

from __future__ import annotations

import logging
import os
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

log = logging.getLogger("vigitrop")


@dataclass(frozen=True)
class Pastas:
    raiz: Path

    @property
    def cache(self) -> Path:  # cache do PySUS (arquivos brutos baixados)
        return self.raiz / "cache"

    @property
    def bronze(self) -> Path:
        return self.raiz / "bronze"

    @property
    def manifesto(self) -> Path:
        return self.bronze / "manifesto.csv"

    @property
    def relatorios(self) -> Path:
        return self.raiz / "relatorios"

    @property
    def logs(self) -> Path:
        return self.raiz / "logs"

    def criar(self) -> None:
        for p in (self.cache, self.bronze, self.relatorios, self.logs):
            p.mkdir(parents=True, exist_ok=True)

    def relativo(self, p: Path) -> str:
        """Caminho relativo à raiz de dados, com '/' (portável Windows/Linux)."""
        return Path(p).resolve().relative_to(self.raiz.resolve()).as_posix()


def configurar_pysus(pastas: Pastas) -> None:
    """Precisa rodar ANTES do primeiro `import pysus`: o PySUS lê o cache na importação."""
    if "pysus" in sys.modules:
        raise RuntimeError("configurar_pysus() chamado depois de importar o pysus")
    cache = str(pastas.cache.resolve())
    os.environ["PYSUS_CACHEPATH"] = cache  # lido em pysus/__init__.py
    os.environ["PYSUS_CACHE_PATH"] = cache  # lido em pysus/config.py


def configurar_log(pastas: Pastas, comando: str) -> Path:
    """Loga no terminal e num arquivo em data/logs/ (para mandar de volta)."""
    carimbo = datetime.now().strftime("%Y%m%d_%H%M%S")
    arquivo = pastas.logs / f"{comando}_{carimbo}.log"
    fmt = logging.Formatter("%(asctime)s %(levelname)-7s %(message)s", "%Y-%m-%d %H:%M:%S")

    raiz = logging.getLogger()
    raiz.setLevel(logging.INFO)
    for h in list(raiz.handlers):
        raiz.removeHandler(h)
    tela = logging.StreamHandler(sys.stdout)
    tela.setFormatter(fmt)
    disco = logging.FileHandler(arquivo, encoding="utf-8")
    disco.setFormatter(fmt)
    raiz.addHandler(tela)
    raiz.addHandler(disco)
    return arquivo
