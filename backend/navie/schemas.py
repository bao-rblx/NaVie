"""Pydantic API contracts shared by the HTTP API and the optional LLM parser."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

Mode = Literal["walk", "motorbike", "car", "taxi", "truck"]
Algorithm = Literal[
    "ucs",
    "greedy",
    "astar",
    "weighted_astar",
    "bidir_dijkstra",
    "bidir_astar",
    "ida_star",
    "alt",
    "dstar_lite",
]
Weight = Literal["time", "distance"]


class LatLon(BaseModel):
    """A coordinate in the API's [latitude, longitude] convention."""

    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)

    def as_tuple(self) -> tuple[float, float]:
        return self.lat, self.lon


class DebugOptions(BaseModel):
    return_explored: bool = False
    max_points: int = Field(default=20_000, ge=0, le=20_000)
    # tracemalloc costs ~5x runtime; only the algorithm lab (peak_memory_kb) pays it.
    track_memory: bool = False


class Vehicle(BaseModel):
    type: str | None = None
    load_kg: float = Field(default=0, ge=0)


class RouteRequest(BaseModel):
    origin: tuple[float, float]
    destination: tuple[float, float]
    mode: Mode = "motorbike"
    algorithm: Algorithm = "astar"
    weight: Weight = "time"
    depart_at: datetime | None = None
    vehicle: Vehicle | None = None
    debug: DebugOptions = Field(default_factory=DebugOptions)

    @field_validator("origin", "destination")
    @classmethod
    def valid_coordinate(cls, value: tuple[float, float]) -> tuple[float, float]:
        if len(value) != 2 or not (-90 <= value[0] <= 90 and -180 <= value[1] <= 180):
            raise ValueError("coordinates must be [latitude, longitude]")
        return value


class CostItem(BaseModel):
    item: str
    vnd: int = Field(ge=0)


class Maneuver(BaseModel):
    type: str
    street: str | None = None
    at_index: int = Field(ge=0)
    distance_m: float = Field(ge=0)
    text_vi: str
    text_en: str


class SearchStats(BaseModel):
    algorithm: str
    nodes_expanded: int = Field(ge=0)
    runtime_ms: float = Field(ge=0)
    peak_memory_kb: float = Field(ge=0)
    path_cost: float


class DataVersion(BaseModel):
    graph: str
    pricing: str


class RouteResponse(BaseModel):
    distance_m: float = Field(ge=0)
    duration_s: float = Field(ge=0)
    cost_vnd: int = Field(ge=0)
    cost_breakdown: list[CostItem] = Field(default_factory=list)
    geometry: list[tuple[float, float]]
    maneuvers: list[Maneuver] = Field(default_factory=list)
    stats: SearchStats
    explored: list[tuple[float, float]] = Field(default_factory=list)
    data_version: DataVersion
    estimate: bool = True


class Place(BaseModel):
    name: str
    address: str | None = None
    latlon: tuple[float, float]
    kind: str = "unknown"


class TripEndpoint(BaseModel):
    text: str
    latlon: tuple[float, float] | None = None


class Cargo(BaseModel):
    weight_kg: float = Field(default=0, ge=0)
    volume_m3: float = Field(default=0, ge=0)


class TripQuery(BaseModel):
    origin: TripEndpoint
    destination: TripEndpoint
    depart_at: datetime | None = None
    arrive_by: datetime | None = None
    purpose: Literal["person", "cargo"] = "person"
    passengers: int = Field(default=1, ge=1)
    cargo: Cargo = Field(default_factory=Cargo)
    modes_allowed: list[Mode] = Field(default_factory=list)
    owned_vehicle: Literal["none", "motorbike", "car", "truck"] = "motorbike"
    optimize: Literal["fastest", "cheapest", "balanced", "fewest_transfers"] = "balanced"
    max_budget_vnd: int | None = Field(default=None, ge=0)


class PlanOption(BaseModel):
    id: str
    modes: list[Mode]
    legs: list[RouteResponse]
    distance_m: float
    duration_s: float
    cost_vnd: int
    transfers: int = 0
    co2_g: float = 0
    labels: list[str] = Field(default_factory=list)


class PlanResponse(BaseModel):
    options: list[PlanOption]
    pareto_ids: list[str]
    summary: dict[str, str]


class ParseRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2_000)


class IncidentRequest(BaseModel):
    type: Literal["accident", "flood", "roadwork", "jam", "police"]
    latlon: tuple[float, float]
    created_at: datetime | None = None
    expires_at: datetime | None = None
    confirmations: int = Field(default=1, ge=1)


class Incident(IncidentRequest):
    id: str
