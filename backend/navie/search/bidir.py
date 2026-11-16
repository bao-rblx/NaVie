"""Bidirectional search over the graph's transposed CSR (docs/03_algorithms.md §2).

``bidir_dijkstra`` is the plain two-frontier Dijkstra: alternate the frontier with the
smaller key and stop once ``top_f + top_b >= best``.

``bidir_astar`` is the same algorithm on *reduced* costs, using the consistent average
potential of Ikeda et al. (2001):

    p(n) = (h_target(n) - h_source(n)) / 2

with ``h_target`` a consistent estimate of the cost n -> target and ``h_source`` one of
n -> source. For any edge u -> v, consistency of both heuristics gives
``(h_target(v) - h_target(u)) + (h_source(u) - h_source(v)) >= -2 * w(u, v)``, i.e.
``w(u, v) + p(v) - p(u) >= 0``: every reduced cost is non-negative, so the search is
Dijkstra on the reduced graph and stays optimal. The forward frontier keys are
``g_f + p`` and the backward ones ``g_b - p``, so ``p + (-p) = 0`` keeps
``top_f + top_b`` a valid lower bound on any path through an unexpanded node — which is
exactly what the ``>= best`` termination test needs.
"""

from __future__ import annotations

import heapq
import math
import time
from collections.abc import Callable, Sequence

from navie.graph.core import Graph
from navie.search.base import Heuristic, Meter, SearchResult, check_costs

Potential = Callable[[int], float]


def _zero(_node: int) -> float:
    """Potential of a heuristically blind (Dijkstra) search."""
    return 0.0


def _bidir(
    graph: Graph,
    source: int,
    target: int,
    costs: Sequence[float],
    potential: Potential,
    *,
    track_memory: bool = False,
    record_explored: bool = True,
) -> SearchResult:
    """Two-frontier search with complementary potentials (forward p, backward -p)."""
    check_costs(costs)
    graph.ensure_reverse()
    assert (
        graph.rev_indptr is not None
        and graph.rev_indices is not None
        and graph.rev_edge is not None
    )
    rev_indptr, rev_indices, rev_edge = graph.rev_indptr, graph.rev_indices, graph.rev_edge
    indptr, indices = graph.py_csr()
    vals = costs.tolist() if hasattr(costs, "tolist") else list(costs)
    with Meter(track_memory) as m:
        if source == target:
            return SearchResult(
                path=[source],
                cost=0.0,
                nodes_expanded=1,
                runtime_ms=(time.perf_counter() - m.t0) * 1000.0,
                peak_memory_kb=0.0,
                explored=[source] if record_explored else [],
            )
        f_heap: list[tuple[float, int]] = [(potential(source), source)]
        b_heap: list[tuple[float, int]] = [(-potential(target), target)]
        df, db = {source: 0.0}, {target: 0.0}
        pf: dict[int, int] = {}
        pb: dict[int, int] = {}
        seen_f: set[int] = set()
        seen_b: set[int] = set()
        explored: list[int] = []
        best = math.inf
        meet = -1
        while f_heap and b_heap:
            if f_heap[0][0] + b_heap[0][0] >= best:
                break
            forward = f_heap[0][0] <= b_heap[0][0]
            if forward:
                heap, dist, other, parent, seen, sign = f_heap, df, db, pf, seen_f, 1.0
            else:
                heap, dist, other, parent, seen, sign = b_heap, db, df, pb, seen_b, -1.0
            key, u = heapq.heappop(heap)
            if u in seen or key != dist[u] + sign * potential(u):
                continue  # stale entry (lazy deletion)
            seen.add(u)
            if record_explored:
                explored.append(u)
            if u in other and dist[u] + other[u] < best:
                best, meet = dist[u] + other[u], u
            if forward:
                edges = ((indices[e], e) for e in range(indptr[u], indptr[u + 1]))
            else:
                edges = (
                    (int(rev_indices[e]), int(rev_edge[e]))
                    for e in range(int(rev_indptr[u]), int(rev_indptr[u + 1]))
                )
            du = dist[u]
            for v, edge in edges:
                c = vals[edge]
                if not math.isfinite(c):
                    continue
                nd = du + c
                if nd < dist.get(v, math.inf):
                    dist[v] = nd
                    parent[v] = u
                    heapq.heappush(heap, (nd + sign * potential(v), v))
                    if v in other and nd + other[v] < best:
                        best, meet = nd + other[v], v
        if meet < 0:
            return SearchResult(
                path=[],
                cost=math.inf,
                nodes_expanded=len(seen_f | seen_b),
                runtime_ms=(time.perf_counter() - m.t0) * 1000.0,
                peak_memory_kb=0.0,
                explored=explored,
            )
        left = [meet]
        while left[-1] != source:
            left.append(pf[left[-1]])
        left.reverse()
        right = [meet]
        while right[-1] != target:
            right.append(pb[right[-1]])
        path = left + right[1:]
    return SearchResult(
        path=path,
        cost=best,
        nodes_expanded=len(seen_f | seen_b),
        runtime_ms=m.runtime_ms,
        peak_memory_kb=m.peak_kb,
        explored=explored,
    )


def bidir_dijkstra(
    graph: Graph,
    source: int,
    target: int,
    costs: Sequence[float],
    *,
    track_memory: bool = False,
    record_explored: bool = True,
) -> SearchResult:
    """Find an optimal path by expanding frontiers from both endpoints."""
    return _bidir(
        graph,
        source,
        target,
        costs,
        _zero,
        track_memory=track_memory,
        record_explored=record_explored,
    )


def bidir_astar(
    graph: Graph,
    source: int,
    target: int,
    costs: Sequence[float],
    heuristic: Heuristic,
    reverse_heuristic: Heuristic,
    *,
    track_memory: bool = False,
    record_explored: bool = True,
) -> SearchResult:
    """Optimal path; both frontiers are steered by consistent average potentials.

    ``heuristic(n)`` must estimate the cost n -> target and ``reverse_heuristic(n)``
    the cost n -> source; both must be consistent (and therefore admissible) for the
    result to be optimal.
    """

    def potential(node: int) -> float:
        return 0.5 * (heuristic(node) - reverse_heuristic(node))

    return _bidir(
        graph,
        source,
        target,
        costs,
        potential,
        track_memory=track_memory,
        record_explored=record_explored,
    )
