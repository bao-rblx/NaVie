"""Per-mode edge filters and free-flow speeds (docs/03_algorithms.md §1, FR-35).

A profile turns a graph into a per-edge cost array: seconds (``weight="time"``) or
meters (``weight="distance"``). Disallowed edges cost ``inf``; search skips them.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Literal

import numpy as np
from numpy.typing import NDArray

from navie import config
from navie.graph.core import (
    FLAG_FOOTWAY,
    FLAG_MOTORCYCLE_NO,
    FLAG_MOTORWAY,
    ONEWAY_AGAINST,
    ROAD_CLASSES,
    Graph,
)

Mode = Literal["walk", "motorbike", "car", "taxi", "truck"]
Weight = Literal["time", "distance"]
MODES: tuple[Mode, ...] = ("walk", "motorbike", "car", "taxi", "truck")

# Values stated in docs/03_algorithms.md §1.
WALK_KMH = 4.8
MOTORBIKE_FACTOR = 0.9
TRUCK_MAX_KMH = 60.0
TRUCK_MIN_HEIGHT_M = 4.0

_TRUNK = ROAD_CLASSES.index("trunk")


@lru_cache(maxsize=4)
def class_speeds(path: Path | None = None) -> NDArray[np.float64]:
    """Default km/h per road_class code, from ``data/graph/class_speeds.json``."""
    p = path or config.DATA_DIR / "graph" / "class_speeds.json"
    table = json.loads(p.read_text(encoding="utf-8"))["kmh"]
    return np.array([float(table[c]) for c in ROAD_CLASSES], dtype=np.float64)


@dataclass(frozen=True)
class Profile:
    """Edge rules for one travel mode."""

    mode: Mode
    load_t: float = 0.0  # truck load, compared with maxweight_t

    def allowed(self, g: Graph) -> NDArray[np.bool_]:
        """Boolean mask of edges this mode may use."""
        f = g.flags
        motorway = (f & FLAG_MOTORWAY) != 0
        footway = (f & FLAG_FOOTWAY) != 0
        against = g.oneway == ONEWAY_AGAINST
        if self.mode == "walk":
            # No sidewalk data yet: exclude all motorway/trunk. Ignores one-way.
            return ~motorway & (g.road_class != _TRUNK)
        vehicle = ~footway & ~against
        if self.mode == "motorbike":
            return vehicle & ~motorway & ((f & FLAG_MOTORCYCLE_NO) == 0)
        if self.mode in ("car", "taxi"):
            return vehicle
        # truck: car rules + weight/height limits (0 = no limit). Ban windows: TODO (C).
        weight_ok = (g.maxweight_t == 0) | (g.maxweight_t >= self.load_t)
        height_ok = (g.maxheight_m == 0) | (g.maxheight_m >= TRUCK_MIN_HEIGHT_M)
        return vehicle & weight_ok & height_ok

    def speed_kmh(self, g: Graph) -> NDArray[np.float64]:
        """Free-flow speed per edge (km/h), ignoring whether the edge is allowed."""
        if self.mode == "walk":
            return np.full(g.n_edges, WALK_KMH)
        default = class_speeds()[g.road_class]
        tagged = g.maxspeed_kmh.astype(np.float64)
        base = np.where(tagged > 0, np.minimum(tagged, default), default)
        if self.mode == "motorbike":
            return (base * MOTORBIKE_FACTOR).astype(np.float64)
        if self.mode == "truck":
            return np.minimum(base, TRUCK_MAX_KMH)
        return base

    def max_speed_mps(self, g: Graph) -> float:
        """Highest free-flow speed on any allowed edge (for an admissible time heuristic)."""
        mask = self.allowed(g)
        if not mask.any():
            return 1.0
        return float(self.speed_kmh(g)[mask].max()) / 3.6

    def edge_costs(self, g: Graph, weight: Weight = "time") -> NDArray[np.float64]:
        """Cost per edge: seconds or meters; ``inf`` where not allowed."""
        if weight == "distance":
            cost = g.length_m.astype(np.float64).copy()
        else:
            cost = g.length_m / (self.speed_kmh(g) / 3.6)
        cost[~self.allowed(g)] = np.inf
        return cost


def profile(mode: Mode, load_t: float = 0.0) -> Profile:
    """Return the profile for a mode name."""
    if mode not in MODES:
        raise ValueError(f"unknown mode {mode!r}")
    return Profile(mode=mode, load_t=load_t)
