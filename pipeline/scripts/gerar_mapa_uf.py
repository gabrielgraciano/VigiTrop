"""Gera shiny/mapas/uf_2022.geojson (malha das UFs, simplificada) a partir do IBGE.

Roda UMA vez (o GeoJSON fica versionado). Não faz parte da imagem do pipeline.

Fonte: IBGE, Malha Territorial 2022, BR_UF_2022 (SIRGAS 2000)
  https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2022/Brasil/BR/BR_UF_2022.zip

A simplificação é topológica: cada fronteira compartilhada é simplificada uma
vez só, então não sobram buracos nem sobreposição entre UFs. Ilhotas menores
que AREA_MIN saem, e as geometrias passam por make_valid. Substitui o
ms_simplify que o app antigo rodava a cada clique.

Uso:
  python -m venv .venv-geo
  .venv-geo/bin/pip install pyshp==2.3.1 shapely==2.0.6 topojson==1.9 numpy==2.2.6
  .venv-geo/bin/python pipeline/scripts/gerar_mapa_uf.py <pasta com BR_UF_2022.*> shiny/mapas/uf_2022.geojson
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import shapefile  # pyshp
import topojson
from shapely import make_valid
from shapely.geometry import MultiPolygon, Polygon, mapping, shape

TOLERANCIA = 0.02  # graus (~2 km): suficiente para mapa de UF entre os zooms 4 e 10
CASAS = 4  # casas decimais nas coordenadas (~11 m)
AREA_MIN = 0.0002  # graus² (~2,4 km²): ilhotas menores somem do mapa (Fernando de Noronha fica)


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
    if isinstance(g, Polygon):
        return g
    partes = [p for p in g.geoms if p.area >= AREA_MIN]
    return partes[0] if len(partes) == 1 else MultiPolygon(partes)


def main(pasta: Path, destino: Path) -> None:
    base = pasta / "BR_UF_2022"
    cpg = base.with_suffix(".cpg")
    encoding = cpg.read_text().strip() if cpg.exists() else "utf-8"
    r = shapefile.Reader(str(base), encoding=encoding)
    feicoes = []
    for sr in r.shapeRecords():
        rec = sr.record.as_dict()
        feicoes.append({
            "type": "Feature",
            "properties": {"CD_UF": int(rec["CD_UF"]), "SIGLA_UF": rec["SIGLA_UF"], "NM_UF": rec["NM_UF"]},
            "geometry": mapping(_sem_ilhotas(make_valid(shape(sr.shape.__geo_interface__)))),
        })
    if len(feicoes) != 27:
        raise SystemExit(f"esperava 27 UFs, achei {len(feicoes)}")

    topo = topojson.Topology({"type": "FeatureCollection", "features": feicoes}, prequantize=False, toposimplify=TOLERANCIA)
    gj = json.loads(topo.to_geojson())
    for f in gj["features"]:
        f.pop("id", None)
        geom = _poligonal(make_valid(shape({**f["geometry"], "coordinates": _arredondar(f["geometry"]["coordinates"])})))
        if not geom.is_valid or geom.is_empty:
            raise SystemExit(f"geometria inválida depois de simplificar: {f['properties']['SIGLA_UF']}")
        f["geometry"] = mapping(geom)
    gj["features"].sort(key=lambda f: f["properties"]["CD_UF"])
    gj["fonte"] = "IBGE, Malha Territorial 2022 (BR_UF_2022), simplificada (toposimplify %s graus)" % TOLERANCIA

    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(json.dumps(gj, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{destino}: {len(gj['features'])} UFs, {destino.stat().st_size / 1e3:.0f} kB")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
