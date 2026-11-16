"""Application service that connects graph profiles, search and API models."""

from __future__ import annotations

import math
from typing import Any

import numpy as np

from navie.costs import estimate_cost
from navie.errors import NavieError, not_implemented
from navie.geo import haversine_m
from navie.graph.core import Graph
from navie.graph.profiles import Profile, profile
from navie.graph.snap import Snapper
from navie.schemas import (
    CostItem,
    DataVersion,
    Maneuver,
    PlanOption,
    PlanResponse,
    RouteRequest,
    RouteResponse,
    SearchStats,
    TripQuery,
)
from navie.search import (
    SearchResult,
    astar,
    bidir_astar,
    bidir_dijkstra,
    greedy,
    ida_star,
    straight_line,
    ucs,
)

# Algorithm labels the API accepts (schemas.Algorithm) but does not implement yet.
# They are rejected explicitly instead of being quietly answered by another algorithm.
_UNIMPLEMENTED = frozenset({"alt", "dstar_lite"})


def _bearing(a: tuple[float, float], b: tuple[float, float]) -> float:
    y = math.sin(math.radians(b[1] - a[1])) * math.cos(math.radians(b[0]))
    x = math.cos(math.radians(a[0])) * math.sin(math.radians(b[0])) - math.sin(
        math.radians(a[0])
    ) * math.cos(math.radians(b[0])) * math.cos(math.radians(b[1] - a[1]))
    return (math.degrees(math.atan2(y, x)) + 360) % 360


def _turn(delta: float) -> tuple[str, str, str]:
    d = abs(delta)
    if d > 170:
        return "u_turn", "Quay đầu", "Make a U-turn"
    if d < 20:
        return "straight", "Đi thẳng", "Continue straight"
    side_vi = "trái" if delta < 0 else "phải"
    side_en = "left" if delta < 0 else "right"
    if d < 45:
        return (
            ("slight_left" if delta < 0 else "slight_right"),
            f"Chếch sang {side_vi}",
            f"Bear {side_en}",
        )
    if d <= 135:
        return ("turn_left" if delta < 0 else "turn_right"), f"Rẽ {side_vi}", f"Turn {side_en}"
    return (
        ("sharp_left" if delta < 0 else "sharp_right"),
        f"Rẽ gấp sang {side_vi}",
        f"Sharp turn {side_en}",
    )


def _street(g: Graph, edge: int | None) -> str | None:
    """Road name of ``edge`` from the graph name table (-1 / out of range = unnamed)."""
    if edge is None or not g.names:
        return None
    e = int(edge)
    if not 0 <= e < g.n_edges:
        return None
    name_id = int(g.name_id[e])
    if 0 <= name_id < len(g.names):
        return g.names[name_id]
    return None


def _maneuvers(g: Graph, path: list[int], edges: list[int]) -> list[Maneuver]:
    """Turn-by-turn steps; ``edges[i]`` is the edge the path takes from ``path[i]``."""
    if len(path) < 3:
        return []
    result: list[Maneuver] = []
    prev = _bearing(
        (float(g.node_lat[path[0]]), float(g.node_lon[path[0]])),
        (float(g.node_lat[path[1]]), float(g.node_lon[path[1]])),
    )
    distance = float(g.length_m[edges[0]]) if edges else 0.0
    for i in range(1, len(path) - 1):
        a = (float(g.node_lat[path[i]]), float(g.node_lon[path[i]]))
        b = (float(g.node_lat[path[i + 1]]), float(g.node_lon[path[i + 1]]))
        bearing = _bearing(a, b)
        delta = (bearing - prev + 540) % 360 - 180
        kind, vi, en = _turn(delta)
        if kind != "straight":
            street = _street(g, edges[i] if i < len(edges) else None)
            if street:
                vi, en = _onto(vi, en, street)
            result.append(
                Maneuver(
                    type=kind,
                    street=street,
                    at_index=i,
                    distance_m=distance,
                    text_vi=vi,
                    text_en=en,
                )
            )
        distance += float(g.length_m[edges[i]]) if i < len(edges) else 0.0
        prev = bearing
    return result


def _onto(vi: str, en: str, street: str) -> tuple[str, str]:
    """Append "onto <street>" to a turn instruction (FR-31).

    Vietnamese uses "vào" for the street a turn enters; "Quay đầu" and the straight
    variants take "về" / no preposition, so only real turns get "vào".
    """
    if vi.startswith(("Rẽ", "Chếch")):
        return f"{vi} vào {street}", f"{en} onto {street}"
    return f"{vi} về {street}", f"{en} towards {street}"


def _edge_for_path(g: Graph, path: list[int], costs: Any) -> list[int]:
    edges: list[int] = []
    for u, v in zip(path, path[1:], strict=False):
        candidates = [
            e for e in g.out_edges(u) if int(g.indices[e]) == v and math.isfinite(float(costs[e]))
        ]
        if candidates:
            edges.append(min(candidates, key=lambda e: float(costs[e])))
    return edges


def _run_search(
    g: Graph,
    request: RouteRequest,
    prof: Profile,
    start: int,
    goal: int,
    cost_values: list[float],
) -> SearchResult:
    """Dispatch on ``request.algorithm``; every branch really runs that algorithm."""
    divisor = 1.0 if request.weight == "distance" else prof.max_speed_mps(g)
    heuristic = straight_line(g, goal, divisor)
    kwargs: dict[str, Any] = {
        "track_memory": request.debug.track_memory,
        "record_explored": request.debug.return_explored,
    }
    algorithm = request.algorithm
    if algorithm in _UNIMPLEMENTED:
        raise not_implemented(algorithm)
    if algorithm == "ucs":
        return ucs(g, start, goal, cost_values, **kwargs)
    if algorithm == "greedy":
        return greedy(g, start, goal, cost_values, heuristic, **kwargs)
    if algorithm == "weighted_astar":
        return astar(g, start, goal, cost_values, heuristic, w=1.5, **kwargs)
    if algorithm == "bidir_dijkstra":
        return bidir_dijkstra(g, start, goal, cost_values, **kwargs)
    if algorithm == "bidir_astar":
        # Backward potential: straight-line distance to the source, same divisor.
        reverse_heuristic = straight_line(g, start, divisor)
        return bidir_astar(g, start, goal, cost_values, heuristic, reverse_heuristic, **kwargs)
    if algorithm == "ida_star":
        return ida_star(g, start, goal, cost_values, heuristic, **kwargs)
    return astar(g, start, goal, cost_values, heuristic, **kwargs)


def route_trip(g: Graph, request: RouteRequest) -> RouteResponse:
    """Snap endpoints, run the selected team-owned algorithm and format a route."""
    load_t = (request.vehicle.load_kg / 1000.0) if request.vehicle else 0.0
    prof = profile(request.mode, load_t=load_t)
    snapper = Snapper(g, prof)
    start, goal = snapper.snap(*request.origin).node, snapper.snap(*request.destination).node
    costs = prof.edge_costs(g, request.weight)
    cost_values: list[float] = [float(value) for value in costs]
    result = _run_search(g, request, prof, start, goal, cost_values)
    if not result["path"]:
        raise NavieError("NO_PATH", "Không tìm thấy đường đi.", "No route found.")
    path = result["path"]
    edge_ids = _edge_for_path(g, path, costs)
    distance = sum(float(g.length_m[e]) for e in edge_ids)
    duration = _duration_s(g, prof, request.weight, edge_ids, float(result["cost"]))
    estimate = estimate_cost(request.mode, distance, duration)
    geometry = [(float(g.node_lat[n]), float(g.node_lon[n])) for n in path]
    explored_nodes = (
        result["explored"][: request.debug.max_points] if request.debug.return_explored else []
    )
    explored = [(float(g.node_lat[n]), float(g.node_lon[n])) for n in explored_nodes]
    return RouteResponse(
        distance_m=distance,
        duration_s=duration,
        cost_vnd=estimate.total_vnd,
        cost_breakdown=[CostItem(item=item, vnd=value) for item, value in estimate.breakdown],
        geometry=geometry,
        maneuvers=_maneuvers(g, path, edge_ids),
        stats=SearchStats(
            algorithm=request.algorithm,
            nodes_expanded=result["nodes_expanded"],
            runtime_ms=result["runtime_ms"],
            peak_memory_kb=result["peak_memory_kb"],
            path_cost=result["cost"],
        ),
        explored=explored,
        data_version=DataVersion(graph=g.version, pricing=estimate.last_updated),
        estimate=not estimate.verified,
    )


def _duration_s(
    g: Graph,
    prof: Profile,
    weight: str,
    edge_ids: list[int],
    path_cost: float,
) -> float:
    """Travel time of the chosen path.

    For ``weight="time"`` the search cost *is* the travel time. For ``weight="distance"``
    the search optimised meters, so the time has to be summed over the very same edges
    with the time profile — dividing the distance by the profile top speed silently
    reports every route too fast.
    """
    if weight == "time":
        return path_cost
    if not edge_ids:
        return 0.0
    time_costs = prof.edge_costs(g, "time")
    return float(np.sum(time_costs[edge_ids]))


def _plan_labels(options: list[PlanOption]) -> None:
    """Tag the fastest and cheapest option in place."""
    fastest = min(options, key=lambda x: x.duration_s).id
    cheapest = min(options, key=lambda x: x.cost_vnd).id
    for option in options:
        if option.id == fastest:
            option.labels.append("fastest")
        if option.id == cheapest:
            option.labels.append("cheapest")


def plan_trip(g: Graph, query: TripQuery) -> PlanResponse:
    """Return one route option per permitted mode, with simple Pareto labels."""
    if query.origin.latlon is None or query.destination.latlon is None:
        raise NavieError(
            "VALIDATION",
            "Vui lòng chọn đủ điểm đi và điểm đến.",
            "Choose both an origin and destination.",
        )
    allowed = query.modes_allowed or ["walk", "motorbike", "car", "taxi"]
    direct = haversine_m(*query.origin.latlon, *query.destination.latlon)
    if "walk" in allowed and direct > 10_000 and not query.modes_allowed:
        allowed = [m for m in allowed if m != "walk"]
    options: list[PlanOption] = []
    for mode in allowed:
        try:
            route = route_trip(
                g,
                RouteRequest(
                    origin=query.origin.latlon, destination=query.destination.latlon, mode=mode
                ),
            )
        except NavieError:
            continue
        options.append(
            PlanOption(
                id=mode,
                modes=[mode],
                legs=[route],
                distance_m=route.distance_m,
                duration_s=route.duration_s,
                cost_vnd=route.cost_vnd,
            )
        )
    if not options:
        raise NavieError(
            "NO_PATH", "Không tìm thấy lựa chọn phù hợp.", "No suitable route options found."
        )
    _plan_labels(options)
    return PlanResponse(
        options=options,
        pareto_ids=[o.id for o in options],
        summary={"text_vi": f"Đã tìm thấy {len(options)} lựa chọn.", "source": "template"},
    )
