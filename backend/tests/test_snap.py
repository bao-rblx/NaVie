import pytest

from navie.errors import NavieError
from navie.graph.profiles import profile
from navie.graph.snap import Snapper
from tests.fixtures import graphs


def test_snaps_to_nearest_node_on_edge() -> None:
    g = graphs.line(5)
    s = Snapper(g, profile("car")).snap(graphs.LAT0 + 0.0001, graphs.LON0 + 0.0029)
    assert s.node == 3
    assert s.distance_m == pytest.approx(11.1, abs=0.5)


def test_motorbike_does_not_snap_to_motorway() -> None:
    g = graphs.mixed_roads()
    # Point right on the motorway midpoint (0 -> 1).
    lat, lon = graphs.LAT0, graphs.LON0 + 2 * graphs.STEP
    car = Snapper(g, profile("car")).snap(lat, lon)
    moto = Snapper(g, profile("motorbike")).snap(lat, lon)
    assert car.edge == g.find_edge(0, 1)
    assert moto.edge != g.find_edge(0, 1)


def test_out_of_coverage_far_point() -> None:
    g = graphs.line(3)
    with pytest.raises(NavieError) as ei:
        Snapper(g, profile("car")).snap(21.0, 105.8)  # Hanoi
    assert ei.value.code == "OUT_OF_COVERAGE"


def test_out_of_coverage_outside_bbox() -> None:
    g = graphs.line(3)
    g.bbox = (10.0, 106.0, 10.5, 106.5)
    with pytest.raises(NavieError):
        Snapper(g, profile("car")).snap(graphs.LAT0, graphs.LON0)
