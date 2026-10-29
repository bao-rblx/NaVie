"""Snap a lat/lon to the nearest edge a mode may use (KD-tree over nodes)."""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np
from numpy.typing import NDArray
from scipy.spatial import cKDTree

from navie.errors import out_of_coverage
from navie.geo import EARTH_RADIUS_M
from navie.graph.core import Graph
from navie.graph.profiles import Profile

# Points farther than this from any allowed edge count as outside coverage.
MAX_SNAP_M = 500.0
# Candidate nodes examined per query; their incident edges are tested exactly.
K_NEAREST = 16


@dataclass(frozen=True)
class Snap:
    """Result of snapping a point onto an edge u -> v."""

    node: int  # endpoint of the edge closer to the point (search start/goal)
    edge: int
    point: tuple[float, float]  # projected [lat, lon] on the edge
    distance_m: float


class Snapper:
    """Nearest allowed edge for one graph and mode."""

    def __init__(self, graph: Graph, prof: Profile) -> None:
        self.g = graph
        self.allowed = prof.allowed(graph)
        self.lat0 = float(np.mean(graph.node_lat)) if graph.n_nodes else 0.0
        self._kx = math.radians(1.0) * EARTH_RADIUS_M * math.cos(math.radians(self.lat0))
        self._ky = math.radians(1.0) * EARTH_RADIUS_M
        self.xy = self._project(graph.node_lat, graph.node_lon)
        # Only nodes touching an allowed edge are candidates.
        src = graph.edge_source()
        usable = np.zeros(graph.n_nodes, dtype=bool)
        usable[src[self.allowed]] = True
        usable[graph.indices[self.allowed]] = True
        self.cand = np.flatnonzero(usable)
        self.tree = cKDTree(self.xy[self.cand]) if self.cand.size else None
        self.src = src

    def _project(self, lat: NDArray[np.float64], lon: NDArray[np.float64]) -> NDArray[np.float64]:
        """Local equirectangular projection to meters (accurate at city scale)."""
        return np.column_stack((np.asarray(lon) * self._kx, np.asarray(lat) * self._ky))

    def _in_bbox(self, lat: float, lon: float) -> bool:
        if self.g.bbox is None:
            return True
        s, w, n, e = self.g.bbox
        return s <= lat <= n and w <= lon <= e

    def snap(self, lat: float, lon: float) -> Snap:
        """Snap a point; raises NavieError(OUT_OF_COVERAGE) when nothing is close enough."""
        if self.tree is None or not self._in_bbox(lat, lon):
            raise out_of_coverage()
        p = self._project(np.array([lat]), np.array([lon]))[0]
        k = min(K_NEAREST, self.cand.size)
        _, idx = self.tree.query(p, k=k)
        nodes = self.cand[np.atleast_1d(idx)]
        best: tuple[float, int, float] | None = None  # (dist, edge, t)
        g = self.g
        for u in nodes.tolist():
            edges = list(g.out_edges(u))
            if g.rev_indptr is not None and g.rev_edge is not None:
                edges += [int(e) for e in g.rev_edge[g.rev_indptr[u] : g.rev_indptr[u + 1]]]
            for e in edges:
                if not self.allowed[e]:
                    continue
                a, b = self.xy[self.src[e]], self.xy[g.indices[e]]
                ab = b - a
                denom = float(ab @ ab)
                t = 0.0 if denom == 0 else min(1.0, max(0.0, float((p - a) @ ab) / denom))
                d = float(np.hypot(*(a + t * ab - p)))
                if best is None or d < best[0]:
                    best = (d, e, t)
        if best is None or best[0] > MAX_SNAP_M:
            raise out_of_coverage()
        d, e, t = best
        u, v = int(self.src[e]), int(g.indices[e])
        lat_s = g.node_lat[u] + t * (g.node_lat[v] - g.node_lat[u])
        lon_s = g.node_lon[u] + t * (g.node_lon[v] - g.node_lon[u])
        return Snap(
            node=u if t < 0.5 else v,
            edge=e,
            point=(float(lat_s), float(lon_s)),
            distance_m=d,
        )
