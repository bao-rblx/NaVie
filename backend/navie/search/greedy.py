"""Greedy best-first search."""

from __future__ import annotations

import heapq
import math
from collections.abc import Sequence

from navie.graph.core import Graph
from navie.search.base import Heuristic, Meter, SearchResult, check_costs, reconstruct


def greedy(
    graph: Graph,
    source: int,
    target: int,
    costs: Sequence[float],
    heuristic: Heuristic,
    *,
    track_memory: bool = False,
    record_explored: bool = True,
) -> SearchResult:
    """Return a valid path prioritising the smallest heuristic value."""
    check_costs(costs)
    indptr, indices = graph.py_csr()
    values = costs.tolist() if hasattr(costs, "tolist") else list(costs)
    with Meter(track_memory) as m:
        heap: list[tuple[float, int]] = [(heuristic(source), source)]
        parent: dict[int, int] = {}
        g_score = {source: 0.0}
        closed: set[int] = set()
        explored: list[int] = []
        found_path: list[int] | None = None
        found_cost = math.inf
        while heap:
            _, u = heapq.heappop(heap)
            if u in closed:
                continue
            closed.add(u)
            if record_explored:
                explored.append(u)
            if u == target:
                path = reconstruct(parent, source, target)
                found_path, found_cost = path, g_score[u]
                break
            for e in range(indptr[u], indptr[u + 1]):
                c = values[e]
                v = indices[e]
                if math.isfinite(c) and v not in closed and v not in g_score:
                    g_score[v] = g_score[u] + c
                    parent[v] = u
                    heapq.heappush(heap, (heuristic(v), v))
    return SearchResult(
        path=found_path or [],
        cost=found_cost,
        nodes_expanded=len(closed),
        runtime_ms=m.runtime_ms,
        peak_memory_kb=m.peak_kb,
        explored=explored,
    )
