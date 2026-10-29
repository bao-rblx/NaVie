"""Admissible heuristics (docs/03_algorithms.md §2).

* distance weight: haversine(n, target) in meters. Every edge length is at least the
  straight-line distance between its endpoints, so h never overestimates.
* time weight: haversine / v_max, v_max = fastest free-flow speed in the profile.
  No edge can be traversed faster than v_max, so h is admissible; it is consistent
  because haversine obeys the triangle inequality.
"""

from __future__ import annotations

import numpy as np

from navie.geo import EARTH_RADIUS_M
from navie.graph.core import Graph
from navie.search.base import Heuristic


def straight_line(graph: Graph, target: int, divisor: float = 1.0) -> Heuristic:
    """Haversine distance to ``target`` divided by ``divisor`` (1 = meters, v_max = seconds).

    Precomputed for all nodes with numpy, then looked up per call.
    """
    lat = np.radians(graph.node_lat)
    lon = np.radians(graph.node_lon)
    lt, ln = lat[target], lon[target]
    a = np.sin((lat - lt) / 2) ** 2 + np.cos(lat) * np.cos(lt) * np.sin((lon - ln) / 2) ** 2
    d = 2 * EARTH_RADIUS_M * np.arcsin(np.minimum(1.0, np.sqrt(a)))
    # Small safety margin so float rounding vs. stored edge lengths never breaks admissibility.
    table = (d * (1 - 1e-9) / divisor).tolist()
    return table.__getitem__
