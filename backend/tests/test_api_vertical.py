from fastapi.testclient import TestClient

from navie.graph.profiles import profile
from navie.main import create_app
from navie.search import bidir_dijkstra, greedy, ida_star
from tests.fixtures.graphs import line


def test_route_endpoint_with_injected_fixture() -> None:
    graph = line(5)
    client = TestClient(create_app(graph=graph))
    payload = {
        "origin": [10.77, 106.70],
        "destination": [10.77, 106.704],
        "mode": "car",
        "algorithm": "astar",
        "debug": {"return_explored": True, "max_points": 3},
    }
    response = client.post("/v1/route", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["geometry"][0][0] == 10.77
    assert len(body["explored"]) <= 3
    assert body["stats"]["algorithm"] == "astar"


def test_plan_endpoint_returns_mode_options() -> None:
    graph = line(5)
    client = TestClient(create_app(graph=graph))
    response = client.post(
        "/v1/plan",
        json={
            "origin": {"text": "A", "latlon": [10.77, 106.70]},
            "destination": {"text": "B", "latlon": [10.77, 106.704]},
            "modes_allowed": ["car", "walk"],
        },
    )
    assert response.status_code == 200
    assert {option["id"] for option in response.json()["options"]} == {"car", "walk"}


def test_additional_search_algorithms_find_a_line_path() -> None:
    graph = line(5)
    costs = profile("car").edge_costs(graph, "distance").tolist()

    def heuristic(_node: int) -> float:
        return 0.0

    assert greedy(graph, 0, 4, costs, heuristic)["path"] == [0, 1, 2, 3, 4]
    assert bidir_dijkstra(graph, 0, 4, costs)["path"] == [0, 1, 2, 3, 4]
    assert ida_star(graph, 0, 4, costs, heuristic)["path"] == [0, 1, 2, 3, 4]
