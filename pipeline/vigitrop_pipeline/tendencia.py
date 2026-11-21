"""Tendência da incidência Brasil: regressão segmentada log-linear, no estilo do Joinpoint (NCI).

Modelo, por doença (t = ano):

    ln(taxa_t) = b0 + b1·t + Σ dk·(t − τk)+        taxa = casos / população × 100 mil

- Joinpoints τk em anos observados, com pelo menos 2 observações antes do
  primeiro, depois do último e entre dois joinpoints (o padrão do Joinpoint).
- Para cada número de joinpoints k (0 até o máximo recomendado pelo Joinpoint
  para n anos, limitado a 3), a posição é achada por busca exaustiva (mínimos
  quadrados ordinários, variância constante). O k vem do menor BIC, na forma do
  Joinpoint: ln(SQR/n) + (2k + 2)·ln(n)/n (conta também as posições dos joinpoints).
  O TCC usou o teste de permutação do Joinpoint; aqui é BIC.
- APC do segmento = 100·(exp(inclinação) − 1). IC95% pela t de Student com
  gl = n − 2k − 2, com o erro-padrão da inclinação do segmento. É condicional às
  posições dos joinpoints (não inclui a incerteza delas), como o método
  paramétrico do Joinpoint; o TCC usou o método empírico (bootstrap), que dá
  intervalos assimétricos e mais largos.
- AAPC = 100·(exp(média das inclinações, ponderada pelos anos de cada segmento) − 1).
  O erro-padrão da média vem da matriz de covariância dos coeficientes (é uma
  combinação linear deles); o IC usa a normal na escala log e depois volta para %,
  como o Joinpoint. Se o período cabe num segmento só, AAPC = APC (IC pela t).
- Significativo = o IC95% não contém 0.
- Ano com zero casos: o log não existe. Soma-se meio caso (0,5) só nesse ano, e
  o ano fica no `aviso`. Excluir o ano puxaria a tendência para cima, porque só
  sairiam os valores mais baixos.

Duas execuções:
- app: definição padrão de cada doença, do ano_inicio do config ao último ano
  FINAL da doença (sem anos PRELIM). Saída: data/gold/tendencia.parquet.
- TCC: regra do TCC (`legado_tcc` ou a padrão, como no `validar`), nos períodos
  do TCC (config/tcc_joinpoint.csv), comparada com o Joinpoint do TCC.
  Saída: data/relatorios/tendencia_tcc.csv.

data/gold/tendencia.parquet (formato longo, uma linha por segmento + uma de AAPC):
  doenca, definicao     doença (slug) e definição de caso usada
  tipo                  'APC' (segmento) ou 'AAPC' (período inteiro)
  segmento              1, 2, ... (NULL na linha de AAPC)
  ano_inicio, ano_fim   limites do segmento ou do período (o joinpoint é fim de um e início do outro)
  apc, apc_ic_inf, apc_ic_sup   % ao ano e IC95% (na linha AAPC: a AAPC)
  significativo         IC95% não contém 0
  taxa_inicio, taxa_fim incidência ajustada pelo modelo (por 100 mil) nos dois anos-limite
  joinpoints, n_anos    joinpoints do modelo escolhido e anos usados no ajuste
  aviso                 anos com zero casos (corrigidos) ou falta de anos; NULL se nada
"""

from __future__ import annotations

import csv
import logging
import math
from dataclasses import dataclass
from functools import cached_property
from itertools import combinations
from pathlib import Path
from statistics import NormalDist

import duckdb
import numpy as np

from .ambiente import Pastas
from .config import CONFIG_PADRAO, Config, Doenca
from .normalizacao import literal
from .validacao import definicao_tcc

log = logging.getLogger("vigitrop.tendencia")

TABELA_JOINPOINT_TCC = CONFIG_PADRAO.parent / "tcc_joinpoint.csv"
MAX_JOINPOINTS = 3
PARAMETROS_POR_JOINPOINT = 2  # penalidade do BIC: (2k + 2) parâmetros, como no Joinpoint
MIN_OBS_PONTA = 2  # observações antes do 1º joinpoint e depois do último (fora o joinpoint)
MIN_OBS_ENTRE = 2  # observações entre dois joinpoints (fora os joinpoints)
MEIO_CASO = 0.5  # somado aos anos com zero casos
Z_975 = NormalDist().inv_cdf(0.975)


# ---------------------------------------------------------------------------
# Quantil da t de Student (sem scipy): beta incompleta + bisseção.

def _beta_fc(a: float, b: float, x: float) -> float:
    """Fração contínua da beta incompleta (algoritmo de Lentz, Numerical Recipes 6.4)."""
    minimo = 1e-300
    d = 1 - (a + b) * x / (a + 1)
    d = 1 / (d if abs(d) > minimo else minimo)
    c, h = 1.0, d
    for m in range(1, 500):
        for aa in (m * (b - m) * x / ((a + 2 * m - 1) * (a + 2 * m)),
                   -(a + m) * (a + b + m) * x / ((a + 2 * m) * (a + 2 * m + 1))):
            d = 1 + aa * d
            d = 1 / (d if abs(d) > minimo else minimo)
            c = 1 + aa / c
            c = c if abs(c) > minimo else minimo
            h *= d * c
        if abs(d * c - 1) < 1e-15:
            break
    return h


def _beta_regularizada(a: float, b: float, x: float) -> float:
    """I_x(a, b)."""
    if x <= 0:
        return 0.0
    if x >= 1:
        return 1.0
    frente = math.exp(math.lgamma(a + b) - math.lgamma(a) - math.lgamma(b) + a * math.log(x) + b * math.log1p(-x))
    if x < (a + 1) / (a + b + 2):
        return frente * _beta_fc(a, b, x) / a
    return 1 - frente * _beta_fc(b, a, 1 - x) / b


def quantil_t(p: float, gl: int) -> float:
    """Quantil p (0,5 < p < 1) da t de Student com `gl` graus de liberdade."""
    if not 0.5 < p < 1 or gl < 1:
        raise ValueError(f"quantil_t: p={p}, gl={gl}")
    cauda = 1 - p  # P(T > t) = I_{gl/(gl+t²)}(gl/2, 1/2) / 2

    def acima(t: float) -> float:
        return _beta_regularizada(gl / 2, 0.5, gl / (gl + t * t)) / 2

    lo, hi = 0.0, 1.0
    while acima(hi) > cauda:
        lo, hi = hi, hi * 2
    for _ in range(200):
        meio = (lo + hi) / 2
        if acima(meio) > cauda:
            lo = meio
        else:
            hi = meio
        if hi - lo < 1e-12:
            break
    return (lo + hi) / 2


# ---------------------------------------------------------------------------
# Ajuste

@dataclass(frozen=True)
class Tendencia:
    """APC de um segmento ou AAPC de um período, em % ao ano, com IC95%."""
    ano_inicio: int
    ano_fim: int
    apc: float
    ic_inf: float
    ic_sup: float
    taxa_inicio: float  # incidência ajustada no ano_inicio
    taxa_fim: float  # incidência ajustada no ano_fim

    @property
    def significativo(self) -> bool:
        return self.ic_inf > 0 or self.ic_sup < 0

    def texto(self, periodo: bool = True) -> str:
        return _texto(self.ano_inicio, self.ano_fim, self.apc, self.ic_inf, self.ic_sup, self.significativo, periodo)


def _texto(ini: int, fim: int, apc: float, inf: float, sup: float, sig: bool, periodo: bool = True) -> str:
    """'2007-2013 +30.6* [17.8; 74.2]'"""
    return f"{f'{ini}-{fim} ' if periodo else ''}{apc:+.1f}{'*' if sig else ''} [{inf:.1f}; {sup:.1f}]"


def _pct(b: float) -> float:
    return 100 * math.expm1(b)


def max_joinpoints(n: int, teto: int = MAX_JOINPOINTS) -> int:
    """Máximo recomendado pelo Joinpoint para n observações (7-11: 1; 12-16: 2; 17-21: 3...), limitado a `teto`."""
    return min(teto, 0 if n < 7 else min(5, (n - 7) // 5 + 1))


def candidatos(n: int, k: int, min_ponta: int = MIN_OBS_PONTA, min_entre: int = MIN_OBS_ENTRE):
    """Índices (das observações) possíveis para k joinpoints, respeitando os mínimos de observações."""
    for idx in combinations(range(min_ponta, n - min_ponta), k):
        if all(b - a > min_entre for a, b in zip(idx, idx[1:])):
            yield idx


def _matriz(x: np.ndarray, joinpoints: tuple[float, ...]) -> np.ndarray:
    return np.column_stack([np.ones_like(x), x, *(np.maximum(x - tau, 0.0) for tau in joinpoints)])


@dataclass(frozen=True, eq=False)
class Ajuste:
    anos: tuple[int, ...]
    taxas: tuple[float, ...]
    joinpoints: tuple[int, ...]
    coef: np.ndarray  # b0, b1, d1..dk (t medido a partir do primeiro ano)
    cov: np.ndarray
    sse: float
    gl: int
    bic: float

    @property
    def limites(self) -> list[int]:
        return [self.anos[0], *self.joinpoints, self.anos[-1]]

    def ajustada(self, ano: float) -> float:
        x = np.array([float(ano - self.anos[0])])
        jps = tuple(float(j - self.anos[0]) for j in self.joinpoints)
        return float(np.exp(_matriz(x, jps)[0] @ self.coef))

    def _vetor(self, j: int) -> np.ndarray:
        """Combinação dos coeficientes que dá a inclinação do segmento j (0 = primeiro)."""
        c = np.zeros(len(self.coef))
        c[1] = 1
        c[2:2 + j] = 1
        return c

    def _tendencia(self, ini: int, fim: int, c: np.ndarray, quantil: float) -> Tendencia:
        b = float(c @ self.coef)
        ep = math.sqrt(max(float(c @ self.cov @ c), 0.0))
        return Tendencia(ini, fim, _pct(b), _pct(b - quantil * ep), _pct(b + quantil * ep),
                         self.ajustada(ini), self.ajustada(fim))

    @cached_property
    def _t975(self) -> float:
        return quantil_t(0.975, self.gl)

    @property
    def segmentos(self) -> list[Tendencia]:
        lim = self.limites
        return [self._tendencia(lim[j], lim[j + 1], self._vetor(j), self._t975) for j in range(len(lim) - 1)]

    def media(self, ini: int, fim: int) -> Tendencia:
        """AAPC entre ini e fim: média das inclinações ponderada pelos anos de cada segmento no intervalo."""
        if not self.anos[0] <= ini < fim <= self.anos[-1]:
            raise ValueError(f"intervalo {ini}-{fim} fora de {self.anos[0]}-{self.anos[-1]}")
        lim = self.limites
        pesos = [max(0, min(lim[j + 1], fim) - max(lim[j], ini)) for j in range(len(lim) - 1)]
        c = sum(p * self._vetor(j) for j, p in enumerate(pesos)) / sum(pesos)
        um_segmento = sum(p > 0 for p in pesos) == 1
        return self._tendencia(ini, fim, c, self._t975 if um_segmento else Z_975)

    @property
    def aapc(self) -> Tendencia:
        return self.media(self.anos[0], self.anos[-1])


def _mqo(x: np.ndarray, y: np.ndarray, joinpoints: tuple[float, ...]) -> tuple[np.ndarray, float, np.ndarray]:
    X = _matriz(x, joinpoints)
    coef, *_ = np.linalg.lstsq(X, y, rcond=None)
    resid = y - X @ coef
    return coef, float(resid @ resid), X


def ajustar(anos: list[int], taxas: list[float], k_max: int | None = None,
            por_joinpoint: int = PARAMETROS_POR_JOINPOINT) -> Ajuste:
    """Escolhe o número e a posição dos joinpoints (BIC) e ajusta o modelo log-linear.

    BIC = ln(SQR/n) + (por_joinpoint·k + 2)·ln(n)/n. `por_joinpoint` = 2 é o BIC
    do Joinpoint; 3 é o BIC3 (mais conservador).
    """
    if len(anos) != len(taxas) or len(anos) < 3:
        raise ValueError("são precisos ao menos 3 anos com taxa")
    if any(b <= a for a, b in zip(anos, anos[1:])):
        raise ValueError("anos fora de ordem ou repetidos")
    if any(not t > 0 for t in taxas):
        raise ValueError("taxa zero ou negativa: corrija antes (ver MEIO_CASO)")
    n = len(anos)
    x = np.array(anos, dtype=float) - anos[0]
    y = np.log(np.array(taxas, dtype=float))
    k_max = max_joinpoints(n) if k_max is None else k_max

    melhor: Ajuste | None = None
    for k in range(k_max + 1):
        gl = n - 2 * k - 2
        if gl < 1:
            break
        achado: tuple[float, tuple[int, ...], np.ndarray, np.ndarray] | None = None
        for idx in candidatos(n, k):
            jps = tuple(x[i] for i in idx)
            coef, sse, X = _mqo(x, y, jps)
            if achado is None or sse < achado[0]:
                achado = (sse, idx, coef, X)
        if achado is None:
            break  # poucos anos para k joinpoints com os mínimos exigidos
        sse, idx, coef, X = achado
        bic = math.log(max(sse / n, 1e-12)) + (por_joinpoint * k + 2) * math.log(n) / n
        if melhor is None or bic < melhor.bic:
            cov = sse / gl * np.linalg.inv(X.T @ X)
            melhor = Ajuste(tuple(anos), tuple(taxas), tuple(anos[i] for i in idx), coef, cov, sse, gl, bic)
    assert melhor is not None
    return melhor


# ---------------------------------------------------------------------------
# Dados

@dataclass(frozen=True)
class Serie:
    anos: list[int]
    taxas: list[float]
    avisos: list[str]


def serie_taxas(anos: list[int], casos: dict[int, int], populacao: dict[int, float]) -> Serie:
    """Incidência por 100 mil em cada ano; ano com zero casos recebe MEIO_CASO (e vira aviso)."""
    taxas, zerados = [], []
    for ano in anos:
        n = casos.get(ano, 0)
        if n == 0:
            zerados.append(ano)
        taxas.append((n or MEIO_CASO) * 1e5 / populacao[ano])
    avisos = [f"zero casos em {', '.join(map(str, zerados))}: somado meio caso"] if zerados else []
    return Serie(list(anos), taxas, avisos)


def _faixas(anos: list[int]) -> str:
    partes, ini = [], None
    for i, a in enumerate(anos):
        ini = a if ini is None else ini
        if i + 1 == len(anos) or anos[i + 1] != a + 1:
            partes.append(f"{ini}" if ini == a else f"{ini}-{a}")
            ini = None
    return ", ".join(partes)


@dataclass
class _Gold:
    populacao: dict[int, float]
    casos: dict[tuple[str, str, int], int]
    arquivos: dict[str, dict[int, str]]  # doenca -> ano -> status

    @classmethod
    def ler(cls, g: Path) -> _Gold:
        for nome in ("casos", "populacao", "arquivos"):
            if not (g / f"{nome}.parquet").exists():
                raise SystemExit(f"Falta data/gold/{nome}.parquet. Rode `gold` antes.")
        con = duckdb.connect()
        pop = dict(con.execute(f"SELECT ano, sum(populacao) FROM read_parquet({literal(str(g / 'populacao.parquet'))}) GROUP BY 1").fetchall())
        casos = {
            (doenca, definicao, ano): int(n)
            for doenca, definicao, ano, n in con.execute(
                f"SELECT doenca, definicao, ano, sum(casos) FROM read_parquet({literal(str(g / 'casos.parquet'))}) GROUP BY ALL"
            ).fetchall()
        }
        arquivos: dict[str, dict[int, str]] = {}
        for doenca, ano, status in con.execute(
            f"SELECT doenca, ano, status FROM read_parquet({literal(str(g / 'arquivos.parquet'))})"
        ).fetchall():
            arquivos.setdefault(doenca, {})[int(ano)] = status
        con.close()
        return cls(pop, casos, arquivos)

    def serie(self, d: Doenca, definicao: str, anos: list[int]) -> Serie:
        casos = {a: self.casos.get((d.slug, definicao, a), 0) for a in anos}
        return serie_taxas(anos, casos, self.populacao)


# ---------------------------------------------------------------------------
# Execução do app -> data/gold/tendencia.parquet

COLUNAS_GOLD = (
    "doenca VARCHAR, definicao VARCHAR, tipo VARCHAR, segmento SMALLINT, ano_inicio SMALLINT, ano_fim SMALLINT, "
    "apc DOUBLE, apc_ic_inf DOUBLE, apc_ic_sup DOUBLE, significativo BOOLEAN, taxa_inicio DOUBLE, taxa_fim DOUBLE, "
    "joinpoints SMALLINT, n_anos SMALLINT, aviso VARCHAR"
)


def _linhas_gold(d: Doenca, definicao: str, aj: Ajuste, aviso: str | None) -> list[tuple]:
    def linha(tipo: str, seg: int | None, t: Tendencia) -> tuple:
        return (d.slug, definicao, tipo, seg, t.ano_inicio, t.ano_fim, t.apc, t.ic_inf, t.ic_sup,
                t.significativo, t.taxa_inicio, t.taxa_fim, len(aj.joinpoints), len(aj.anos), aviso)

    return [linha("APC", i, t) for i, t in enumerate(aj.segmentos, 1)] + [linha("AAPC", None, aj.aapc)]


def _execucao_app(dados: _Gold, cfg: Config, destino: Path) -> None:
    log.info("Tendência para o app (definição padrão, anos FINAL, a partir de %d):", cfg.ano_inicio)
    linhas: list[tuple] = []
    for d in cfg.doencas.values():
        status = dados.arquivos.get(d.slug, {})
        finais = sorted(a for a, s in status.items() if s == "FINAL" and a >= cfg.ano_inicio)
        if len(finais) < 3:
            log.warning("  %-4s menos de 3 anos FINAL no gold: sem tendência", d.codigo)
            continue
        avisos = []
        buracos = sorted(set(range(finais[0], finais[-1] + 1)) - set(finais))
        if buracos:
            avisos.append(f"sem arquivo FINAL em {_faixas(buracos)}")
        s = dados.serie(d, d.padrao, finais)
        avisos += s.avisos
        aviso = "; ".join(avisos) or None
        aj = ajustar(s.anos, s.taxas)
        linhas += _linhas_gold(d, d.padrao, aj, aviso)
        log.info("  %-4s %-26s %s | %d joinpoint(s): %s | AAPC %s", d.codigo, d.padrao, _faixas(finais),
                 len(aj.joinpoints), " | ".join(t.texto() for t in aj.segmentos), aj.aapc.texto(periodo=False))
        if aviso:
            log.warning("  %-4s %s", d.codigo, aviso)

    con = duckdb.connect()
    con.execute(f"CREATE TABLE t ({COLUNAS_GOLD})")
    con.executemany(f"INSERT INTO t VALUES ({', '.join('?' * 15)})", linhas)
    tmp = destino.with_suffix(".tmp.parquet")
    con.execute(f"COPY (SELECT * FROM t ORDER BY doenca, tipo DESC, segmento) TO {literal(str(tmp))} (FORMAT parquet, COMPRESSION zstd)")
    con.close()
    tmp.replace(destino)
    log.info("Gravado: %s (%d linhas)", destino, len(linhas))


# ---------------------------------------------------------------------------
# Execução do TCC -> data/relatorios/tendencia_tcc.csv

def ler_tcc(caminho: Path = TABELA_JOINPOINT_TCC) -> dict[str, list[dict[str, str]]]:
    linhas = csv.DictReader(l for l in caminho.open(encoding="utf-8") if not l.startswith("#"))
    por_codigo: dict[str, list[dict[str, str]]] = {}
    for r in linhas:
        por_codigo.setdefault(r["codigo"], []).append(r)
    return por_codigo


def _execucao_tcc(dados: _Gold, cfg: Config, destino: Path) -> None:
    por_codigo = {d.codigo: d for d in cfg.doencas.values()}
    saida: list[dict[str, object]] = []
    log.info("Tendência com a regra e os períodos do TCC, comparada com o Joinpoint do TCC "
             "(APC %/ano [IC95%]; * = significativo; VigiTrop no mesmo período = AAPC do nosso modelo naquele trecho):")
    for cod, refs in ler_tcc().items():
        d = por_codigo[cod]
        definicao = definicao_tcc(d)
        ini, fim = min(int(r["ano_inicio"]) for r in refs), max(int(r["ano_fim"]) for r in refs)
        com_arquivo = sorted(a for a in dados.arquivos.get(d.slug, {}) if ini <= a <= fim)
        avisos = []
        sem = sorted(set(range(ini, fim + 1)) - set(com_arquivo))
        if sem:
            avisos.append(f"sem arquivo em {_faixas(sem)}")
        s = dados.serie(d, definicao, com_arquivo)
        avisos += s.avisos
        aj = ajustar(s.anos, s.taxas)
        segs_tcc = [r for r in refs if r["tipo"] == "APC"]
        nossos = " | ".join(t.texto() for t in aj.segmentos)

        log.info("  %s (%s, %d-%d): %d joinpoint(s) %s; TCC %d %s", cod, definicao, ini, fim,
                 len(aj.joinpoints), list(aj.joinpoints), len(segs_tcc) - 1,
                 [int(r["ano_inicio"]) for r in segs_tcc[1:]])
        for r in refs:
            a, b = int(r["ano_inicio"]), int(r["ano_fim"])
            nosso = aj.media(a, b)
            apc_tcc, inf_tcc, sup_tcc = float(r["apc"]), float(r["ic_inf"]), float(r["ic_sup"])
            sig_tcc = r["significativo"].strip().lower() == "true"
            rotulo = "AAPC" if r["tipo"] == "AAPC" else f"seg {r['segmento']}"
            log.info("    %-6s TCC %-34s VigiTrop %s", rotulo, _texto(a, b, apc_tcc, inf_tcc, sup_tcc, sig_tcc),
                     nosso.texto(periodo=False))
            saida.append({
                "codigo": cod, "definicao": definicao, "tipo": r["tipo"], "segmento": r["segmento"],
                "ano_inicio": a, "ano_fim": b,
                "tcc_apc": apc_tcc, "tcc_ic_inf": inf_tcc, "tcc_ic_sup": sup_tcc, "tcc_significativo": sig_tcc,
                "apc": round(nosso.apc, 2), "ic_inf": round(nosso.ic_inf, 2), "ic_sup": round(nosso.ic_sup, 2),
                "significativo": nosso.significativo,
                "mesmo_sentido": (apc_tcc > 0) == (nosso.apc > 0),
                "mesma_significancia": sig_tcc == nosso.significativo,
                "tcc_joinpoints": len(segs_tcc) - 1, "joinpoints": len(aj.joinpoints),
                "segmentos_vigitrop": nossos, "aviso": "; ".join(avisos),
            })
        log.info("    VigiTrop: %s", nossos)
        if avisos:
            log.warning("    %s: %s", cod, "; ".join(avisos))

    with destino.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(saida[0]))
        w.writeheader()
        w.writerows(saida)
    aapc = [r for r in saida if r["tipo"] == "AAPC"]
    log.info("AAPC: mesmo sentido em %d de %d doenças, mesma significância em %d de %d. Detalhes: %s",
             sum(r["mesmo_sentido"] for r in aapc), len(aapc), sum(r["mesma_significancia"] for r in aapc), len(aapc), destino)


def gerar(pastas: Pastas, cfg: Config) -> None:
    g = pastas.raiz / "gold"
    dados = _Gold.ler(g)
    _execucao_app(dados, cfg, g / "tendencia.parquet")
    _execucao_tcc(dados, cfg, pastas.relatorios / "tendencia_tcc.csv")
