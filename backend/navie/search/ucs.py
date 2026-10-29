"""Uniform-cost search (Dijkstra): A* with a zero heuristic."""

from __future__ import annotations

from collections.abc import Sequence

from navie.graph.core import Graph
from navie.search.astar import astar
from navie.search.base import SearchResult


def ucs(
    graph: Graph,
    source: int,
    target: int,
    costs: Sequence[float],
    *,
    track_memory: bool = False,
    record_explored: bool = True,
) -> SearchResult:
    """Optimal path source -> target for non-negative edge costs."""
    return astar(
        graph,
        source,
        target,
        costs,
        None,
        track_memory=track_memory,
        record_explored=record_explored,
    )
