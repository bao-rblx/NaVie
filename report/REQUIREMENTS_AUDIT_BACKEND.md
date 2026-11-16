# NaVie — Backend & Algorithm Requirements Audit

**Auditor:** backend-auditor (AI agent) · **Date:** 2026-11-15 (Asia/Saigon)
**Scope:** `backend/navie/**`, `backend/tests/**`, `scripts/**`, `Makefile`, `report/`, `data/`
**Baselines:** course PDF (text extracted to `report/course_pdf_text.txt`), `AGENTS.md`, `docs/00_brief.md`, `docs/01_requirements.md`, `docs/03_algorithms.md`, `docs/05_roadmap.md`, `docs/06_report_and_presentation.md`
**Method:** static read of every file in scope + live execution against the built HCMC graph (`data/build/hcmc.npz`, 138,322 nodes / 351,154 edges, version `hcmc-2026-11-01`) via `fastapi.testclient`.

Status key: **DONE** = implemented, wired, tested · **PARTIAL** = present but incomplete/mis-wired/untested · **MISSING** = no implementation · **UNVERIFIABLE** = cannot be checked here.

---

## 0. Headline numbers

| Metric | Value |
|---|---|
| Backend source files | 18 (`backend/navie/`), 1,070 statements |
| Backend tests | 43 tests in 8 files, **all pass** (91% coverage) |
| Search algorithms documented as graded | 10 (`docs/03_algorithms.md` §2 table) |
| Search algorithm modules actually implemented | **5** files (`astar.py`, `greedy.py`, `bidir.py`, `ida_star.py`, `ucs.py`) covering **6** named capabilities — `astar.py` supplies both A\* and Weighted A\* |
| FR-10 algorithms honestly reachable via the API | **3** fully (`ucs`, `astar`, `greedy`) + **1** partial (`weighted_astar`, w hard-coded to 1.5) |
| Algorithm labels the API accepts but executes as something else or not at all | **4**: `bidir_astar` → Bidir Dijkstra, `alt` → plain A\*, `dstar_lite` → plain A\*, `ida_star` → 404 `NO_PATH` at city scale |
| Missing backend packages (dir exists, empty, no `__init__.py`) | **5** (`api/`, `traffic/`, `nav/`, `logistics/`, `llm/`) |
| Missing roadmap scripts | **6** (`bench.py`, `plots.py`, `simulate_traffic.py`, `fit_bn.py`, `build_landmarks.py`, `seed_demo.py`) |
| HTTP endpoints live | **4** (`/health`, `/v1/route`, `/v1/plan`, `/v1/geocode`) of the **10** documented in `docs/02_architecture.md` §4 |

---

## 1. Graded search algorithms

`docs/01_requirements.md:29` FR-10 mandates a selector over: UCS, Greedy, A*, Weighted A*, Bidirectional Dijkstra, Bidirectional A*, IDA*, ALT.
`docs/03_algorithms.md:34-45` additionally lists Replan A* and D* Lite (C).

| Requirement | Status | Evidence | Gap |
|---|---|---|---|
| **UCS / Dijkstra** | DONE | `backend/navie/search/ucs.py:12-30` (delegates to `astar` with `heuristic=None` → h≡0, `astar.py:37`); API dispatch `backend/navie/planner/service.py:105-106`; oracle test `backend/tests/test_search.py:37-51`. Live: 32,424 expansions, 551.9 s on Bến Thành→Landmark 81. | None functionally. `ucs` is not its own implementation — it is A* with h=0. Defensible, but the essay must say so. |
| **Greedy best-first** | DONE | `backend/navie/search/greedy.py:13-60`; dispatch `service.py:107-108`. Verified suboptimal as designed: cost 1925.3 vs optimal 1796.6 (ratio 1.072) on `grid(8,8)`. Live: 146 expansions, cost 577.1 s vs 551.9 s optimal. | No test asserts the suboptimality claim T-06 requires (`docs/05_roadmap.md:47`). Only a path-existence assertion at `test_api_vertical.py:49`. |
| **A\*** | DONE | `backend/navie/search/astar.py:17-88` (heap + lazy deletion + closed set + tie-break on larger g); dispatch `service.py:116`. Tests: `test_search.py:37-51`, `76-80`, `93-99`. Live: 8,248 expansions / 8.7 ms vs UCS 32,424 / 38.5 ms. | None. |
| **Weighted A\*** | PARTIAL | Implemented via `astar(..., w=)` `astar.py:24,45,69`; dispatch at `service.py:109-110` **hard-codes `w=1.5`**. RouteRequest has no `w` field (`backend/navie/schemas.py:45-53`). | FR-10 compliance is nominal: the user cannot choose w. `docs/03_algorithms.md:39` specifies w ∈ {1.2,1.5,2,3}; only 1.5 is reachable. On the real graph w=1.5 happened to find the optimal cost (487.6 = C\*), so no demonstrable trade-off exists in the API. Test `test_search.py:117-123` does cover the w-bound. |
| **Bidirectional Dijkstra** | PARTIAL | `backend/navie/search/bidir.py:14-108`. Correct on 200 random OD pairs (0 cost mismatches vs UCS — my own script, not a repo test). Live: 7,992 expansions, 551.9 s. | **(a) Untested.** No repo test compares `bidir_dijkstra` cost to UCS; `test_api_vertical.py:50` only checks a 5-node line path exists. T-07 (`docs/05_roadmap.md:48`) requires "equal cost to UCS on all tests" — that test does not exist. **(b) Performance bug:** it calls `graph.build_reverse()` on every invocation (`bidir.py:25`), a full `argsort` over 351,154 edges = **25.4 ms of pure overhead**, even though `load()` already built it (`graph/core.py:193`). Live: 129.6 ms vs A* 84.0 ms — bidirectional is *slower* than A*. |
| **Bidirectional A\*** | **MISSING** | `service.py:111-112` maps `bidir_astar` into the **same** `bidir_dijkstra` call. No bidirectional A* exists; no Ikeda potentials, no `docs/03_algorithms.md:41` "consistent average potentials". | **This is a silent correctness bug, not just a gap.** `POST /v1/route {"algorithm":"bidir_astar"}` returns `stats.algorithm = "bidir_astar"` while executing Bidirectional Dijkstra. The API misreports which algorithm ran. Verified live: both return identical expansions (7,992). |
| **IDA\*** | PARTIAL | `backend/navie/search/ida_star.py:12-76` (recursive DFS, path-cycle check, 2M node budget). Correct on 200 random OD pairs vs UCS (0 mismatches — my script). | **It cannot solve a real city trip.** Live on HCMC: default budget → `nodes_expanded=2,000,001`, `cost=inf`, `path=[]` in 1.4 s; via the API this surfaces as **HTTP 404 `NO_PATH`**. A city-scale demo of IDA* is impossible. T-08 asks for "bounded iterations/time; documented as small-graph only" — the bound exists, the documentation is only a code comment (`ida_star.py:23`), and there is no test of the budget-exhaustion path or of any graph larger than a 5-node line. |
| **ALT** | **MISSING** | `docs/03_algorithms.md:43` and FR-10 require `alt.py` + landmark precompute. `backend/navie/search/alt.py` **does not exist**; `scripts/build_landmarks.py` **does not exist**; `data/build/*_alt_*.npz` absent. `service.py:115-116` `else` branch silently runs plain A*. Live: `algorithm=alt` returns `nodes_expanded=8248` — byte-identical to A*. | Silent substitution again. `docs/05_roadmap.md:50` marks T-09 as "(P2, C)" but FR-10 (`docs/01_requirements.md:29`) lists ALT in the **Must** selector, so this is a Must gap, not a Could gap. |
| **Replan A\*** | **MISSING** | `docs/03_algorithms.md:44`; `replan.py` absent. | Required by the graded "dynamic replanning" row in `docs/00_brief.md:30`. |
| **D\* Lite** | **MISSING** | `docs/03_algorithms.md:45` (C), `dstar_lite.py` absent. Schema still advertises `"dstar_lite"` (`schemas.py:20`); `service.py:115-116` runs plain A*. Live: `nodes_expanded=8248`, identical to A*. | Could-tier, but the API advertises it. Third silent substitution. |
| **Explored-node output (FR-11)** | DONE | `service.py:128-131` truncates to `debug.max_points`; `schemas.py:37` caps at 20,000. Verified: `max_points=3` → 3 points; `max_points=20000` on UCS (32,424 expansions) → exactly 20,000. Browser animation: `app/web_app/app.js:342-343`. | None. Sampling is a head-truncation, not a spatial sample — a fair-demo nuance, not a violation. |
| **SearchResult contract** | DONE | `backend/navie/search/base.py:18-26` matches `docs/03_algorithms.md:23-31` exactly (path/cost/nodes_expanded/runtime_ms/peak_memory_kb/explored). Memory via `tracemalloc` (`base.py:45-64`). API exposes `stats` (`schemas.py:77-82`). | None. |

### 1.1 Measured algorithm behaviour (HCMC, motorbike, Bến Thành → Landmark 81, 5.35 km)

| Algorithm label sent | Actually executed | Expansions | Path cost (s) | Runtime |
|---|---|---|---|---|
| `ucs` | UCS | 32,424 | 551.9 | 323.4 ms |
| `greedy` | Greedy | 146 | 577.1 | 1.1 ms |
| `astar` | A* | 8,248 | 551.9 | 84.0 ms |
| `weighted_astar` | A* with w=1.5 | 4,262 | 551.9 | 39.6 ms |
| `bidir_dijkstra` | Bidir Dijkstra | 7,992 | 551.9 | 129.6 ms |
| `bidir_astar` | **Bidir Dijkstra** | 7,992 | 551.9 | 129.2 ms |
| `ida_star` | IDA* | budget exhausted | **404 NO_PATH** | — |
| `alt` | **plain A\*** | 8,248 | 551.9 | — |
| `dstar_lite` | **plain A\*** | 8,248 | 551.9 | — |

**Verdict: 3 of the 8 FR-10 algorithms are honestly wired (UCS, Greedy, A\*), 1 is partial (Weighted A\* with a fixed w), 2 are silently substituted (Bidir A\*, ALT), 1 is broken at city scale (IDA\*), 1 is advertised but absent (D\* Lite).**

### 1.2 Algorithm selector wiring

| Requirement | Status | Evidence | Gap |
|---|---|---|---|
| FR-10 selector in the app | PARTIAL | Browser lab dropdowns `app/web_app/index.html:53` offer only **4** options: `astar`, `ucs`, `greedy`, `bidir_dijkstra`. Flutter has **no** lab screen at all — `app/lib/features/lab/` contains only `.gitkeep`. | Weighted A\*, IDA\*, Bidir A\*, ALT, D\* Lite are unreachable from either client. FR-10 says "user (or dev panel) chooses"; neither client can. T-24 not done. |
| FR-11 side-by-side heat layer | DONE (browser) | `app.js:324-343` runs A and B concurrently and animates 250-point chunks. `locales.mjs:264` "Show explored nodes". | Flutter lab missing (`app/lib/features/lab/.gitkeep`). |

---

## 2. Hard rule 1 — no library shortest-path / inference / optimization in production

**Verdict: COMPLIANT.** Grepped `backend/navie`, `scripts/`, `app/`, `app/web_app/` for `networkx|scipy|pgmpy|osrm|valhalla|ortools|sklearn|torch|igraph|pulp`.

| Finding | Status | Evidence |
|---|---|---|
| `networkx` in production | DONE (clean) | Only in `backend/tests/test_search.py:6,16-17,44,68-69` — exactly the oracle use `AGENTS.md:9` permits. Declared `networkx==3.4.2  # test oracle only` at `backend/pyproject.toml:28`, and only in the `dev` extra (line 23-30), so it is not a runtime dependency. |
| `pgmpy` / inference libs | DONE (clean) | Zero occurrences anywhere. (There is also no BN to infer with — see §3.) |
| `scipy` | **Judgement call** | `backend/navie/graph/snap.py:10` `from scipy.spatial import cKDTree` is production code, and `scipy==1.15.0` is a core runtime dep (`pyproject.toml:15`). This is a **nearest-neighbour spatial index**, not `scipy.optimize` — `AGENTS.md:9` names `scipy.optimize` specifically, and `docs/02_architecture.md:54,56` lists scipy in the stack. **I read this as compliant**, but a strict marker could object to scipy-in-production. Recorded for transparency. |
| `osmnx` | PASS (boundary respected) | Only `scripts/build_graph.py:27,36-38,60` — download/simplify only, and `backend/pyproject.toml:22` puts it in the optional `data` extra. `backend/navie/graph/build.py:3-4` explicitly documents that `navie/` is osmnx-free. Verified: no `import osmnx` under `backend/navie`. |
| OSRM / Valhalla / OR-Tools | DONE (clean) | Zero occurrences. |

---

## 3. Feature-by-feature: docs vs reality

| ID | Requirement | Status | Evidence | Gap |
|---|---|---|---|---|
| **FR-01** | Geocoder / search box | **PARTIAL** | `/v1/geocode` live (`backend/navie/main.py:118-135`), accent-insensitive + abbreviation expanding (`geocode/service.py:25-39`), rapidfuzz WRatio ranking + proximity bonus (`service.py:85-106`). My timing: **290–300 ms** per query over 25,801 places, index load 0.25 s — inside the 2 s AC. | **Index is roads-only.** I measured `kinds = {'road': 25801}` — **every single entry is a road; zero POIs; zero addresses.** `Chợ Bến Thành` returns `Hồ Thành Biên` (a road) as the top hit and **no entry in the whole index contains "ben thanh"** (0 matches). Reason: `make data` ran `build_geocode.py` in `--roads-only` mode or the Overpass download failed (`scripts/build_geocode.py:163-171`); the index was never rebuilt with POIs. **FR-01's literal AC ("search 'Chợ Bến Thành' returns a result inside HCMC") is not met** — it returns *a* result, but not the market. |
| **FR-02** | Compare modes | **PARTIAL** | `plan_trip` `planner/service.py:152-200`; live: walk/motorbike/car/taxi, each with distance_m, duration_s, cost_vnd, geometry, legs[], cost_breakdown. Walk >10 km suppression works (`service.py:162-163`; verified: 20.8 km plan dropped walk, explicit `modes_allowed=['walk']` kept it). | **`cost_vnd` is 0 for every mode.** `costs/engine.py:36-42` returns `CostEstimate(0, [("pricing_unverified", 0)], False, ...)` for everything except walk. Live response: `cost_vnd=0, estimate=true, cost_breakdown=[{"item":"pricing_unverified","vnd":0}]`. So the demo can show **no VND figures at all**, which kills the "cost comparison in VND" product promise (`docs/00_brief.md:23`) and FR-02's `cost_breakdown` AC is only structurally met. |
| **FR-03** | Optimize preference | **MISSING (server)** / DONE (client) | `TripQuery.optimize` is **parsed and ignored** — `planner/service.py:152-200` never reads it. Live: `optimize` = fastest/cheapest/balanced/fewest_transfers all return the identical body and identical labels `[('walk',['cheapest']),('car',['fastest'])]`. Client-side re-sorting exists and matches the AC: `app/web_app/navigation.mjs:60-65` `sortOptions`, wired at `app.js:360`. | The **AC** ("re-sorts client-side without a new request") is DONE. `fewest_transfers` is unimplementable (every option has 0 transfers). Server-side `optimize` is dead code — worth flagging so nobody claims it works. |
| **FR-04** | Departure time affects traffic | **MISSING** | `RouteRequest.depart_at` `schemas.py:51` and `TripQuery.depart_at` `schemas.py:123` are declared. Grep for `depart_at` in `backend/navie` returns **2 hits, both in `schemas.py`**. Nothing consumes it. Live: `/v1/plan` at `08:00` and `03:00` returns **identical** durations (walk 3369.6, motorbike 551.9, car 487.6, taxi 487.6). | **The AC is definitively failed.** Also, `duration_s` for the same mode differs between `weight=time` (551.9 s) and `weight=distance` (305.1 s) — see the bug in §3.1. |
| **FR-05** | Natural-language input | **MISSING** | `/v1/parse` unconditionally raises `NavieError("LLM_UNAVAILABLE", ...)` → 503 (`main.py:110-116`). `backend/navie/llm/` is an empty directory with no `__init__.py`. `/health` hard-codes `"llm_available": False` (`main.py:98`). | The **fallback** half of the AC is honestly DONE ("app works fully when the LLM is unavailable" — 503 + form). The parse half is entirely absent. Note: `TripQuery` (`schemas.py:120-131`) does match the `docs/02_architecture.md:96-107` LLM-output schema, so the contract is ready. |
| **FR-06** | Intercity multimodal | **MISSING** | `data/schedules/hubs.csv` is a **header only** (1 line, no rows). `trains.csv`, `flights.csv`, `coaches.csv`, `ferries.csv` **do not exist**. No `intercity`/`Pareto` code beyond the label list in `planner/service.py:198`. | Nothing to audit. `pareto_ids` is `[o.id for o in options]` — *every* id, i.e. **not a Pareto filter**, just the full list (`service.py:198`). |
| **FR-07** | AI summary | **PARTIAL** | `planner/service.py:199` returns `{"text_vi": f"Đã tìm thấy {len(options)} lựa chọn.", "source": "template"}`. | Template fallback exists and contains no invented numbers — good. But it says nothing about the options (no time/cost), so it is not "1–3 sentences explaining top options". No `llm/explain` (T-33). |
| **FR-12** | Benchmark runner → CSV + plots | **MISSING** | `Makefile:40-41`: `bench:
	@echo "bench: not implemented yet (T-10)"`. `scripts/bench.py` **does not exist**; `scripts/plots.py` **does not exist**; `report/results/` **does not exist**; `report/figures/` contains only `.gitkeep`. Grep for `matplotlib|pandas|to_csv|savefig|DataFrame` across `backend/` and `scripts/` → **0 hits**. `matplotlib` and `pandas` are **not installed** in either interpreter (`ModuleNotFoundError`) and are **not declared** in `backend/pyproject.toml`. No `/v1/bench/latest` endpoint (404). | **This is the single biggest grading gap.** `docs/06_report_and_presentation.md:27-34` lists **7 figures** that must come out of `make bench`. There is no code that produces any of them. |
| **FR-10** | Algorithm selector | PARTIAL | See §1.1/§1.2. | Silent substitutions; no `w` parameter; 5 of 10 unreachable. |
| **FR-11** | Explored-node visualisation | DONE | `service.py:128-131`, `schemas.py:37`, `app.js:324-343`. | Flutter lab missing. |
| **FR-20** | Time-dependent traffic (Bayesian Network) | **MISSING** | `backend/navie/traffic/` is an empty dir. `data/traffic/bn_structure.yaml` absent. `scripts/simulate_traffic.py`, `scripts/fit_bn.py` absent. Grep `traffic|bayes|congestion|variable_elimination` in `backend/navie` → **0 hits**. Edge cost is pure free-flow: `profiles.py:95-102` `length_m / speed_kmh`. | **The entire Category-3 depth contribution does not exist.** `docs/00_brief.md:9,31` and `docs/05_roadmap.md:62` (T-17) rank this as a graded deliverable. Its AC ("BN inference matches pgmpy within 1e-6") cannot even be attempted. |
| **FR-21** | Incident reports | **MISSING** | `IncidentRequest`/`Incident` pydantic models exist (`schemas.py:156-165`) but are **never imported** by anything. `POST /v1/incidents` and `GET /v1/incidents` → **404** (verified). No SQLite store, no TTL, no 50 m spatial index, no dedupe. | Schema-only. Models with no routes are worse than nothing for the audit — they make the OpenAPI look populated while the contract is unimplemented. |
| **FR-22** | Rerouting on obstacles | **MISSING (server)** / PARTIAL (client) | `POST /v1/nav/reroute` → **404** (verified). The AC "active routes crossing a new blocking incident get a 'Đường mới nhanh hơn X phút' prompt" cannot fire — there are no incidents to cross. Client off-route detection exists and is correct: `app/lib/features/driver/navigation_progress.dart:69` and `app/web_app/navigation.mjs:77` (3 consecutive >40 m fixes → reroute), re-calling `/v1/route` (`app.js:309`, `driver_screen.dart:172`). | This is *self*-rerouting on GPS deviation, **not** incident-driven rerouting, and it is not the documented `/v1/nav/reroute` endpoint. The "faster route" prompt does not exist in any form. |
| **FR-23** | Crowdsourced speeds | MISSING | (C-tier.) No code, no `gps_samples` table, `data/navie.db` doesn't exist. | — |
| **FR-30..34** | Driver mode (nav view, maneuvers, TTS, off-route, GPS sim) | PARTIAL | Maneuvers DONE: `planner/service.py:59-80` classifies by bearing with the exact thresholds `docs/01_requirements.md:52` demands (<20 straight, 20–45 slight, 45–135 turn, >135 sharp, >170 U-turn) in vi+en. Live: 17 maneuvers on a 5.35 km route. TTS thresholds DONE: `navigation.mjs:58` `[50,200,500]` car / `[50]` walk, matching `docs/01_requirements.md:54`. GPS simulator DONE (1–10×, `app.js:272-301`). | **`street` is `null` on every maneuver** (live check: 6/6 sampled `"street": null`) — the graph stores `name_id` and `names` (`graph/core.py:84-85`) but `_maneuvers` never looks them up (`service.py:75-77` passes no `street=`). So instructions read "Rẽ phải", not "Rẽ phải vào Lê Lợi" → **FR-31's literal AC is not met**. Also `distance_m` accumulates over the *whole* route rather than resetting per maneuver text ("Sau 200 m…") — minor. |
| **FR-35** | Mode-specific rules | **PARTIAL** | Motorbike bans motorway + `motorcycle=no`: `profiles.py:66-67`; walk ignores one-way and bans motorway+trunk: `profiles.py:62-64`; truck weight/height: `profiles.py:70-73`. Tests: `test_profiles.py:9-35`, `test_mode_routing.py:8-27`. Real graph: 22,575 oneway + 22,161 synthetic against-edges, 92 motorway, 27,692 footway, 3,152 motorcycle=no, 3,552 maxweight. | **Truck-ban windows (C) NOT implemented** — acknowledged in-line at `profiles.py:70` "Ban windows: TODO (C)". Walk excludes *all* trunk roads because there is no sidewalk data (`profiles.py:63-64`) — a documented deviation from `docs/03_algorithms.md:13`. |
| **FR-40** | Light cargo comparison | MISSING | `data/pricing/courier.yaml` does not exist. No courier code. | — |
| **FR-41** | Multi-stop SA vs HC | **MISSING** | `backend/navie/logistics/` empty. No SA/HC/TSP code anywhere. Grep `anneal|simulated|hill_climb|tsp|vrp` across `backend` → **0 hits**. `POST /v1/logistics/optimize` → **404**. | **Second graded contribution absent.** `docs/03_algorithms.md:83-87` (SA/HC/NN/brute, 2-opt, geometric cooling) and `docs/06_report_and_presentation.md:33` figure 6 both depend on it. |
| **FR-42/43** | Fleet VRP, heavy truck | MISSING | (C-tier.) | Truck weight/height limits do partially exist (see FR-35). |
| **NFR-01** | A\* < 1 s for ≤20 km; graph load < 10 s | DONE | Live: 19.3 km car trip, A* distance-weight = **48.9 ms** / 35,383 expansions; time-weight 133.5 ms / 86,109 expansions. Graph load: **0.15 s** for 138k nodes (4.9 MB npz). | Comfortably inside. Worth putting these numbers in the essay. |
| **NFR-02** | Navigation never depends on the LLM | DONE | `/v1/route` and `/v1/plan` import nothing from `llm/` (which is empty). `/v1/parse` fails closed with 503 (`main.py:110-116`). | None. |
| **NFR-03** | $0; no paid keys | DONE | No API keys; `.env.example:6` `GEMINI_API_KEY=` empty; `.gitignore:14` ignores `.env`. Tiles are raw OSM (`app.js:83`) — free. | `AGENTS.md:12` says "no internet except map tiles", but `geocode/service.py:130-183` calls **Photon/komoot over the network** at request time. It fails open (`return []`) and is bounded to 1.05 s spacing, but it *is* a live network dependency in the nav path. Flag for the essay. |
| **NFR-04** | Prices flagged unverified | DONE | `estimate: bool = True` in `schemas.py:100`; set from `not estimate.verified` (`planner/service.py:148`); `data_version.pricing = "TODO-verify"` (live). | Exemplary honesty. It is also *why* every cost is 0 — the data was never verified. |
| **NFR-06/07** | vi/en + accessibility | PARTIAL | ARB files `app/lib/l10n/app_vi.arb`/`app_en.arb`, 8 tooltips in Flutter. | No `Semantics`/`semanticLabel` widgets anywhere; tooltips are not screen-reader labels. Contrast targets unclaimed. Cannot verify 48 dp without a device run. |
| **NFR-08** | Coverage ≥ 80% for `search`, `traffic`, `logistics` | **PARTIAL** | Measured: `search/` is **excellent** — astar 100%, base 100%, heuristics 100%, ucs 100%, profiles 99%, ida_star 98%, greedy 97%, bidir 92%. Total 91%. | `traffic/` and `logistics/` **do not exist** (0% by definition). Also no `fail_under` gate in `pyproject.toml:47-49`, so coverage can silently regress. |
| **NFR-10** | `make setup && make data && make run` on a clean machine | **UNVERIFIABLE** | `make` is **not installed** on this machine (`NO_MAKE`), so the targets have never run as written. `make data` (`Makefile:20-22`) does **not** run traffic simulation or BN fitting, despite `AGENTS.md:31` promising "download OSM, build graphs, simulate traffic, fit BN". | Also: `pyproject.toml` has **no `pyyaml`, `pandas`, or `matplotlib`** although `docs/02_architecture.md:58` lists pandas+matplotlib for benchmarks/figures and `docs/04` requires YAML/CSV parsing. `make setup` as written cannot produce a machine that can run T-10 even once it is written. |

### 3.1 Three live defects found while auditing

All three are observable in shipped API responses or in measured runtime.

1. **`weight="distance"` reports a fabricated duration.** `planner/service.py:123-125`:
   ```python
   duration = (result["cost"] if request.weight == "time"
               else distance / max(prof.max_speed_mps(g), 0.1))
   ```
   For a distance-weighted route it divides the whole distance by the single **fastest** speed in the profile. Measured on Bến Thành→Landmark 81 motorbike: distance-optimal path = 5,339.2 m, **real** time-weight cost of that same path = **553.3 s**, but the API reports **305.1 s** (5,339.2 / 17.5 m·s⁻¹). It is **45% too fast** and it is presented as a normal `duration_s` with no flag. Fix: sum the time-cost array over the chosen edges.

2. **Bidirectional search rebuilds the reverse CSR on every call.** `bidir.py:25` `graph.build_reverse()` with no "already built?" guard. `graph/core.py:126-135` re-does a full `argsort` of 351,154 edges. Measured: **25.4 ms per call**, on a total bidir runtime of ~129 ms. `load()` already built it (`core.py:193`), and `build_graph()` already built it (`build.py:181`). Guard with `if self.rev_indptr is None`.

3. **Every API request pays a 5.3x `tracemalloc` tax for a stat nobody reads.** `planner/service.py:104` hard-codes `kwargs = {"track_memory": True, ...}`, so `Meter` starts `tracemalloc` on every route (`base.py:52-64`). Measured on the same A* query: `track_memory=False` -> **14.6 ms**, `track_memory=True` -> **77.8 ms**. NFR-01 still passes (77 ms << 1 s), but the benchmark harness (once written) must enable `track_memory` only for the memory measurement, or every runtime number will be inflated ~5x.

---

## 4. Tests — do they actually pass?

**Yes. 43 passed, 0 failed, 91% coverage.**

```
$ backend\.venv\Scripts\python.exe -m pytest -q
...
navie\search\ucs.py              7      0   100%
TOTAL                          1070     94    91%

43 passed, 1 warning in 2.08s
```

Verification notes:
- **Both interpreters pass today.** The venv run failed on my *first* attempt with `ModuleNotFoundError: No module named 'rapidfuzz'` (3 collection errors, 23% coverage); `rapidfuzz` and `Unidecode` were then installed into `.venv` (site-packages mtime 2026-11-15 12:41) and both interpreters now report 43 passed / 91%. **Whoever set up this repo left the venv incomplete**; `make setup` had not been re-run after `rapidfuzz`/`Unidecode` were added to `pyproject.toml:16-17`. `make setup` would have fixed it — but `make` is not installed (`Makefile:2` assumes Git Bash + GnuWin32 Make). This is a real reproducibility risk for the 22/11 submission.
- 1 warning: `starlette` deprecation (`anyio.abc.BlockingPortal`), pre-existing upstream.
- `make lint` equivalent: **ruff 0.8.6 clean** ("All checks passed!", "39 files already formatted"), **mypy 1.14.1 clean** ("Success: no issues found in 25 source files").
- `node --test app/web_app/tests/*.test.mjs` → **9 passed**.
- `flutter test` → **7 passed**.

### 4.1 Test quality — what the 43 tests do *not* cover

| Gap | Evidence |
|---|---|
| **No bidirectional correctness test** | `test_api_vertical.py:50` asserts a path exists on a 5-node line. T-07 (`docs/05_roadmap.md:48`) demands "equal cost to UCS on all tests" — **that assertion is nowhere**. I verified it myself on 200 random graphs (0 mismatches) so the code is probably right; the *test suite* doesn't prove it. |
| **No IDA\* budget/no-path test** | `test_api_vertical.py:51` checks a 5-node line only. Nothing covers budget exhaustion, nothing covers a city graph, nothing asserts the `NO_PATH` behaviour. |
| **No Greedy suboptimality test** | T-06 (`docs/05_roadmap.md:47`) requires "tests show Greedy may be suboptimal". No such test. |
| **No Bidir A\* / ALT / D\* Lite test** | They have no implementations and no tests — but the schema accepts all three, and **no test asserts that requesting them is rejected**. A test asserting `algorithm="alt"` returns 422 would today fail, which is the honest signal. |
| **No 200-random-OD-pair city test** | `docs/03_algorithms.md:54` and T-05 (`docs/05_roadmap.md:46`) require it. `test_search.py:54-73` uses `graphs.grid(3..8)` fixtures only — max 64 nodes. The real 138k-node graph is never exercised by any test. |
| **No property tests** | `docs/03_algorithms.md:57` requires hypothesis property tests. `hypothesis` is not installed and not declared. |
| **No cost-engine formula test** | T-13 (`docs/05_roadmap.md:56`) requires "unit tests per formula with hand-computed values". `costs/engine.py` is 91% covered but the only behaviour is "return 0, unverified" — there is no formula to test. |
| **No incident / BN / logistics test** | Nothing to test. |
| **Coverage gate absent** | `pyproject.toml:47-49` has `--cov` but no `--cov-fail-under`. NFR-08 is unenforced. |

---

## 5. Essay & presentation obligations (course PDF)

Source of truth: `report/course_pdf_text.txt`. Requirements are on lines 18-32, deadlines on lines 8-12.

| Obligation (PDF line) | Status | Evidence | Gap |
|---|---|---|---|
| Written essay, 10 pages, double-spaced, **+ cover page** with title, members, student IDs (`course_pdf_text.txt:20-22`) | **MISSING** | `report/` contains exactly: `ai_usage_log.md`, `T-25_validation.md`, `figures/.gitkeep`, `ui/planner.png`, `ui/driver-mobile.png`. `docs/06_report_and_presentation.md` is a **50-line outline**, not a draft. Glob for `*.tex|*.docx|*.pptx|*.odt` outside `.venv` → **zero hits** (the only PDF is the course brief itself). | **No essay exists in any form — not even a skeleton.** Zero words written against a 2,500–3,000-word budget. |
| Must contain Introduction / Discussion / Conclusion (`:24-26`) | **MISSING** | `docs/06_report_and_presentation.md:8-18` is a **page-budget table** (7 sections, owners, page counts) with no prose. | Outline only. The PDF says the essay "must include" these; an outline is not an essay. |
| Proofs sketched with citations if too long (`:28-30`) | **PARTIAL** | `docs/06_report_and_presentation.md:17` lists the right citations (Hart 1968, Korf 1985, Goldberg & Harrelson 2005, Koenig & Likhachev 2002, Kirkpatrick 1983, Pearl 1988, R&N 4th, OSM). Admissibility/consistency reasoning exists in code comments: `search/heuristics.py:1-8`, `graph/build.py:103-105`. | Navigation is right; **no written proof sketch and no bibliography** exist. |
| 15-minute oral presentation (`:32`) | **MISSING** | `docs/06_report_and_presentation.md:48-57` has a minute-by-minute run sheet. No slide deck anywhere (`*.pptx`/Google Slides export: zero hits). | Run sheet ≠ deck. |
| **Submission 22/11/2026** (`:12`) | **AT RISK** | Today is 2026-11-15 — **7 days out**. Also `19/11/2026` oral (**4 days**), `12/11/2026` code freeze (**already passed, 3 days ago**). | See §6. |
| AI-use disclosure (`report/ai_usage_log.md` per `AGENTS.md:37-38`) | DONE | `report/ai_usage_log.md:7-16` logs T-01..T-05, T-15, BUILD, RUN; `:20` discloses that all commits were AI-generated and that placeholder author names are used; `:22-26` logs T-25. | Honestly and unusually well kept — this is the strongest compliance artifact in the repo. **But it stops at T-25**; no entry for anything after 2026-11-02, and none of the graded algorithms (T-06..T-10, T-17, T-28) are logged. |
| Deliverable figures for the essay (`docs/06_report_and_presentation.md:27-34`, 7 figures) | **MISSING** | `report/figures/` = `.gitkeep` only. FR-12 bench harness absent. | **All 7 figures are blocked on FR-12.** Figures 2–7 additionally depend on BN (FR-20) and SA/HC (FR-41), which don't exist. |

---

## 6. Consolidated requirement table

| ID | Requirement | Status |
|---|---|---|
| FR-01 | Geocoder search box | PARTIAL (roads-only index; no POIs/addresses) |
| FR-02 | Compare modes with VND | PARTIAL (4 modes work; cost_vnd always 0) |
| FR-03 | Optimize preference | DONE on client / server ignores `optimize` |
| FR-04 | Departure time → traffic | **MISSING** |
| FR-05 | Natural-language input | **MISSING** (503 fallback only) |
| FR-06 | Intercity multimodal + Pareto | **MISSING** |
| FR-07 | AI summary | PARTIAL (template, no content) |
| FR-10 | Algorithm selector (8 algorithms) | PARTIAL (3 honest, 1 fixed-w, 2 substituted, 1 broken, 1 absent) |
| FR-11 | Explored-node visualisation | DONE (browser) / MISSING (Flutter) |
| FR-12 | Benchmark runner → CSV + plots | **MISSING** |
| FR-20 | Bayesian Network traffic | **MISSING** |
| FR-21 | Incident reports | **MISSING** (models only) |
| FR-22 | Incident rerouting | **MISSING** (client self-reroute only) |
| FR-23 | Crowdsourced speeds (C) | MISSING |
| FR-30–34 | Driver mode | PARTIAL (maneuvers/TTS/off-route/sim work; street names null) |
| FR-35 | Mode rules | PARTIAL (moto/walk/car/truck limits done; truck-ban windows TODO) |
| FR-36/37 | Night theme, voice commands | PARTIAL (night theme in web) / MISSING |
| FR-40 | Cargo comparison | MISSING |
| FR-41 | SA vs HC multi-stop | **MISSING** |
| FR-42/43 | Fleet VRP, heavy truck (C) | MISSING / PARTIAL |
| NFR-01 | A\* < 1 s @20 km; load < 10 s | DONE (48.9 ms / 0.15 s) |
| NFR-02 | LLM-independent navigation | DONE |
| NFR-03 | $0, no paid keys | DONE (note: Photon network call in geocoder) |
| NFR-04 | Unverified prices flagged | DONE |
| NFR-05 | GPS privacy | MISSING (no gps_samples store) |
| NFR-06/07 | vi/en, accessibility | PARTIAL |
| NFR-08 | Coverage ≥ 80% search/traffic/logistics | PARTIAL (search excellent; other two absent; no gate) |
| NFR-09 | OSM attribution, island labelling | PARTIAL (attribution DONE everywhere; no custom island label layer exists to check) |
| NFR-10 | Reproducible `make setup && data && run` | UNVERIFIABLE (make not installed; venv was incomplete; no BN/traffic step in `data`) |

### Status tally

Row-level distribution over the 29 requirement rows in the table above (rows that mix two states, e.g. FR-11 "DONE (browser) / MISSING (Flutter)", are counted by their primary backend status — the prose column records the split):

| Status | Count |
|---|---|
| DONE | 6 (FR-03, FR-11, NFR-01..04) |
| PARTIAL | 10 (FR-01, FR-02, FR-07, FR-10, FR-30–34, FR-35, FR-36/37, NFR-06/07, NFR-08, NFR-09) |
| MISSING | 12 (FR-04, FR-05, FR-06, FR-12, FR-20, FR-21, FR-22, FR-23, FR-40, FR-41, FR-42/43, NFR-05) |
| UNVERIFIABLE | 1 (NFR-10) |
| **Total requirement rows** | **29** |

Separately, 8 of the 10 search-algorithm rows in §1 are graded items; see §1.1 for their individual verdicts (3 honest, 1 partial, 2 substituted, 1 broken, 1 absent).

---

## 7. Top gaps, ranked by grading risk

1. **FR-12 benchmark harness does not exist** — `Makefile:41` literally prints "not implemented yet". No `scripts/bench.py`, no `scripts/plots.py`, no `report/results/`, no matplotlib/pandas installed or declared, `report/figures/` empty. This blocks **all 7 essay figures** and with them the "Experiments & discussion" section that `docs/06_report_and_presentation.md:15` budgets **2.5 of 10 pages** for.
2. **The whole graded AI contribution beyond search is absent.** `navie/traffic/` and `navie/logistics/` are empty directories. No BN (FR-20, no pgmpy oracle test possible), no incidents (FR-21/22), no SA/HC (FR-41). `docs/00_brief.md:9-10` sells these as the depth that distinguishes the project; `docs/03_algorithms.md:59` calls the BN "Category 3 depth".
3. **Two of eight FR-10 algorithms are silently faked.** `bidir_astar` → Bidir Dijkstra and `alt` → plain A* (`service.py:111-116`), while `stats.algorithm` echoes the *requested* label (`service.py:140`). Live proof: `alt` and `astar` are indistinguishable (8,248 expansions both). Also `dstar_lite` → plain A*. This is the kind of thing a demo-day question exposes in 10 seconds.
4. **FR-04 and FR-02's headline number fail.** `depart_at` is parsed and dropped — 08:00 and 03:00 give byte-identical durations. `cost_vnd` is 0 for every motorised mode because the pricing files were never verified, so no VND comparison can be shown. Plus the distance-weight duration bug reports 305.1 s where the truth is 553.3 s.
5. **No essay, no slides, and the code freeze has passed.** `report/` has no draft; glob for tex/docx/pptx returns nothing; `docs/06` is a 50-line outline. Code freeze was 12/11 (3 days ago), oral is 19/11 (4 days), submission 22/11 (7 days).

Honourable mentions: **IDA\* cannot route a real trip** (404 NO_PATH at 2M nodes) so the IDA\* "finding" the essay wants is unproducible through the API; **bidirectional search is slower than A\*** because it rebuilds the reverse CSR every call (25.4 ms of 129 ms); **geocoder index contains 25,801 roads and zero POIs**, so "Chợ Bến Thành" returns a road called Hồ Thành Biên; **maneuvers never carry street names** (`"street": null`) so FR-31's "rẽ phải vào đường Lê Lợi" is unmet; **`pareto_ids` is the full option list**, not a Pareto filter (`service.py:198`).

---

## 8. What is genuinely solid (so fixes do not break it)

- **Search core quality is high.** A\* (`astar.py`) is a textbook-clean heap + lazy-deletion + closed-set implementation with correct tie-breaking; heuristics are provably admissible *and* consistent (`heuristics.py:1-8`) and I confirmed **0 consistency violations** on a 351k-edge sample of the real graph. `build_graph` clamps length to the straight-line distance (`build.py:139`) precisely to keep haversine admissible — a subtle bug avoided on purpose.
- **Measured performance is well within NFR-01**: 48.9 ms for a 19.3 km A\* search; 0.15 s to load a 138k-node graph.
- **The deliberate "return 0, mark unverified" cost policy** (`costs/engine.py:36-42`) is the right call under `AGENTS.md:10` ("never invent data"). It must be *fixed by filling real prices*, not by deleting the guard.
- **Honesty artifacts are unusually good**: `report/T-25_validation.md:57-59` and `report/ai_usage_log.md` state plainly what is not done, and `estimate: true` is on every response.
- **Admissibility/consistency reasoning, mode-rule tests, snapping, and the graph layer are solid and well tested** — do not touch them.
