# NaVie — Architecture

## 1. Big picture
```
Flutter app (Web + Android)
  ├─ Planner screens   ├─ Driver mode   ├─ Algorithm lab   ├─ GPS simulator
  │  map: maplibre_gl + OpenFreeMap vector tiles (free, no key)
  │  TTS: flutter_tts (vi-VN)   location: geolocator
  ▼ HTTPS/JSON + WebSocket (driver mode)
FastAPI backend (Python 3.11, single process, runs on a laptop)
  ├─ api/          REST + WS routes, request validation (pydantic)
  ├─ graph/        OSM → compact graph (CSR numpy arrays), per-mode profiles
  ├─ search/       OUR algorithms: ucs, greedy, astar, weighted_astar, bidir, ida_star, alt, dstar_lite
  ├─ traffic/      Bayesian Network (own inference), incident store, time-dependent weights
  ├─ planner/      mode orchestration, multimodal hub graph, Pareto filter
  ├─ costs/        fuel, toll, taxi, courier, ticket formulas from data/ files
  ├─ nav/          maneuver generation, Vietnamese instructions, off-route check
  ├─ logistics/    TSP/VRP: nearest neighbour, hill climbing, simulated annealing
  ├─ geocode/      fuzzy search over OSM names/POIs (rapidfuzz), Vietnamese normalizer
  └─ llm/          optional: Gemini free tier or Ollama; parse + explain only
Storage: files (graph .npz, YAML/CSV data) + SQLite for incidents/GPS samples
Tools: scripts/ (data build, benchmarks, plots), tests/ (pytest)
```
Why no PostGIS / Valhalla / Docker in the main path: the course grades our own search algorithms, and a laptop-only Python stack is simpler for 4 students. Valhalla/networkx may be installed as **test oracles** only.

## 2. Repo layout
```
NaVie/
├── AGENTS.md
├── Makefile                 # setup, data, run, test, bench, lint
├── docs/                    # this spec
├── backend/
│   ├── pyproject.toml       # uv / pip, pinned versions
│   ├── navie/
│   │   ├── main.py          # FastAPI app factory
│   │   ├── config.py        # env vars, paths
│   │   ├── api/ graph/ search/ traffic/ planner/ costs/ nav/ logistics/ geocode/ llm/
│   │   └── schemas.py       # pydantic models (single source of truth for the API)
│   └── tests/               # mirrors navie/ ; fixtures/ has tiny hand-made graphs
├── data/
│   ├── raw/                 # downloaded OSM extracts (git-ignored)
│   ├── build/               # generated graphs, BN params (git-ignored)
│   ├── pricing/             # fuel.yaml, tolls.csv, taxi.yaml, courier.yaml, vehicles.yaml
│   ├── schedules/           # hubs.csv, trains.csv, flights.csv, coaches.csv, ferries.csv
│   └── traffic/             # simulated_observations.csv, bn_structure.yaml
├── scripts/                 # build_graph.py, simulate_traffic.py, fit_bn.py, bench.py, plots.py
├── app/                     # Flutter project (lib/features/{planner,driver,lab,simulator,report})
└── report/                  # essay draft, figures, slides
```

## 3. Tech stack (pinned at setup time)
| Layer | Choice | Notes |
|---|---|---|
| Backend | Python 3.11, FastAPI, uvicorn, pydantic v2, numpy, scipy | |
| Graph build | osmnx (download + simplify only), pyrosm optional | Extract → our CSR arrays |
| Geometry | shapely, pyproj | haversine for heuristics |
| Test oracles | networkx, pgmpy | tests only |
| ML/plots | pandas, matplotlib | benchmarks + report figures |
| Fuzzy search | rapidfuzz, unidecode | accent-insensitive Vietnamese |
| LLM | google-genai (Gemini free tier) or Ollama `qwen2.5:7b` | optional, behind interface |
| App | Flutter 3.x stable: maplibre_gl, geolocator, flutter_tts, dio, riverpod, go_router, intl | |
| Tiles | OpenFreeMap (`https://tiles.openfreemap.org/styles/liberty`) | free, no key; OSM attribution required |
| Quality | ruff, mypy (lenient), pytest, pytest-cov; flutter analyze, flutter test | CI on GitHub Actions |

## 4. API contract (v1)
All bodies JSON. Coordinates are `[lat, lon]`. Times ISO-8601 with `+07:00`.

### `POST /v1/route` — single mode, single algorithm
The executable contract for this endpoint and the related `/v1/plan`, `/v1/parse`,
and `/v1/geocode` endpoints lives in `backend/navie/schemas.py`; this section is
the human-readable API reference and must be updated alongside that module.

```json
// request
{ "origin": [10.7725, 106.6980], "destination": [10.7300, 106.7210],
  "mode": "motorbike",               // walk|motorbike|car|taxi|truck
  "algorithm": "astar",              // ucs|greedy|astar|weighted_astar|bidir_dijkstra|bidir_astar|ida_star|alt|dstar_lite
  "weight": "time",                  // time|distance
  "depart_at": "2026-10-01T08:00:00+07:00",
  "vehicle": { "type": "motorbike_110cc", "load_kg": 0 },
  "debug": { "return_explored": true, "max_points": 20000 } }
// response
{ "distance_m": 6120, "duration_s": 1260, "cost_vnd": 9800,
  "cost_breakdown": [{"item":"fuel","vnd":3800},{"item":"parking","vnd":6000}],
  "geometry": [[10.7725,106.6980], ...],
  "maneuvers": [{"type":"turn_right","street":"Lê Lợi","at_index":12,"distance_m":200,"text_vi":"Rẽ phải vào Lê Lợi","text_en":"Turn right onto Lê Lợi"}],
  "stats": { "algorithm":"astar","nodes_expanded":18234,"runtime_ms":143,"peak_memory_kb":5120,"path_cost":1260 },
  "explored": [[10.77,106.69], ...],
  "data_version": { "graph":"hcmc-2026-09-01", "pricing":"2026-09-15" } }
```

### `POST /v1/plan` — compare modes / multimodal
Request: `TripQuery` (below). Response: `{ "options": [Option...], "pareto_ids": [...], "summary": {"text_vi": "...", "source": "llm|template"} }` where each Option = `{id, modes[], legs[], distance_m, duration_s, cost_vnd, transfers, co2_g, labels[] ("fastest","cheapest","balanced")}` and each leg = route response subset or `{type:"scheduled", carrier, service_no, depart_at, arrive_at, from_hub, to_hub, fare_vnd}`.

### `TripQuery` schema (also the LLM output schema)
```json
{ "origin": {"text":"Thủ Đức","latlon":null},
  "destination": {"text":"Quận 7","latlon":null},
  "depart_at": null, "arrive_by": null,
  "purpose": "person",                 // person|cargo
  "passengers": 1,
  "cargo": {"weight_kg": 0, "volume_m3": 0},
  "modes_allowed": [],                 // empty = all applicable
  "owned_vehicle": "motorbike",        // none|motorbike|car|truck
  "optimize": "balanced",              // fastest|cheapest|balanced|fewest_transfers
  "max_budget_vnd": null }
```

### Others
| Endpoint | Purpose |
|---|---|
| `POST /v1/parse` | `{text}` → `TripQuery` (LLM; 503 + `{"fallback":"form"}` if unavailable) |
| `GET /v1/geocode?q=&near=` | top 10 matches `{name, address, latlon, kind}` |
| `POST /v1/incidents` / `GET /v1/incidents?bbox=` | create/list incidents `{type, latlon, created_at, expires_at, confirmations}` |
| `POST /v1/nav/reroute` | `{position, heading_deg, destination, mode, route_id}` → route response |
| `WS /v1/nav/session` | client sends `{lat,lon,speed,heading,ts}` every 1 s; server pushes `{event:"incident_ahead"|"faster_route", ...}` |
| `POST /v1/logistics/optimize` | `{depot, stops[], vehicles[], method:"sa"|"hc"|"nn"|"brute"}` → order + stats |
| `GET /v1/bench/latest` | last benchmark CSV summary for the lab screen |
| `GET /health` | versions of graph, pricing, BN, LLM availability |

Errors: `{ "error": {"code":"NO_PATH"|"OUT_OF_COVERAGE"|"VALIDATION"|"LLM_UNAVAILABLE", "message_vi":"...", "message_en":"..."} }`.

## 5. AI call map
| Moment | Component | Type | Frequency | Fallback |
|---|---|---|---|---|
| User types/speaks free text | `llm/parse` | LLM, JSON-schema constrained | once per request, cached by text hash | show form |
| Results shown | `llm/explain` | LLM, numbers injected from result | once, optional | template sentence |
| Every route request | `search/*` | **classical AI search (graded)** | every request | — |
| Edge travel times | `traffic/bn` | Bayesian Network inference | cached per (hour, day_type, weather, road_class) | free-flow speeds |
| New incident | `traffic/incidents` | rules + merge | per report | — |
| Driver position update | `nav/` | geometry code, no AI | 1 Hz | — |
| Multi-stop order | `logistics/sa` | local search | per request | nearest neighbour |
| Voice command (C) | STT on device → `llm/parse` intent | LLM | on demand | buttons |

LLM rule: the LLM never outputs a price, duration or distance that is shown to the user unless it was copied from the result JSON; `llm/explain` output is checked — any number not present in the result → use template.

## 6. App screens
1. **Home/Planner** — search boxes, mode chips, depart time, optimize toggle, NL text field with mic.
2. **Results** — list cards (icon per mode, time, VND, km, transfers, labels), map with all polylines, tap → detail.
3. **Trip detail** — legs timeline, cost breakdown, "Bắt đầu" button → driver mode.
4. **Driver mode** — full-screen map, maneuver banner, bottom bar (ETA, km, speed), report button, mute, end.
5. **Algorithm lab** — pick OD + algorithms, run, side-by-side explored-node animation, stats table, benchmark charts.
6. **Logistics** — add stops, vehicle, run optimizer, ordered stops + route, SA convergence chart.
7. **Settings** — language, theme, GPS sharing opt-in, simulator toggle, backend URL.
