"""Iterative-deepening A* for small graphs and demonstrations."""

from __future__ import annotations

import math
from collections.abc import Sequence

from navie.graph.core import Graph
from navie.search.base import Heuristic, Meter, SearchResult, check_costs


def ida_star(
    graph: Graph,
    source: int,
    target: int,
    costs: Sequence[float],
    heuristic: Heuristic | None = None,
    *,
    node_budget: int = 2_000_000,
    track_memory: bool = False,
    record_explored: bool = True,
) -> SearchResult:
    """Run IDA* with a finite node budget so a city graph cannot hang the API."""
    check_costs(costs)
    indptr, indices = graph.py_csr()
    vals = costs.tolist() if hasattr(costs, "tolist") else list(costs)
    h = heuristic or (lambda _n: 0.0)
    with Meter(track_memory) as m:
        explored: list[int] = []
        expanded = 0
        path = [source]
        answer: list[int] | None = None
        answer_cost = math.inf
        bound = h(source)
        while expanded < node_budget:
            next_bound = math.inf
            current_bound = bound

            def dfs(u: int, g: float, bound_value: float = current_bound) -> float:
                nonlocal answer, answer_cost, expanded, next_bound
                f = g + h(u)
                if f > bound_value:
                    next_bound = min(next_bound, f)
                    return f
                expanded += 1
                if record_explored:
                    explored.append(u)
                if u == target:
                    answer, answer_cost = path.copy(), g
                    return g
                best = math.inf
                for e in range(indptr[u], indptr[u + 1]):
                    c, v = vals[e], indices[e]
                    if not math.isfinite(c) or v in path:
                        continue
                    path.append(v)
                    best = min(best, dfs(v, g + c))
                    path.pop()
                    if answer is not None or expanded >= node_budget:
                        break
                return best

            dfs(source, 0.0)
            if answer is not None:
                break
            if next_bound == math.inf:
                break
            bound = next_bound
    return SearchResult(
        path=answer or [],
        cost=answer_cost,
        nodes_expanded=expanded,
        runtime_ms=m.runtime_ms,
        peak_memory_kb=m.peak_kb,
        explored=explored,
    )
