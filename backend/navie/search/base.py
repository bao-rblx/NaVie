"""Common search interface (docs/03_algorithms.md §2)."""

from __future__ import annotations

import time
import tracemalloc
from collections.abc import Callable, Sequence
from typing import TypedDict

import numpy as np

from navie.graph.core import Graph

# Heuristic: node id -> admissible estimate of remaining cost to the target.
Heuristic = Callable[[int], float]


class SearchResult(TypedDict):
    """Output of every search algorithm."""

    path: list[int]  # node ids, empty if no path
    cost: float
    nodes_expanded: int
    runtime_ms: float
    peak_memory_kb: float
    explored: list[int]  # expansion order (for visualization)


def check_costs(costs: Sequence[float]) -> None:
    """Reject negative or NaN edge costs (Dijkstra/A* are only correct for costs >= 0)."""
    arr = np.asarray(costs, dtype=np.float64)
    if arr.size and (np.isnan(arr).any() or arr.min() < 0):
        raise ValueError("negative or NaN edge cost: UCS/A* require non-negative costs")


def reconstruct(parent: dict[int, int], source: int, target: int) -> list[int]:
    """Walk parent pointers back from target to source."""
    path = [target]
    while path[-1] != source:
        path.append(parent[path[-1]])
    path.reverse()
    return path


class Meter:
    """Measures runtime and peak Python memory of one search call."""

    def __init__(self, track_memory: bool) -> None:
        self.track = track_memory
        self.t0 = 0.0

    def __enter__(self) -> Meter:
        if self.track:
            tracemalloc.start()
        self.t0 = time.perf_counter()
        return self

    def __exit__(self, *exc: object) -> None:
        self.runtime_ms = (time.perf_counter() - self.t0) * 1000.0
        self.peak_kb = 0.0
        if self.track:
            _, peak = tracemalloc.get_traced_memory()
            tracemalloc.stop()
            self.peak_kb = peak / 1024.0


__all__ = ["Graph", "Heuristic", "Meter", "SearchResult", "check_costs", "reconstruct"]
