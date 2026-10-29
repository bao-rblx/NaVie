"""A* search; UCS (Dijkstra) is A* with h = 0 (docs/03_algorithms.md §2).

Binary heap with lazy deletion and a closed set. Ties on f are broken in favour
of larger g (the node closer to the goal), stored as -g in the heap key.
"""

from __future__ import annotations

import heapq
import math
from collections.abc import Sequence

from navie.graph.core import Graph
from navie.search.base import Heuristic, Meter, SearchResult, check_costs, reconstruct


def astar(
    graph: Graph,
    source: int,
    target: int,
    costs: Sequence[float],
    heuristic: Heuristic | None = None,
    *,
    w: float = 1.0,
    track_memory: bool = False,
    record_explored: bool = True,
) -> SearchResult:
    """Shortest path source -> target.

    ``costs[e]`` is the cost of edge ``e`` (``inf`` = not allowed). With an admissible,
    consistent ``heuristic`` and ``w == 1`` the result is optimal. ``w > 1`` gives
    Weighted A* (cost <= w * optimal).
    """
    check_costs(costs)
    indptr, indices = graph.py_csr()
    cost_list = costs.tolist() if hasattr(costs, "tolist") else list(costs)
    h = heuristic or (lambda _n: 0.0)
    inf = math.inf

    with Meter(track_memory) as m:
        g_score: dict[int, float] = {source: 0.0}
        parent: dict[int, int] = {}
        closed: set[int] = set()
        explored: list[int] = []
        heap: list[tuple[float, float, int]] = [(w * h(source), -0.0, source)]
        found = False
        while heap:
            _, neg_g, u = heapq.heappop(heap)
            if u in closed:
                continue  # stale entry (lazy deletion)
            closed.add(u)
            if record_explored:
                explored.append(u)
            if u == target:
                found = True
                break
            gu = -neg_g
            for e in range(indptr[u], indptr[u + 1]):
                c = cost_list[e]
                if c == inf:
                    continue
                v = indices[e]
                if v in closed:
                    continue
                gv = gu + c
                if gv < g_score.get(v, inf):
                    g_score[v] = gv
                    parent[v] = u
                    heapq.heappush(heap, (gv + w * h(v), -gv, v))
        expanded = len(closed)

    if not found:
        return SearchResult(
            path=[],
            cost=inf,
            nodes_expanded=expanded,
            runtime_ms=m.runtime_ms,
            peak_memory_kb=m.peak_kb,
            explored=explored,
        )
    return SearchResult(
        path=reconstruct(parent, source, target),
        cost=g_score[target],
        nodes_expanded=expanded,
        runtime_ms=m.runtime_ms,
        peak_memory_kb=m.peak_kb,
        explored=explored,
    )
