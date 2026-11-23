"""Gera shiny/mapas/municipios/<UF>.geojson (malha dos municípios de cada UF, simplificada).

Roda UMA vez (os GeoJSON ficam versionados), como gerar_mapa_uf.py. Não faz
parte da imagem do pipeline. Refazer quando o IBGE publicar município novo.

Fonte: IBGE, Malha Territorial 2025, <UF>_Municipios_2025 (SIRGAS 2000)
  https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2025/UFs/<UF>/<UF>_Municipios_2025.zip

Mesma receita do mapa das UFs: simplificação topológica (cada divisa entre
municípios é simplificada uma vez só, sem buracos nem sobreposição), ilhotas
pequenas fora e make_valid. Cada UF é simplificada à parte, porque o app
mostra uma UF por vez.

Propriedades de cada município:
  municipio  código IBGE com 6 dígitos, como no SINAN (ID_MN_RESI)
  nome       nome do município

Uso:
  python -m venv .venv-geo
  .venv-geo/bin/pip install pyshp==2.3.1 shapely==2.0.6 topojson==1.9 numpy==2.2.6
  .venv-geo/bin/python pipeline/scripts/gerar_mapas_municipios.py <pasta para os .zip> shiny/mapas/municipios
"""

from __future__ import annotations

import io
import json
import sys
import time
import urllib.request
import zipfile
from pathlib import Path

import shapefile  # pyshp
import topojson
from shapely import make_valid
from shapely.geometry import MultiPolygon, Polygon, mapping, shape

ANO = 2025
URL = ("https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/"
       "municipio_{ano}/UFs/{uf}/{uf}_Municipios_{ano}.zip")
UFS = ["RO", "AC", "AM", "RR", "PA", "AP", "TO", "MA", "PI", "CE", "RN", "PB", "PE", "AL", "SE", "BA",
       "MG", "ES", "RJ", "SP", "PR", "SC", "RS", "MS", "MT", "GO", "DF"]
TOLERANCIA = 0.004  # graus (~400 m): o mapa mostra uma UF inteira, sem zoom de rua
CASAS = 4  # casas decimais nas coordenadas (~11 m)
AREA_MIN = 0.00005  # graus² (~0,6 km²): ilhotas menores somem (o município nunca some inteiro)
# A malha do RS traz as lagoas Mirim e dos Patos como "municípios": não são.
NAO_MUNICIPIOS = {"4300001", "4300002"}


def _arredondar(coords):
    if isinstance(coords[0], (int, float)):
        return [round(coords[0], CASAS), round(coords[1], CASAS)]
    return [_arredondar(c) for c in coords]


def _poligonal(g):
    """Só as partes poligonais (make_valid pode devolver GeometryCollection)."""
    if isinstance(g, (Polygon, MultiPolygon)):
        return g
    partes = [p for p in getattr(g, "geoms", []) if isinstance(p, (Polygon, MultiPolygon))]
    polis = [q for p in partes for q in (p.geoms if isinstance(p, MultiPolygon) else [p])]
    return MultiPolygon(polis)


def _sem_ilhotas(g):
    g = _poligonal(g)
    if isinstance(g, Polygon):
        return g
    partes = [p for p in g.geoms if p.area >= AREA_MIN] or [max(g.geoms, key=lambda p: p.area)]
    return partes[0] if len(partes) == 1 else MultiPolygon(partes)


def _baixar(uf: str, pasta: Path) -> Path:
    destino = pasta / f"{uf}_Municipios_{ANO}.zip"
    if destino.exists():
        return destino
    for tentativa in range(1, 5):
        try:
            with urllib.request.urlopen(URL.format(ano=ANO, uf=uf), timeout=300) as resp:
                destino.write_bytes(resp.read())
            return destino
        except OSError as e:
            if tentativa == 4:
                raise
            print(f"{uf}: {e}; tentando de novo", file=sys.stderr)
            time.sleep(5 * tentativa)
    return destino


def _ler(zip_path: Path) -> list[dict]:
    with zipfile.ZipFile(zip_path) as z:
        nomes = {Path(n).suffix.lower(): n for n in z.namelist()}
        partes = {ext: io.BytesIO(z.read(nomes[ext])) for ext in (".shp", ".shx", ".dbf")}
        encoding = z.read(nomes[".cpg"]).decode().strip() if ".cpg" in nomes else "utf-8"
    r = shapefile.Reader(shp=partes[".shp"], shx=partes[".shx"], dbf=partes[".dbf"], encoding=encoding)
    feicoes = []
    for sr in r.shapeRecords():
        rec = sr.record.as_dict()
        if str(rec["CD_MUN"]) in NAO_MUNICIPIOS:
            continue
        feicoes.append({
            "type": "Feature",
            "properties": {"municipio": str(rec["CD_MUN"])[:6], "nome": rec["NM_MUN"]},
            "geometry": mapping(_sem_ilhotas(make_valid(shape(sr.shape.__geo_interface__)))),
        })
    return feicoes


def gerar_uf(uf: str, pasta_zip: Path, destino: Path) -> int:
    feicoes = _ler(_baixar(uf, pasta_zip))
    topo = topojson.Topology({"type": "FeatureCollection", "features": feicoes}, prequantize=False, toposimplify=TOLERANCIA)
    gj = json.loads(topo.to_geojson())
    for f in gj["features"]:
        f.pop("id", None)
        geom = _poligonal(make_valid(shape({**f["geometry"], "coordinates": _arredondar(f["geometry"]["coordinates"])})))
        if not geom.is_valid or geom.is_empty:
            raise SystemExit(f"{uf}: geometria inválida depois de simplificar: {f['properties']}")
        f["geometry"] = mapping(geom)
    gj["features"].sort(key=lambda f: f["properties"]["municipio"])
    gj["fonte"] = f"IBGE, Malha Territorial {ANO} ({uf}_Municipios_{ANO}), simplificada (toposimplify {TOLERANCIA} graus)"
    arquivo = destino / f"{uf}.geojson"
    arquivo.write_text(json.dumps(gj, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    return len(gj["features"])


def main(pasta_zip: Path, destino: Path) -> None:
    pasta_zip.mkdir(parents=True, exist_ok=True)
    destino.mkdir(parents=True, exist_ok=True)
    total = 0
    for uf in UFS:
        n = gerar_uf(uf, pasta_zip, destino)
        total += n
        print(f"{uf}: {n} municípios, {(destino / f'{uf}.geojson').stat().st_size / 1e3:.0f} kB")
    print(f"Total: {total} municípios")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
