"""FastAPI application and the thin HTTP layer around NaVie services."""

from __future__ import annotations

from collections.abc import Callable

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from navie import __version__
from navie.errors import NavieError
from navie.geocode.service import Geocoder
from navie.geocode.service import load as load_geocoder
from navie.graph.core import Graph, load
from navie.planner.service import plan_trip, route_trip
from navie.schemas import ParseRequest, Place, PlanResponse, RouteRequest, RouteResponse, TripQuery


def create_app(
    graph: Graph | None = None,
    city: str = "hcmc",
    graph_loader: Callable[[], Graph] | None = None,
    geocoder: Geocoder | None = None,
    geocoder_loader: Callable[[], Geocoder] | None = None,
) -> FastAPI:
    """Build the API; accept an injected graph so tests and demos stay deterministic."""
    app = FastAPI(title="NaVie", version=__version__)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            "http://127.0.0.1:8080",
            "http://localhost:8080",
            "http://127.0.0.1:8000",
            "http://localhost:8000",
        ],
        allow_credentials=False,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["*"],
    )
    state: dict[str, Graph | Geocoder | None] = {"graph": graph, "geocoder": geocoder}

    def get_graph() -> Graph:
        if state["graph"] is None:
            try:
                state["graph"] = graph_loader() if graph_loader else load(city)
            except FileNotFoundError as exc:
                raise NavieError(
                    "OUT_OF_COVERAGE",
                    "Dữ liệu bản đồ chưa được xây dựng. Hãy chạy make data.",
                    "Map data is not built yet. Run make data.",
                ) from exc
        assert state["graph"] is not None
        assert isinstance(state["graph"], Graph)
        return state["graph"]

    def get_geocoder() -> Geocoder:
        if state["geocoder"] is None:
            try:
                state["geocoder"] = (
                    geocoder_loader() if geocoder_loader else load_geocoder(city, online=True)
                )
            except FileNotFoundError as exc:
                raise HTTPException(
                    status_code=503,
                    detail={
                        "error": {
                            "code": "OUT_OF_COVERAGE",
                            "message_vi": (
                                "Chỉ mục địa điểm chưa được xây dựng. Hãy chạy make data."
                            ),
                            "message_en": "The place index is not built yet. Run make data.",
                        }
                    },
                ) from exc
        assert isinstance(state["geocoder"], Geocoder)
        return state["geocoder"]

    @app.exception_handler(NavieError)
    async def navie_error(_request: Request, exc: NavieError) -> JSONResponse:
        status = (
            404
            if exc.code == "NO_PATH"
            else 422
            if exc.code in ("VALIDATION", "NOT_IMPLEMENTED")
            else 503
            if exc.code == "LLM_UNAVAILABLE"
            else 400
        )
        return JSONResponse(status_code=status, content=exc.to_dict())

    @app.get("/health")
    def health() -> dict[str, object]:
        graph = state["graph"]
        return {
            "status": "ok",
            "version": __version__,
            "llm_available": False,
            "graph": graph.version if isinstance(graph, Graph) else None,
        }

    @app.post("/v1/route", response_model=RouteResponse)
    def route(request: RouteRequest) -> RouteResponse:
        return route_trip(get_graph(), request)

    @app.post("/v1/plan", response_model=PlanResponse)
    def plan(query: TripQuery) -> PlanResponse:
        return plan_trip(get_graph(), query)

    @app.post("/v1/parse", response_model=TripQuery)
    def parse(_request: ParseRequest) -> TripQuery:
        raise NavieError(
            "LLM_UNAVAILABLE",
            "Nhập thông tin vào biểu mẫu để tiếp tục.",
            "The language parser is unavailable; use the form instead.",
        )

    @app.get("/v1/geocode", response_model=list[Place])
    def geocode(
        q: str = Query(min_length=1, max_length=200),
        near: str | None = Query(default=None, description="Optional latitude,longitude"),
        limit: int = Query(default=10, ge=1, le=10),
    ) -> list[Place]:
        near_point: tuple[float, float] | None = None
        if near:
            try:
                lat, lon = (float(value.strip()) for value in near.split(",", maxsplit=1))
                if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                    raise ValueError
                near_point = (lat, lon)
            except ValueError as exc:
                raise HTTPException(
                    status_code=422, detail="near must be latitude,longitude"
                ) from exc
        return get_geocoder().search(q, near=near_point, limit=limit)

    return app


app = create_app()
