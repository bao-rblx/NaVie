"""Convert edge records (from OSM or fixtures) into a CSR ``Graph``.

Kept free of osmnx so it can be unit-tested; ``scripts/build_graph.py`` does the
download and turns osmnx edges into ``EdgeRecord`` rows.
"""

from __future__ import annotations

import re
from collections.abc import Iterable, Sequence
from dataclasses import dataclass

import numpy as np

from navie.geo import haversine_m
from navie.graph.core import (
    FLAG_BRIDGE,
    FLAG_FOOTWAY,
    FLAG_MOTORCYCLE_NO,
    FLAG_MOTORWAY,
    FLAG_TOLL,
    ONEWAY_AGAINST,
    ONEWAY_FORWARD,
    ONEWAY_NONE,
    ROAD_CLASSES,
    Graph,
)

_FOOT_CLASSES = {"footway", "path", "pedestrian", "steps", "cycleway"}
_CLASS_ALIASES = {
    "motorway_link": "motorway",
    "trunk_link": "trunk",
    "primary_link": "primary",
    "secondary_link": "secondary",
    "tertiary_link": "tertiary",
    "road": "unclassified",
    "corridor": "footway",
    "bridleway": "path",
}
_NUM = re.compile(r"\d+(?:[.,]\d+)?")


@dataclass
class EdgeRecord:
    """One OSM road segment u -> v as stored by osmnx (raw tag values)."""

    u: int
    v: int
    length_m: float
    highway: str | list[str] | None = None
    oneway: bool = False
    maxspeed: str | list[str] | None = None
    name: str | list[str] | None = None
    motorcycle: str | None = None
    toll: str | None = None
    bridge: str | None = None
    maxweight: str | None = None
    maxheight: str | None = None


def _first(value: str | list[str] | None) -> str | None:
    if isinstance(value, list):
        return str(value[0]) if value else None
    return None if value is None else str(value)


def road_class_code(highway: str | list[str] | None) -> int:
    """Map an OSM ``highway`` tag to a ROAD_CLASSES index (0 = other)."""
    h = _first(highway)
    if h is None:
        return 0
    h = _CLASS_ALIASES.get(h, h)
    return ROAD_CLASSES.index(h) if h in ROAD_CLASSES else 0


def parse_number(value: str | list[str] | None, mph: bool = True) -> float:
    """First number in an OSM value; converts ``mph`` to km/h. 0.0 if none."""
    s = _first(value)
    if not s:
        return 0.0
    m = _NUM.search(s)
    if not m:
        return 0.0
    x = float(m.group(0).replace(",", "."))
    if mph and "mph" in s:
        x *= 1.609344
    return x


def _yes(value: str | None) -> bool:
    return _first(value) in {"yes", "true", "1", "viaduct"}


def build_graph(
    node_ids: Sequence[int],
    node_lat: Sequence[float],
    node_lon: Sequence[float],
    edges: Iterable[EdgeRecord],
    version: str = "unversioned",
) -> Graph:
    """Build a CSR graph. Adds a walk-only reverse edge for each one-way segment.

    ``length_m`` is clamped to at least the straight-line distance between its
    end nodes so the haversine heuristic stays admissible.
    """
    index = {int(n): i for i, n in enumerate(node_ids)}
    lat = np.asarray(node_lat, dtype=np.float64)
    lon = np.asarray(node_lon, dtype=np.float64)
    names: list[str] = []
    name_index: dict[str, int] = {}
    rows: list[tuple[int, int, float, int, float, int, int, float, float, int]] = []
    forward_pairs: set[tuple[int, int]] = set()
    records = list(edges)

    for r in records:
        forward_pairs.add((index[r.u], index[r.v]))

    for r in records:
        u, v = index[r.u], index[r.v]
        rc = road_class_code(r.highway)
        cls = ROAD_CLASSES[rc]
        flags = 0
        if cls == "motorway":
            flags |= FLAG_MOTORWAY
        if cls in _FOOT_CLASSES:
            flags |= FLAG_FOOTWAY
        if _first(r.motorcycle) == "no":
            flags |= FLAG_MOTORCYCLE_NO
        if _yes(r.toll):
            flags |= FLAG_TOLL
        if _yes(r.bridge):
            flags |= FLAG_BRIDGE
        nm = _first(r.name)
        nid = -1
        if nm:
            nid = name_index.setdefault(nm, len(names))
            if nid == len(names):
                names.append(nm)
        length = max(float(r.length_m), haversine_m(lat[u], lon[u], lat[v], lon[v]))
        common = (
            length,
            rc,
            parse_number(r.maxspeed),
            flags,
            parse_number(r.maxweight, mph=False),
            parse_number(r.maxheight, mph=False),
            nid,
        )
        ow = ONEWAY_FORWARD if r.oneway else ONEWAY_NONE
        rows.append((u, v, common[0], common[1], common[2], ow, *common[3:]))
        if r.oneway and (v, u) not in forward_pairs:
            rows.append((v, u, common[0], common[1], common[2], ONEWAY_AGAINST, *common[3:]))

    rows.sort(key=lambda t: (t[0], t[1]))
    n = len(node_ids)
    src = np.fromiter((t[0] for t in rows), dtype=np.int64, count=len(rows))
    counts = np.bincount(src, minlength=n) if rows else np.zeros(n, dtype=np.int64)
    indptr = np.zeros(n + 1, dtype=np.int32)
    np.cumsum(counts, out=indptr[1:])

    def col(i: int, dtype: type) -> np.ndarray:
        return np.array([t[i] for t in rows], dtype=dtype)

    graph = Graph(
        node_lat=lat,
        node_lon=lon,
        indptr=indptr,
        indices=col(1, np.int32),
        length_m=col(2, np.float64),
        road_class=col(3, np.uint8),
        maxspeed_kmh=col(4, np.float32),
        oneway=col(5, np.uint8),
        flags=col(6, np.uint8),
        maxweight_t=col(7, np.float32),
        maxheight_m=col(8, np.float32),
        name_id=col(9, np.int32),
        names=names,
        version=version,
    )
    graph.validate()
    graph.build_reverse()
    return graph
