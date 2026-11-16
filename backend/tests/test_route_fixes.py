"""Regression tests for the bugs in report/REQUIREMENTS_AUDIT_BACKEND.md §1/§3.1.

1. weight="distance" must report the true travel time of the chosen path (not
   distance / profile top speed).
2. bidirectional search must not rebuild the reverse CSR on every call.
3. stats.algorithm must name the algorithm that actually ran; unimplemented labels are
   rejected instead of being silently answered by A*.
4. maneuvers carry the street name of the edge the turn enters (FR-31).
5. tracemalloc is opt-in through DebugOptions.track_memory.
"""

import numpy as np
import pytest
from fastapi.testclient import TestClient

from navie.graph.core import Graph
from navie.graph.profiles import profile
from navie.main import create_app
from navie.planner.service import route_trip
from navie.schemas import DebugOptions, RouteRequest
from tests.fixtures import graphs

ORIGIN = [10.77, 106.70]
DESTINATION = [10.77, 106.704]


def _node_path(g: Graph, geometry: list[tuple[float, float]]) -> list[int]:
    """Map the returned geometry back to node ids (fixture coordinates are exact)."""
    lookup = {
        (round(float(g.node_lat[n]), 9), round(float(g.node_lon[n]), 9)): n
        for n in range(g.n_nodes)
    }
    return [lookup[(round(lat, 9), round(lon, 9))] for lat, lon in geometry]


def test_distance_weight_reports_the_time_cost_of_its_own_path() -> None:
    """Bug 1: sum the time profile over the edges the distance search actually chose.

    speed_mix() makes the shortest path the *slow* one (2 x 1000 m residential) while
    the fastest route is 2 x 1400 m primary, so the two weights disagree and the old
    "distance / v_max" formula is provably wrong.
    """
    g = graphs.speed_mix()
    prof = profile("car")
    route = route_trip(
        g,
        RouteRequest(
            origin=(10.77, 106.70),
            destination=(10.77, 106.702),
            mode="car",
            weight="distance",
        ),
    )
    time_costs = prof.edge_costs(g, "time")
    distance_costs = prof.edge_costs(g, "distance")
    nodes = _node_path(g, route.geometry)
    edges = [
        min(
            (e for e in g.out_edges(u) if int(g.indices[e]) == v),
            key=lambda e: float(distance_costs[e]),
        )
        for u, v in zip(nodes, nodes[1:], strict=False)
    ]
    assert route.duration_s == pytest.approx(float(np.sum(time_costs[edges])), rel=1e-9)
    # The old formula divided by the single fastest speed in the profile: always too fast.
    assert route.duration_s > route.distance_m / prof.max_speed_mps(g)


def test_distance_weight_is_never_faster_than_the_time_optimum() -> None:
    g = graphs.grid(5, 5)
    client = TestClient(create_app(graph=g))
    base = {"origin": ORIGIN, "destination": [10.774, 106.704], "mode": "car"}
    distance = client.post("/v1/route", json={**base, "weight": "distance"}).json()
    time = client.post("/v1/route", json={**base, "weight": "time"}).json()
    assert distance["duration_s"] >= time["duration_s"] - 1e-9
    assert distance["duration_s"] > distance["distance_m"] / profile("car").max_speed_mps(g)


def test_time_weight_duration_is_the_search_cost() -> None:
    """weight="time" behaviour must not change."""
    g = graphs.grid(4, 4)
    response = route_trip(
        g,
        RouteRequest(
            origin=(10.77, 106.70), destination=(10.773, 106.703), mode="car", weight="time"
        ),
    )
    assert response.duration_s == pytest.approx(response.stats.path_cost, rel=1e-12)


def test_route_does_not_rebuild_the_reverse_csr() -> None:
    """Bug 2: reuse the reverse CSR built by load()/build_graph()."""
    g = graphs.grid(5, 5)
    calls = {"n": 0}
    original = g.build_reverse

    def counting() -> None:
        calls["n"] += 1
        original()

    g.build_reverse = counting  # type: ignore[method-assign]
    route_trip(
        g,
        RouteRequest(
            origin=(10.77, 106.70),
            destination=(10.773, 106.703),
            mode="car",
            algorithm="bidir_dijkstra",
        ),
    )
    assert calls["n"] == 0


def test_bidir_astar_is_not_a_relabelled_bidirectional_dijkstra() -> None:
    """Bug 3: the guided search must expand strictly fewer nodes at the same cost."""
    g = graphs.grid(8, 8)
    client = TestClient(create_app(graph=g))
    payload = {
        "origin": ORIGIN,
        "destination": [10.777, 106.707],
        "mode": "car",
        "algorithm": "bidir_astar",
    }
    body = client.post("/v1/route", json=payload).json()
    assert body["stats"]["algorithm"] == "bidir_astar"
    blind = client.post("/v1/route", json={**payload, "algorithm": "bidir_dijkstra"}).json()
    assert body["stats"]["nodes_expanded"] < blind["stats"]["nodes_expanded"]
    assert body["stats"]["path_cost"] == pytest.approx(blind["stats"]["path_cost"], abs=1e-6)


@pytest.mark.parametrize("algorithm", ["alt", "dstar_lite"])
def test_unimplemented_algorithms_are_rejected(algorithm: str) -> None:
    """Bug 3: never answer a label we cannot run (the API used to run plain A*)."""
    g = graphs.grid(4, 4)
    client = TestClient(create_app(graph=g))
    response = client.post(
        "/v1/route",
        json={"origin": ORIGIN, "destination": DESTINATION, "algorithm": algorithm},
    )
    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "NOT_IMPLEMENTED"
    assert algorithm in error["message_en"]
    assert error["message_vi"]


@pytest.mark.parametrize(
    "algorithm",
    ["ucs", "greedy", "astar", "weighted_astar", "bidir_dijkstra", "bidir_astar"],
)
def test_every_accepted_algorithm_echoes_its_own_identity(algorithm: str) -> None:
    """stats.algorithm may only name an algorithm that actually ran."""
    g = graphs.grid(5, 5)
    client = TestClient(create_app(graph=g))
    body = client.post(
        "/v1/route",
        json={"origin": ORIGIN, "destination": DESTINATION, "algorithm": algorithm},
    ).json()
    assert body["stats"]["algorithm"] == algorithm
    assert body["stats"]["path_cost"] > 0


def test_maneuvers_carry_the_street_name_of_the_turn() -> None:
    """FR-31: "Rẽ phải vào Hai Bà Trưng", not a bare "Rẽ phải"."""
    g = graphs.named_turn()
    client = TestClient(create_app(graph=g))
    body = client.post(
        "/v1/route",
        json={"origin": [10.77, 106.70], "destination": [10.769, 106.701], "mode": "car"},
    ).json()
    assert body["maneuvers"], "the right-angle turn should produce one maneuver"
    turn = body["maneuvers"][0]
    assert turn["type"] == "turn_right"
    assert turn["street"] == "Hai Bà Trưng"
    assert turn["text_vi"] == "Rẽ phải vào Hai Bà Trưng"
    assert "Hai Bà Trưng" in turn["text_en"]


def test_maneuvers_fall_back_to_plain_text_without_a_name() -> None:
    """No name tag -> the old text and a null street, never a fabricated name."""
    g = graphs.unnamed_turn()
    client = TestClient(create_app(graph=g))
    body = client.post(
        "/v1/route",
        json={"origin": [10.77, 106.70], "destination": [10.769, 106.701], "mode": "car"},
    ).json()
    turn = body["maneuvers"][0]
    assert turn["street"] is None
    assert turn["text_vi"] == "Rẽ phải"
    assert turn["text_en"] == "Turn right"


def test_track_memory_is_opt_in() -> None:
    """P1: tracemalloc costs ~5x runtime, so peak_memory_kb stays 0 unless asked for."""
    g = graphs.grid(5, 5)
    client = TestClient(create_app(graph=g))
    request = {"origin": ORIGIN, "destination": DESTINATION, "mode": "car"}
    assert client.post("/v1/route", json=request).json()["stats"]["peak_memory_kb"] == 0.0
    asked = {**request, "debug": {"track_memory": True}}
    assert client.post("/v1/route", json=asked).json()["stats"]["peak_memory_kb"] > 0.0


def test_track_memory_defaults_to_off() -> None:
    assert DebugOptions().track_memory is False
