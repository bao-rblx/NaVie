"""UCS + A* correctness. networkx is used ONLY here, as an oracle (AGENTS.md rule 1)."""

import math
import random

import networkx as nx
import numpy as np
import pytest

from navie.graph.core import Graph
from navie.graph.profiles import profile
from navie.search import astar, straight_line, ucs
from tests.fixtures import graphs


def to_nx(g: Graph, costs: np.ndarray) -> nx.DiGraph:
    G = nx.DiGraph()
    G.add_nodes_from(range(g.n_nodes))
    src = g.edge_source()
    for e in range(g.n_edges):
        if math.isfinite(costs[e]):
            u, v = int(src[e]), int(g.indices[e])
            if not G.has_edge(u, v) or G[u][v]["w"] > costs[e]:
                G.add_edge(u, v, w=float(costs[e]))
    return G


def path_cost(g: Graph, path: list[int], costs: np.ndarray) -> float:
    total = 0.0
    for u, v in zip(path, path[1:], strict=False):
        best = min(costs[e] for e in g.out_edges(u) if g.indices[e] == v)
        total += best
    return total


@pytest.mark.parametrize("weight", ["distance", "time"])
def test_grid_matches_networkx_all_pairs(weight: str) -> None:
    g = graphs.grid(5, 5)
    prof = profile("car")
    costs = prof.edge_costs(g, weight)  # type: ignore[arg-type]
    G = to_nx(g, costs)
    divisor = 1.0 if weight == "distance" else prof.max_speed_mps(g)
    for s in range(g.n_nodes):
        oracle = nx.single_source_dijkstra_path_length(G, s, weight="w")
        for t in range(g.n_nodes):
            r_ucs = ucs(g, s, t, costs)
            r_a = astar(g, s, t, costs, straight_line(g, t, divisor))
            assert r_ucs["cost"] == pytest.approx(oracle[t], abs=1e-6)
            assert r_a["cost"] == pytest.approx(oracle[t], abs=1e-6)
            assert path_cost(g, r_a["path"], costs) == pytest.approx(r_a["cost"], abs=1e-6)
            assert r_a["nodes_expanded"] <= r_ucs["nodes_expanded"]


def test_random_graphs_vs_networkx() -> None:
    rng = random.Random(42)
    for _ in range(20):
        rows, cols = rng.randint(3, 8), rng.randint(3, 8)
        g = graphs.grid(rows, cols)
        # Remove ~20% of edges to create detours / unreachable pairs.
        costs = profile("car").edge_costs(g, "distance")
        drop = np.array([rng.random() < 0.2 for _ in range(g.n_edges)])
        costs[drop] = np.inf
        G = to_nx(g, costs)
        for _ in range(10):
            s, t = rng.randrange(g.n_nodes), rng.randrange(g.n_nodes)
            r = astar(g, s, t, costs, straight_line(g, t))
            try:
                expected = nx.dijkstra_path_length(G, s, t, weight="w")
            except nx.NetworkXNoPath:
                assert r["path"] == [] and math.isinf(r["cost"])
                continue
            assert r["cost"] == pytest.approx(expected, abs=1e-6)
            assert r["path"][0] == s and r["path"][-1] == t


def test_diamond_picks_true_shortest() -> None:
    g = graphs.diamond()
    costs = profile("car").edge_costs(g, "distance")
    assert ucs(g, 0, 3, costs)["path"] == [0, 2, 3]
    assert astar(g, 0, 3, costs, straight_line(g, 3))["path"] == [0, 2, 3]


def test_line_and_same_node() -> None:
    g = graphs.line(5)
    costs = profile("car").edge_costs(g, "distance")
    r = ucs(g, 0, 4, costs)
    assert r["path"] == [0, 1, 2, 3, 4]
    assert r["explored"][0] == 0 and r["explored"][-1] == 4
    same = ucs(g, 2, 2, costs)
    assert same["path"] == [2] and same["cost"] == 0


def test_disconnected_no_path() -> None:
    g = graphs.disconnected()
    costs = profile("car").edge_costs(g, "distance")
    r = astar(g, 0, 3, costs, straight_line(g, 3))
    assert r["path"] == []
    assert math.isinf(r["cost"])
    assert r["nodes_expanded"] == 2


def test_zero_cost_edges() -> None:
    g = graphs.line(4)
    costs = np.zeros(g.n_edges)
    r = ucs(g, 0, 3, costs)
    assert r["cost"] == 0 and r["path"] == [0, 1, 2, 3]


def test_negative_cost_rejected() -> None:
    g = graphs.line(3)
    costs = profile("car").edge_costs(g, "distance")
    costs[0] = -1
    with pytest.raises(ValueError):
        ucs(g, 0, 2, costs)


def test_weighted_astar_bound() -> None:
    g = graphs.grid(8, 8)
    costs = profile("car").edge_costs(g, "distance")
    opt = ucs(g, 0, 63, costs)["cost"]
    for w in (1.2, 1.5, 2.0, 3.0):
        r = astar(g, 0, 63, costs, straight_line(g, 63), w=w)
        assert opt <= r["cost"] <= w * opt + 1e-6


def test_memory_tracking() -> None:
    g = graphs.grid(4, 4)
    costs = profile("car").edge_costs(g, "distance")
    r = ucs(g, 0, 15, costs, track_memory=True)
    assert r["peak_memory_kb"] > 0
    assert r["runtime_ms"] >= 0
