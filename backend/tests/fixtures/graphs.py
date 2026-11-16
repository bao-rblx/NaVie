"""Tiny hand-made graphs for tests (docs/03_algorithms.md §3).

Coordinates are synthetic points near HCMC; lengths are chosen by hand and are
always >= straight-line distance so haversine stays admissible.
"""

from __future__ import annotations

from navie.geo import haversine_m
from navie.graph.build import EdgeRecord, build_graph
from navie.graph.core import Graph

LAT0, LON0 = 10.77, 106.70
STEP = 0.001  # ~111 m


def _grid_coords(rows: int, cols: int) -> tuple[list[int], list[float], list[float]]:
    ids, lat, lon = [], [], []
    for r in range(rows):
        for c in range(cols):
            ids.append(r * cols + c)
            lat.append(LAT0 + r * STEP)
            lon.append(LON0 + c * STEP)
    return ids, lat, lon


def _straight(lat: list[float], lon: list[float], u: int, v: int, scale: float = 1.0) -> float:
    return haversine_m(lat[u], lon[u], lat[v], lon[v]) * scale


def line(n: int = 5) -> Graph:
    """0 - 1 - ... - n-1, two-way residential."""
    ids, lat, lon = _grid_coords(1, n)
    edges = [
        EdgeRecord(i, i + 1, _straight(lat, lon, i, i + 1), highway="residential")
        for i in range(n - 1)
    ]
    edges += [EdgeRecord(e.v, e.u, e.length_m, highway="residential") for e in edges]
    return build_graph(ids, lat, lon, edges, version="fixture-line")


def grid(rows: int = 4, cols: int = 4) -> Graph:
    """4-neighbour grid, two-way, lengths 1.0-1.5x straight-line (deterministic)."""
    ids, lat, lon = _grid_coords(rows, cols)
    edges: list[EdgeRecord] = []
    for r in range(rows):
        for c in range(cols):
            u = r * cols + c
            for dr, dc in ((0, 1), (1, 0)):
                rr, cc = r + dr, c + dc
                if rr < rows and cc < cols:
                    v = rr * cols + cc
                    scale = 1.0 + ((u * 7 + v * 3) % 6) / 10
                    length = _straight(lat, lon, u, v, scale)
                    edges.append(EdgeRecord(u, v, length, highway="residential"))
                    edges.append(EdgeRecord(v, u, length, highway="residential"))
    return build_graph(ids, lat, lon, edges, version="fixture-grid")


def diamond() -> Graph:
    """0 -> {1, 2} -> 3. Path via 2 is shorter even though 1 looks closer to 3."""
    ids = [0, 1, 2, 3]
    lat = [LAT0, LAT0 + STEP, LAT0 - STEP, LAT0]
    lon = [LON0, LON0 + STEP, LON0 + STEP, LON0 + 2 * STEP]
    s = lambda u, v, k=1.0: _straight(lat, lon, u, v, k)  # noqa: E731
    edges = [
        EdgeRecord(0, 1, s(0, 1), highway="residential", oneway=True),
        EdgeRecord(1, 3, s(1, 3, 3.0), highway="residential", oneway=True),
        EdgeRecord(0, 2, s(0, 2), highway="residential", oneway=True),
        EdgeRecord(2, 3, s(2, 3), highway="residential", oneway=True),
    ]
    return build_graph(ids, lat, lon, edges, version="fixture-diamond")


def disconnected() -> Graph:
    """Two components {0,1} and {2,3}."""
    ids, lat, lon = _grid_coords(1, 4)
    edges = [
        EdgeRecord(0, 1, _straight(lat, lon, 0, 1), highway="residential"),
        EdgeRecord(1, 0, _straight(lat, lon, 0, 1), highway="residential"),
        EdgeRecord(2, 3, _straight(lat, lon, 2, 3), highway="residential"),
        EdgeRecord(3, 2, _straight(lat, lon, 2, 3), highway="residential"),
    ]
    return build_graph(ids, lat, lon, edges, version="fixture-disconnected")


def mixed_roads() -> Graph:
    """Small network with one road of each kind the profiles care about.

    0 -motorway-> 1      (car/taxi/truck only)
    0 -primary- 2 -primary- 1   (two-way; detour for motorbike/walk)
    2 -footway- 3        (walk only)
    3 -residential oneway-> 1  (walk may go against it)
    2 -primary motorcycle=no- 4
    """
    ids = [0, 1, 2, 3, 4]
    lat = [LAT0, LAT0, LAT0 + STEP, LAT0 + 2 * STEP, LAT0 + STEP]
    lon = [LON0, LON0 + 4 * STEP, LON0 + 2 * STEP, LON0 + 3 * STEP, LON0 + 3 * STEP]
    s = lambda u, v, k=1.0: _straight(lat, lon, u, v, k)  # noqa: E731
    edges = [
        EdgeRecord(0, 1, s(0, 1), highway="motorway", oneway=True, maxspeed="100"),
        EdgeRecord(0, 2, s(0, 2), highway="primary"),
        EdgeRecord(2, 0, s(0, 2), highway="primary"),
        EdgeRecord(2, 1, s(2, 1), highway="primary"),
        EdgeRecord(1, 2, s(2, 1), highway="primary"),
        EdgeRecord(2, 3, s(2, 3), highway="footway"),
        EdgeRecord(3, 2, s(2, 3), highway="footway"),
        EdgeRecord(3, 1, s(3, 1), highway="residential", oneway=True),
        EdgeRecord(2, 4, s(2, 4), highway="primary", motorcycle="no", maxweight="5"),
        EdgeRecord(4, 2, s(2, 4), highway="primary", motorcycle="no", maxweight="5"),
    ]
    return build_graph(ids, lat, lon, edges, version="fixture-mixed")


def named_turn() -> Graph:
    """0 -Lê Lợi-> 1 -Hai Bà Trưng-> 2: straight east, then turn right (south).

    Used to check FR-31 maneuver text and the street names carried on each turn.
    The unnamed variant drops both road names so the fallback text can be tested.
    """
    ids = [0, 1, 2]
    lat = [LAT0, LAT0, LAT0 - STEP]
    lon = [LON0, LON0 + STEP, LON0 + STEP]
    s = lambda u, v: _straight(lat, lon, u, v)  # noqa: E731
    edges = [
        EdgeRecord(0, 1, s(0, 1), highway="primary", name="Lê Lợi"),
        EdgeRecord(1, 2, s(1, 2), highway="primary", name="Hai Bà Trưng"),
    ]
    return build_graph(ids, lat, lon, edges, version="fixture-named")


def unnamed_turn() -> Graph:
    """Same geometry as ``named_turn`` with no ``name`` tags at all."""
    ids = [0, 1, 2]
    lat = [LAT0, LAT0, LAT0 - STEP]
    lon = [LON0, LON0 + STEP, LON0 + STEP]
    s = lambda u, v: _straight(lat, lon, u, v)  # noqa: E731
    edges = [
        EdgeRecord(0, 1, s(0, 1), highway="primary"),
        EdgeRecord(1, 2, s(1, 2), highway="primary"),
    ]
    return build_graph(ids, lat, lon, edges, version="fixture-unnamed")


def speed_mix() -> Graph:
    """Two routes with different road classes, so distance and time disagree.

    0 -residential-> 1 -residential-> 2   : 2 x 1000 m at 25 km/h = 288.0 s (shorter)
    0 -primary-> 3 -primary-> 2           : 2 x 1400 m at 50 km/h = 201.6 s (faster)

    The distance-optimal path is the slow one, which is exactly the case where
    "distance / profile top speed" used to under-report the travel time.
    """
    ids = [0, 1, 2, 3]
    lat = [LAT0, LAT0, LAT0, LAT0 + STEP]
    lon = [LON0, LON0 + STEP, LON0 + 2 * STEP, LON0 + STEP]
    edges = [
        EdgeRecord(0, 1, 1000.0, highway="residential"),
        EdgeRecord(1, 0, 1000.0, highway="residential"),
        EdgeRecord(1, 2, 1000.0, highway="residential"),
        EdgeRecord(2, 1, 1000.0, highway="residential"),
        EdgeRecord(0, 3, 1400.0, highway="primary"),
        EdgeRecord(3, 0, 1400.0, highway="primary"),
        EdgeRecord(3, 2, 1400.0, highway="primary"),
        EdgeRecord(2, 3, 1400.0, highway="primary"),
    ]
    return build_graph(ids, lat, lon, edges, version="fixture-speed-mix")
