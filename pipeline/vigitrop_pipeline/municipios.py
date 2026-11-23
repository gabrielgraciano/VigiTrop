"""População e nomes dos municípios (IBGE), para a aba "Municípios" do app.

A projeção do IBGE usada nas outras abas (populacao.py) não desce a município.
Aqui entram as populações municipais publicadas pelo IBGE na API de agregados
(https://servicodados.ibge.gov.br/api/v3/agregados):

  6579  População residente estimada (variável 9324): todo ano, menos 2007, 2010, 2022 e 2023
        (o IBGE não publicou estimativa para 2023)
  793   Contagem da População 2007 (variável 93)
  202   Censo 2010 (variável 93)
  4709  Censo 2022 (variável 93)

As estimativas de 2011 a 2021 partiam do Censo 2010 e erraram a distribuição
entre municípios, o que só apareceu no Censo 2022: trocar de fonte em 2022 faz
São Paulo capital cair 3% de um ano para o outro. Por isso as âncoras são as
contagens (2007, 2010 e 2022) e as estimativas posteriores ao Censo 2022; nos
anos entre duas âncoras, a população de cada município é interpolada em linha
reta. As estimativas antigas só entram para quem não existia na âncora
anterior (os 5 municípios instalados em 2013). Depois da última âncora,
repete-se a última.

As fontes não somam exatamente a projeção por UF usada nas outras abas. Para
que as taxas conversem, cada município fica com a sua fração da UF no ano,
aplicada à projeção:

  população(município, ano) = fonte(município, ano) × projeção(UF, ano) / Σ fonte(municípios da UF, ano)

Assim, somar os municípios dá a população da UF de populacao.parquet.

Saídas:
  data/bronze/ibge/municipios/<agregado>_<ano>.json   respostas da API (baixadas uma vez)
  data/gold/municipios.parquet            municipio (6 dígitos, como no SINAN), codigo_ibge (7), nome, uf
  data/gold/populacao_municipio.parquet   ano, uf, municipio, populacao (DOUBLE, reescalada)
"""

from __future__ import annotations

import json
import logging
import time
from datetime import date
from pathlib import Path

import duckdb

from .ambiente import Pastas
from .normalizacao import literal

log = logging.getLogger("vigitrop.municipios")

API = "https://servicodados.ibge.gov.br/api/v3/agregados"
ESTIMATIVAS = (6579, 9324)
CENSOS = {2007: (793, 93), 2010: (202, 93), 2022: (4709, 93)}


def _get(url: str, timeout: float = 180):
    import httpx

    for tentativa in range(1, 5):
        try:
            resp = httpx.get(url, timeout=timeout, follow_redirects=True)
            resp.raise_for_status()
            return resp.json()
        except (httpx.HTTPError, ValueError) as e:
            if tentativa == 4:
                raise
            log.warning("IBGE: %s; tentativa %d/4 em %d s", e, tentativa + 1, 5 * tentativa)
            time.sleep(5 * tentativa)
    return None


def _pasta(pastas: Pastas) -> Path:
    return pastas.bronze / "ibge" / "municipios"


def anos_estimativa(pastas: Pastas) -> set[int]:
    """Anos publicados na tabela 6579. Sem rede, usa os que já estão baixados."""
    try:
        return {int(p["id"]) for p in _get(f"{API}/{ESTIMATIVAS[0]}/periodos", timeout=60)}
    except Exception as e:  # rede fora: segue com o que já foi baixado
        anos = {int(p.stem.split("_")[1]) for p in _pasta(pastas).glob(f"{ESTIMATIVAS[0]}_*.json")}
        log.warning("Não consegui listar os anos da tabela %d (%s); usando os já baixados: %s",
                    ESTIMATIVAS[0], e, sorted(anos))
        return anos


def fontes_por_ano(anos: range, estimativas: set[int]) -> tuple[dict[int, tuple[int, int]], dict[int, tuple[int, int]]]:
    """(âncoras, reserva): ano -> (agregado, variável). Âncoras: contagens e estimativas
    depois do último censo. Reserva: as demais estimativas, para municípios novos."""
    ultimo_censo = max(CENSOS)
    ancoras = {a: CENSOS[a] for a in anos if a in CENSOS}
    ancoras |= {a: ESTIMATIVAS for a in anos if a > ultimo_censo and a in estimativas}
    reserva = {a: ESTIMATIVAS for a in anos if a not in ancoras and a in estimativas}
    return ancoras, reserva


def baixar_ano(pastas: Pastas, ano: int, agregado: int, variavel: int, forcar: bool = False) -> Path:
    destino = _pasta(pastas) / f"{agregado}_{ano}.json"
    if destino.exists() and not forcar:
        return destino
    destino.parent.mkdir(parents=True, exist_ok=True)
    dados = _get(f"{API}/{agregado}/periodos/{ano}/variaveis/{variavel}?localidades=N6[all]")
    tmp = destino.with_suffix(".tmp")
    tmp.write_text(json.dumps(dados, ensure_ascii=False), encoding="utf-8")
    tmp.replace(destino)
    log.info("IBGE: baixado %s", destino.name)
    return destino


def ler_resposta(arquivo: Path, ano: int) -> dict[str, tuple[str, int]]:
    """código IBGE (7 dígitos) -> (nome sem a UF, população). Valores não numéricos ficam de fora."""
    dados = json.loads(arquivo.read_text(encoding="utf-8"))
    saida = {}
    for serie in dados[0]["resultados"][0]["series"]:
        valor = serie["serie"].get(str(ano), "")
        if valor.isdigit():
            loc = serie["localidade"]
            saida[loc["id"]] = (loc["nome"].rsplit(" - ", 1)[0], int(valor))
    return saida


def completar_anos(ancoras: dict[int, dict[str, float]], anos: range,
                   reserva: dict[int, dict[str, float]] | None = None) -> dict[int, dict[str, float]]:
    """População de todos os `anos`. Entre duas âncoras, interpolação linear município
    a município; quem falta numa das duas (município novo) vem da `reserva` do ano,
    se houver. Antes da primeira âncora, a primeira; depois da última, a última."""
    reserva = reserva or {}
    publicados = sorted(ancoras)
    if not publicados:
        raise ValueError("nenhum ano de população municipal")
    saida = {}
    for a in anos:
        if a in ancoras:
            saida[a] = dict(ancoras[a])
            continue
        antes = [p for p in publicados if p < a]
        depois = [p for p in publicados if p > a]
        if not antes or not depois:
            saida[a] = dict(ancoras[antes[-1] if antes else depois[0]])
            continue
        a0, a1 = antes[-1], depois[0]
        f = (a - a0) / (a1 - a0)
        p0, p1 = ancoras[a0], ancoras[a1]
        saida[a] = {m: p0[m] + f * (p1[m] - p0[m]) for m in p0.keys() & p1.keys()}
        extra = reserva.get(a, {})
        saida[a] |= {m: v for m, v in extra.items() if m not in saida[a] and (m in p0 or m in p1)}
    return saida


def gerar(pastas: Pastas, ano_inicio: int, forcar: bool = False) -> None:
    gold = pastas.raiz / "gold"
    proj = gold / "populacao.parquet"
    if not proj.exists():
        raise SystemExit("Falta data/gold/populacao.parquet (rode `populacao`).")

    anos = range(ano_inicio, date.today().year + 1)
    fontes, fontes_reserva = fontes_por_ano(anos, anos_estimativa(pastas))
    nomes: dict[str, str] = {}

    def ler(lista: dict[int, tuple[int, int]]) -> dict[int, dict[str, float]]:
        out = {}
        for ano in sorted(lista):
            agregado, variavel = lista[ano]
            lidos = ler_resposta(baixar_ano(pastas, ano, agregado, variavel, forcar), ano)
            if len(lidos) < 5500:
                raise ValueError(f"tabela {agregado}, {ano}: só {len(lidos)} municípios")
            out[ano] = {cod: float(pop) for cod, (_, pop) in lidos.items()}
            nomes.update({cod: nome for cod, (nome, _) in lidos.items()})  # o ano mais recente prevalece
        return out

    reserva = ler(fontes_reserva)
    ancoras = ler(fontes)  # por último: os nomes das âncoras recentes prevalecem
    log.info("População municipal: âncoras %s; interpolados os demais anos até %d", sorted(ancoras), anos[-1])
    completos = completar_anos(ancoras, anos, reserva)

    import pyarrow as pa

    linhas = [(a, cod, pop) for a, d in completos.items() for cod, pop in d.items()]
    bruta = pa.table({"ano": pa.array([x[0] for x in linhas], pa.int16()),
                      "codigo_ibge": pa.array([x[1] for x in linhas], pa.string()),
                      "populacao": pa.array([x[2] for x in linhas], pa.float64())})
    tab_nomes = pa.table({"codigo_ibge": pa.array(list(nomes), pa.string()),
                          "nome": pa.array(list(nomes.values()), pa.string())})
    con = duckdb.connect()
    con.register("bruta_arrow", bruta)
    con.register("nomes_arrow", tab_nomes)
    con.execute("CREATE TABLE bruta AS SELECT * FROM bruta_arrow")
    con.execute("CREATE TABLE nomes AS SELECT * FROM nomes_arrow")
    con.execute(f"CREATE VIEW proj AS SELECT ano, uf, sum(populacao) AS pop_uf FROM read_parquet({literal(str(proj))}) GROUP BY ALL")
    con.execute("""
        CREATE TABLE pm AS
        SELECT b.ano, CAST(left(b.codigo_ibge, 2) AS SMALLINT) AS uf, left(b.codigo_ibge, 6) AS municipio,
               b.populacao * p.pop_uf / sum(b.populacao) OVER (PARTITION BY b.ano, left(b.codigo_ibge, 2)) AS populacao,
               p.pop_uf / sum(b.populacao) OVER (PARTITION BY b.ano, left(b.codigo_ibge, 2)) AS fator
        FROM bruta b JOIN proj p ON p.ano = b.ano AND p.uf = CAST(left(b.codigo_ibge, 2) AS SMALLINT)""")

    # Conferências: código de 6 dígitos único; soma por UF = projeção; fator plausível
    dup = con.execute("SELECT count(*) FROM (SELECT ano, municipio FROM pm GROUP BY ALL HAVING count(*) > 1)").fetchone()[0]
    if dup:
        raise ValueError(f"{dup} códigos de 6 dígitos repetidos na população municipal")
    n_bruta, n_pm = con.execute("SELECT (SELECT count(*) FROM bruta), (SELECT count(*) FROM pm)").fetchone()
    if n_bruta != n_pm:
        raise ValueError(f"{n_bruta - n_pm} linhas da população municipal sem projeção da UF no ano")
    fmin, fmax = con.execute("SELECT min(fator), max(fator) FROM pm").fetchone()
    log.info("Reescala para a projeção por UF: fator de %.3f a %.3f", fmin, fmax)
    if not 0.8 < fmin <= fmax < 1.25:
        raise ValueError(f"fator de reescala fora do esperado: {fmin:.3f} a {fmax:.3f}")

    destino = gold / "populacao_municipio.parquet"
    tmp = destino.with_suffix(".tmp.parquet")
    con.execute(f"COPY (SELECT ano, uf, municipio, populacao FROM pm ORDER BY ALL) TO {literal(str(tmp))} (FORMAT parquet, COMPRESSION zstd)")
    tmp.replace(destino)

    destino_nomes = gold / "municipios.parquet"
    tmp = destino_nomes.with_suffix(".tmp.parquet")
    con.execute(f"""COPY (SELECT left(codigo_ibge, 6) AS municipio, codigo_ibge, nome, CAST(left(codigo_ibge, 2) AS SMALLINT) AS uf
                         FROM nomes ORDER BY codigo_ibge) TO {literal(str(tmp))} (FORMAT parquet, COMPRESSION zstd)""")
    tmp.replace(destino_nomes)
    n = con.execute("SELECT count(*) FROM nomes").fetchone()[0]
    con.close()
    log.info("População municipal: %s (%d municípios, %d a %d)", destino, n, anos[0], anos[-1])
