import numpy as np
import pytest

from navie.graph import FLAG_MOTORWAY
from navie.graph.profiles import WALK_KMH, profile
from tests.fixtures import graphs


def test_motorbike_never_on_motorway_or_motorcycle_no() -> None:
    g = graphs.mixed_roads()
    allowed = profile("motorbike").allowed(g)
    assert not allowed[(g.flags & FLAG_MOTORWAY) != 0].any()
    assert not allowed[g.find_edge(2, 4)]


def test_walk_ignores_oneway_and_uses_footway() -> None:
    g = graphs.mixed_roads()
    allowed = profile("walk").allowed(g)
    assert allowed[g.find_edge(1, 3)]  # against the one-way 3 -> 1
    assert allowed[g.find_edge(2, 3)]  # footway
    assert not allowed[g.find_edge(0, 1)]  # motorway


def test_car_respects_oneway_and_skips_footway() -> None:
    g = graphs.mixed_roads()
    allowed = profile("car").allowed(g)
    assert not allowed[g.find_edge(1, 3)]
    assert not allowed[g.find_edge(2, 3)]


def test_truck_weight_limit() -> None:
    g = graphs.mixed_roads()
    e = g.find_edge(2, 4)
    assert profile("truck", load_t=3).allowed(g)[e]
    assert not profile("truck", load_t=8).allowed(g)[e]


def test_speeds() -> None:
    g = graphs.mixed_roads()
    e_mw = g.find_edge(0, 1)
    car = profile("car").speed_kmh(g)
    assert np.all(profile("walk").speed_kmh(g) == WALK_KMH)
    assert profile("motorbike").speed_kmh(g)[e_mw] == pytest.approx(car[e_mw] * 0.9)
    assert profile("truck").speed_kmh(g).max() <= 60


def test_edge_costs_inf_when_disallowed() -> None:
    g = graphs.mixed_roads()
    c = profile("motorbike").edge_costs(g, "distance")
    assert np.isinf(c[g.find_edge(0, 1)])
    assert c[g.find_edge(0, 2)] == pytest.approx(g.length_m[g.find_edge(0, 2)])


def test_unknown_mode() -> None:
    with pytest.raises(ValueError):
        profile("boat")  # type: ignore[arg-type]
