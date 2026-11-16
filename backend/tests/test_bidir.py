"""Bidirectional A*: the same cost as Dijkstra, on reduced costs (docs/03_algorithms.md §2).

``bidir_astar`` is a *real* second implementation, not a relabelled bidirectional
Dijkstra — the tests below pin both its result (no worse than the optimum) and its
behaviour (it must expand fewer nodes than the unguided searches on a grid).
"""

import math
import random

import networkx as nx
import numpy as np
import pytest

from navie.graph.core import Graph
from navie.graph.profiles import profile
from navie.search import astar, bidir_astar, bidir_dijkstra, straight_line, ucs
from tests.fixtures import graphs
from tests.test_search import to_nx


@pytest.mark.parametrize("weight", ["distance", "time"])
def test_bidir_astar_matches_networkx_dijkstra(weight: str) -> None:
    """T-07: bidirectional search must equal the UCS cost, not merely find a path."""
    g = graphs.grid(6, 6)
    prof = profile("car")
    costs = prof.edge_costs(g, weight)  # type: ignore[arg-type]
    divisor = 1.0 if weight == "distance" else prof.max_speed_mps(g)
    G = to_nx(g, costs)
    for s in range(g.n_nodes):
        oracle = nx.single_source_dijkstra_path_length(G, s, weight="w")
        for t in range(g.n_nodes):
            expected = oracle[t]
            reverse_h = straight_line(g, s, divisor)
            for result in (
                bidir_astar(g, s, t, costs, straight_line(g, t, divisor), reverse_h),
                bidir_dijkstra(g, s, t, costs),
            ):
                assert result["cost"] == pytest.approx(expected, abs=1e-6)
                assert result["path"][0] == s and result["path"][-1] == t


def test_bidir_astar_random_graphs_with_detours() -> None:
    rng = random.Random(7)
    for _ in range(10):
        g = graphs.grid(rng.randint(4, 7), rng.randint(4, 7))
        prof = profile("car")
        costs = prof.edge_costs(g, "distance")
        drop = np.array([rng.random() < 0.2 for _ in range(g.n_edges)])
        costs[drop] = np.inf
        G = to_nx(g, costs)
        for _ in range(10):
            s, t = rng.randrange(g.n_nodes), rng.randrange(g.n_nodes)
            r = bidir_astar(g, s, t, costs, straight_line(g, t), straight_line(g, s))
            try:
                expected = nx.dijkstra_path_length(G, s, t, weight="w")
            except nx.NetworkXNoPath:
                assert r["path"] == [] and math.isinf(r["cost"])
                continue
            assert r["cost"] == pytest.approx(expected, abs=1e-6)


def test_bidir_astar_prunes_more_than_bidirectional_dijkstra() -> None:
    g = graphs.grid(8, 8)
    costs = profile("car").edge_costs(g, "distance")
    goal = g.n_nodes - 1
    guided = bidir_astar(g, 0, goal, costs, straight_line(g, goal), straight_line(g, 0))
    blind = bidir_dijkstra(g, 0, goal, costs)
    heur = astar(g, 0, goal, costs, straight_line(g, goal))
    assert guided["cost"] == pytest.approx(blind["cost"], abs=1e-6)
    assert guided["nodes_expanded"] < blind["nodes_expanded"]
    assert guided["nodes_expanded"] <= heur["nodes_expanded"]


def test_bidir_astar_trivial_and_no_path() -> None:
    g = graphs.grid(4, 4)
    costs = profile("car").edge_costs(g, "distance")
    same = bidir_astar(g, 5, 5, costs, straight_line(g, 5), straight_line(g, 5))
    assert same["path"] == [5] and same["cost"] == 0.0
    cut = graphs.disconnected()
    ccut = profile("car").edge_costs(cut, "distance")
    none = bidir_astar(cut, 0, 3, ccut, straight_line(cut, 3), straight_line(cut, 0))
    assert none["path"] == [] and math.isinf(none["cost"])


def test_bidir_dijkstra_does_not_rebuild_reverse_csr() -> None:
    """The reverse CSR is built at load time; a search must not pay the argsort again."""
    g = graphs.grid(5, 5)
    costs = profile("car").edge_costs(g, "distance")
    assert g.rev_indptr is not None
    calls = {"n": 0}
    original = g.build_reverse

    def counting() -> None:
        calls["n"] += 1
        original()

    g.build_reverse = counting  # type: ignore[method-assign]
    bidir_dijkstra(g, 0, 12, costs)
    bidir_astar(g, 0, 12, costs, straight_line(g, 12), straight_line(g, 0))
    assert calls["n"] == 0


def test_ensure_reverse_is_idempotent_and_builds_when_missing() -> None:
    g = graphs.grid(3, 3)
    g.rev_indptr = None
    g.rev_indices = None
    g.rev_edge = None
    g.ensure_reverse()
    assert g.rev_indptr is not None and g.rev_indices is not None and g.rev_edge is not None
    pointer = g.rev_indptr
    g.ensure_reverse()
    assert g.rev_indptr is pointer  # same object: nothing was rebuilt


def _cost(g: Graph, path: list[int], costs: np.ndarray) -> float:
    pairs = zip(path, path[1:], strict=False)
    return sum(min(costs[e] for e in g.out_edges(u) if g.indices[e] == v) for u, v in pairs)


def test_bidir_astar_path_cost_equals_reported_cost() -> None:
    """Time-weighted search: the potentials must use the m/s divisor, like service.py does."""
    g = graphs.grid(7, 7)
    prof = profile("car")
    costs = prof.edge_costs(g, "time")
    divisor = prof.max_speed_mps(g)
    t = g.n_nodes - 1
    r = bidir_astar(g, 0, t, costs, straight_line(g, t, divisor), straight_line(g, 0, divisor))
    assert _cost(g, r["path"], costs) == pytest.approx(r["cost"], abs=1e-6)
    assert ucs(g, 0, t, costs)["cost"] == pytest.approx(r["cost"], abs=1e-6)


def test_bidir_astar_with_a_meters_heuristic_on_seconds_is_still_complete() -> None:
    """An over-inflated (inadmissible) potential must not lose the target, only optimality.

    Guards the wiring mistake that is easy to make: passing straight_line() in meters
    while the costs are seconds. The result may be suboptimal but must stay a real path.
    """
    g = graphs.grid(5, 5)
    costs = profile("car").edge_costs(g, "time")
    t = g.n_nodes - 1
    r = bidir_astar(g, 0, t, costs, straight_line(g, t), straight_line(g, 0))
    assert r["path"][0] == 0 and r["path"][-1] == t
    assert _cost(g, r["path"], costs) == pytest.approx(r["cost"], abs=1e-6)
