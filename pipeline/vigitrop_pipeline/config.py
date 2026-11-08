"""Leitura de config/doencas.yaml."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

import yaml

CONFIG_PADRAO = Path(__file__).resolve().parent.parent / "config" / "doencas.yaml"


@dataclass(frozen=True)
class Doenca:
    slug: str
    codigo: str
    nome: str
    tabela_legada: str | None
    colunas_codigo: tuple[str, ...]
    colunas_data: tuple[str, ...]
    definicoes: dict[str, str]
    padrao: str = "confirmado"  # definição que o app usa por padrão
    filtro: str | None = None
    notas: str | None = None
    texto_app: str | None = None  # texto para o usuário do app


@dataclass(frozen=True)
class Config:
    ano_inicio: int
    doencas: dict[str, Doenca] = field(default_factory=dict)
    populacao_url: str = ""

    def selecionar(self, nomes: list[str] | None) -> list[Doenca]:
        """Aceita slug ('raiva_humana') ou código SINAN ('RAIV'), sem caixa."""
        if not nomes:
            return list(self.doencas.values())
        por_chave: dict[str, Doenca] = {}
        for d in self.doencas.values():
            por_chave[d.slug.lower()] = d
            por_chave[d.codigo.lower()] = d
        escolhidas: list[Doenca] = []
        for n in nomes:
            d = por_chave.get(n.lower())
            if d is None:
                validos = ", ".join(sorted(x.codigo for x in self.doencas.values()))
                raise SystemExit(f"Doença desconhecida: {n!r}. Use uma de: {validos}")
            if d not in escolhidas:
                escolhidas.append(d)
        return escolhidas


def _unicos(*listas: list[str] | None) -> tuple[str, ...]:
    vistos: list[str] = []
    for lista in listas:
        for c in lista or []:
            c = c.upper()
            if c not in vistos:
                vistos.append(c)
    return tuple(vistos)


def carregar(caminho: Path | None = None) -> Config:
    caminho = Path(caminho or os.environ.get("VIGITROP_CONFIG") or CONFIG_PADRAO)
    bruto = yaml.safe_load(caminho.read_text(encoding="utf-8"))

    comuns_cod = bruto.get("colunas_codigo_comuns", [])
    comuns_dt = bruto.get("colunas_data_comuns", [])

    doencas: dict[str, Doenca] = {}
    for slug, d in bruto["doencas"].items():
        definicoes = d.get("definicoes") or {}
        if "confirmado" not in definicoes:
            raise ValueError(f"{slug}: falta a definição 'confirmado'")
        padrao = d.get("padrao", "confirmado")
        if padrao not in definicoes:
            raise ValueError(f"{slug}: padrao {padrao!r} não está em definicoes")
        doencas[slug] = Doenca(
            slug=slug,
            codigo=d["codigo"].upper(),
            nome=d["nome"],
            tabela_legada=d.get("tabela_legada"),
            colunas_codigo=_unicos(comuns_cod, d.get("colunas_codigo_extras")),
            colunas_data=_unicos(comuns_dt, d.get("colunas_data_extras")),
            definicoes=dict(definicoes),
            padrao=padrao,
            filtro=d.get("filtro"),
            notas=(d.get("notas") or "").strip() or None,
            texto_app=(d.get("texto_app") or "").strip() or None,
        )
    return Config(
        ano_inicio=int(bruto.get("ano_inicio", 2007)),
        doencas=doencas,
        populacao_url=(bruto.get("populacao") or {}).get("url", ""),
    )
