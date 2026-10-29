"""End-to-end: mode profiles + our search pick mode-legal routes (FR-35)."""

from navie.graph.profiles import profile
from navie.search import astar, straight_line, ucs
from tests.fixtures import graphs


def test_motorbike_route_avoids_motorway() -> None:
    g = graphs.mixed_roads()
    res = ucs(g, 0, 1, profile("motorbike").edge_costs(g))
    assert res["path"] == [0, 2, 1]


def test_car_takes_motorway() -> None:
    g = graphs.mixed_roads()
    res = ucs(g, 0, 1, profile("car").edge_costs(g))
    assert res["path"] == [0, 1]


def test_walk_goes_against_oneway() -> None:
    g = graphs.mixed_roads()
    prof = profile("walk")
    costs = prof.edge_costs(g)
    res = astar(g, 1, 3, costs, straight_line(g, 3, prof.max_speed_mps(g)))
    assert res["path"] == [1, 3]
    # A car cannot drive 1 -> 3 directly (one-way 3 -> 1) and has no other road to 3.
    assert ucs(g, 1, 3, profile("car").edge_costs(g))["path"] == []
