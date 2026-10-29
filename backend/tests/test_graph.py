import time

import numpy as np
import pytest

from navie.geo import haversine_m
from navie.graph import (
    FLAG_FOOTWAY,
    FLAG_MOTORCYCLE_NO,
    FLAG_MOTORWAY,
    ONEWAY_AGAINST,
    ONEWAY_FORWARD,
    load,
    save,
)
from navie.graph.build import EdgeRecord, build_graph, parse_number, road_class_code
from tests.fixtures import graphs


def test_csr_shape_and_reverse() -> None:
    g = graphs.grid(3, 3)
    assert g.n_nodes == 9
    assert g.n_edges == 24  # 12 undirected segments x 2
    assert g.rev_indptr is not None and g.rev_indices is not None and g.rev_edge is not None
    # Every reverse slot points back at a forward edge with matching endpoints.
    src = g.edge_source()
    for v in range(g.n_nodes):
        for slot in range(g.rev_indptr[v], g.rev_indptr[v + 1]):
            e = g.rev_edge[slot]
            assert g.indices[e] == v
            assert src[e] == g.rev_indices[slot]


def test_oneway_gets_walk_only_reverse() -> None:
    g = graphs.diamond()
    e01 = g.find_edge(0, 1)
    e10 = g.find_edge(1, 0)
    assert g.oneway[e01] == ONEWAY_FORWARD
    assert g.oneway[e10] == ONEWAY_AGAINST


def test_flags_from_tags() -> None:
    g = graphs.mixed_roads()
    assert g.flags[g.find_edge(0, 1)] & FLAG_MOTORWAY
    assert g.flags[g.find_edge(2, 3)] & FLAG_FOOTWAY
    assert g.flags[g.find_edge(2, 4)] & FLAG_MOTORCYCLE_NO
    assert g.maxweight_t[g.find_edge(2, 4)] == 5.0


def test_length_clamped_to_straight_line() -> None:
    lat, lon = [10.77, 10.78], [106.70, 106.70]
    g = build_graph([10, 20], lat, lon, [EdgeRecord(10, 20, 1.0, highway="primary")])
    assert g.length_m[0] == pytest.approx(haversine_m(lat[0], lon[0], lat[1], lon[1]))


def test_parse_helpers() -> None:
    assert parse_number("50") == 50
    assert parse_number(["40", "60"]) == 40
    assert parse_number("30 mph") == pytest.approx(48.28, abs=0.01)
    assert parse_number("none") == 0
    assert road_class_code("primary_link") == road_class_code("primary")
    assert road_class_code("unknown_tag") == 0


def test_validate_rejects_negative_length() -> None:
    g = graphs.line(3)
    g.length_m[0] = -1
    with pytest.raises(ValueError):
        g.validate()


def test_save_load_roundtrip(tmp_path) -> None:  # type: ignore[no-untyped-def]
    g = graphs.mixed_roads()
    save(g, "fixture", tmp_path)
    t0 = time.perf_counter()
    g2 = load("fixture", tmp_path)
    assert time.perf_counter() - t0 < 10
    np.testing.assert_array_equal(g.indptr, g2.indptr)
    np.testing.assert_array_equal(g.flags, g2.flags)
    assert g2.names == g.names
    assert g2.version == "fixture-mixed"
    assert g2.rev_indptr is not None


def test_load_missing_raises(tmp_path) -> None:  # type: ignore[no-untyped-def]
    with pytest.raises(FileNotFoundError):
        load("nowhere", tmp_path)
