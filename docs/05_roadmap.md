# NaVie — Roadmap, Roles & Agent Task Cards

## 1. Roles
| Person | Owns | Reviews |
|---|---|---|
| P1 — Data & AI | pricing/schedule data, traffic simulation, Bayesian Network, LLM module | P2's cost code |
| P2 — Backend & algorithms | graph build, `search/`, planner, nav, API | P1's BN code |
| P3 — App | Flutter: planner, results, driver mode, lab, logistics screens | P4's simulator |
| P4 — QA, infra, logistics | Makefile/CI, benchmarks, GPS simulator, `logistics/` (SA/HC), test drives | P3's app PRs |
Everyone: writes their own essay section and presents their part. Every agent PR needs one human approval.

## 2. Weekly plan (code freeze 12/11/2026)
| Week | Dates | Goal | Exit check |
|---|---|---|---|
| 0 | now → 10/09 | Team + topic submitted, lecturer questions asked (brief §8), repo + CI created | `make test` green on empty project |
| 1 | 14/09 – 20/09 | Graph pipeline HCMC, CSR graph, mode profiles, UCS + A* | A* matches networkx on 100 OD pairs |
| 2 | 21/09 – 27/09 | Greedy, Weighted A*, Bidirectional, IDA*; `/v1/route`; Flutter map + route line | App draws a route from tap A → tap B |
| 3 | 28/09 – 04/10 | **Proposal 02/10**: slides from §06; benchmark runner v1; explored-node layer | Live demo: Dijkstra vs A* exploration |
| 4 | 05/10 – 11/10 | Costs (fuel, taxi, parking), `/v1/plan` mode comparison, results screen, geocoder | Search "Chợ Bến Thành" → "Landmark 81" shows 4 modes with VND |
| 5 | 12/10 – 18/10 | Traffic simulation + BN (own inference, pgmpy oracle) → time-dependent weights | 08:00 vs 03:00 car ETA differs |
| 6 | 19/10 – 25/10 | Driver mode: nav view, maneuvers, Vietnamese TTS, GPS simulator, off-route reroute | Simulated drive with injected detour reroutes < 1.5 s |
| 7 | 26/10 – 01/11 | Incidents (dynamic obstacles) + replanning, WS session; ALT landmarks; LLM parse | Report flood on route → "Đường mới nhanh hơn" prompt |
| 8 | 02/11 – 08/11 | Logistics SA/HC, intercity hub graph + Pareto, LLM explain; full benchmarks + plots | All Must ACs pass; figures for essay exported |
| 9 | 09/11 – 12/11 | **Code freeze 12/11**: bug fixes only, demo rehearsal video recorded as backup | Clean-machine `make setup && make data && make run` |
| 10 | 13/11 – 19/11 | Essay final, slides, rehearse 15 min ×3; **oral 19/11** | — |
| 11 | 20/11 – 22/11 | **Submit 22/11**: essay PDF + code zip/repo link | — |
Could-items (D* Lite, fleet VRP, heavy truck, crowdsourced GPS, voice commands, Hanoi graph) only after the week's exit check passes.

## 3. How to use the AI agent
1. Give one task card at a time (below). Paste the card ID, e.g. "Do T-05 per docs".
2. Agent reads `AGENTS.md` + the referenced docs, writes code **and tests**, runs `make test`, opens a PR.
3. Owner reviews: algorithm correctness, no invented data, tests meaningful. Then merge.
4. If the agent fails twice on a card, split the card smaller.
5. Log every card in `report/ai_usage_log.md` (date, card, what the agent did, what humans changed) — needed for AI-use disclosure in the essay.

## 4. Task cards
Format: **ID — title** (owner) · depends on · refs · done when.

### Foundation
- **T-01 — Repo skeleton** (P4) · — · 02 §2–3 · `Makefile` targets `setup data run test bench lint`; `backend/pyproject.toml` pinned; Flutter app created in `app/`; GitHub Actions runs ruff + pytest + flutter analyze/test.
- **T-02 — Graph build** (P2) · T-01 · 03 §1, 04 §2 · `scripts/build_graph.py --city hcmc` produces CSR `.npz` with edge flags; loader `navie.graph.load(city)` < 10 s; tests on a 10-node fixture.
- **T-03 — Mode profiles** (P2) · T-02 · 03 §1, 01 FR-35 · per-mode edge filters + speeds; tests: motorbike never on motorway, walk ignores one-way.
- **T-04 — Snapping** (P2) · T-02 · 03 §1 · lat/lon → nearest allowed edge per mode (KD-tree); `OUT_OF_COVERAGE` error outside bbox.

### Search (graded core)
- **T-05 — UCS + A*** (P2) · T-03 · 03 §2 · common `SearchResult` with stats; tests vs networkx on fixtures + 100 random city OD; A* expands ≤ UCS.
- **T-06 — Greedy + Weighted A*** (P2) · T-05 · 03 §2 · tests show Greedy may be suboptimal, WA* cost ≤ w × optimal.
- **T-07 — Bidirectional Dijkstra + A*** (P2) · T-05 · 03 §2 · correct stopping criterion; equal cost to UCS on all tests.
- **T-08 — IDA*** (P2) · T-05 · 03 §2 · bounded iterations/time; documented as small-graph only.
- **T-09 — ALT** (P2, C) · T-05 · 03 §2 · landmark precompute script; fewer expansions than A* on benchmark.
- **T-10 — Benchmark runner** (P4) · T-05..T-08 · 03 §6, 01 FR-12 · `make bench` → CSV + plots in `report/figures/`.
- **T-11 — Explored-node output** (P2) · T-05 · 01 FR-11 · sampled ≤ 20k points in response when `debug.return_explored`.

### API & planner
- **T-12 — `/v1/route`, `/health`, error model** (P2) · T-04, T-05 · 02 §4 · pydantic schemas; API tests.
- **T-13 — Cost engine** (P1) · T-01 · 04 §3–4 · loads YAML/CSV, formulas per mode, breakdown, `last_updated`; unit tests per formula with hand-computed values.
- **T-14 — `/v1/plan` mode comparison** (P2) · T-12, T-13 · 01 FR-02/03 · options for walk/moto/car/taxi, labels fastest/cheapest/balanced.
- **T-15 — Geocoder** (P1) · T-02 · 04 §6 · `/v1/geocode`; tests: accent-less and abbreviated queries find the right place.

### Traffic
- **T-16 — Traffic simulator** (P1) · T-02 · 04 §2 · reproducible CSV from `sim_config.yaml`.
- **T-17 — Bayesian Network** (P1) · T-16 · 03 §3 · MLE + Laplace fit, own variable elimination; matches pgmpy within 1e-6.
- **T-18 — Time-dependent weights** (P2) · T-17 · 03 §3 · edge time = f(BN, depart_at); cache per bucket; FR-04 AC passes.
- **T-19 — Incidents + replanning** (P2) · T-18 · 01 FR-21/22, 03 §4 · SQLite store, TTL, merge, edges blocked/slowed, replan from current node.
- **T-20 — D* Lite** (P2, C) · T-19 · 03 §4 · same path cost as full replan, fewer expansions.

### Navigation
- **T-21 — Maneuvers + Vietnamese text** (P2) · T-12 · 01 FR-31 · bearing classification, street names, roundabouts; snapshot tests.
- **T-22 — Reroute + WS session** (P2) · T-19, T-21 · 01 FR-33, 02 §4 · `/v1/nav/reroute` < 1.5 s; WS pushes `incident_ahead` / `faster_route`.

### App
- **T-23 — Map + planner screens** (P3) · T-12 · 02 §6 · OpenFreeMap style, tap pins, search box, mode chips, results cards.
- **T-24 — Algorithm lab screen** (P3) · T-11 · 01 FR-10/11 · side-by-side explored animation + stats table.
- **T-25 — Driver mode UI** (P3) · T-21 · 01 FR-30..36 · heading-up camera, banner, ETA bar, TTS vi-VN at 500/200/50 m, report button, night theme.
- **T-26 — GPS simulator** (P4) · T-25 · 01 FR-34 · replay route/GPX at 1–10× speed with injected detour.
- **T-27 — i18n + accessibility** (P3) · T-23 · NFR-06/07 · vi/en ARB files, semantics labels, 48 dp targets.

### Logistics & intercity
- **T-28 — TSP: NN, brute, HC, SA** (P4) · T-05 · 03 §5 · `/v1/logistics/optimize`; FR-41 AC; convergence data.
- **T-29 — Logistics screen** (P3) · T-28 · 02 §6 · stops list, ordered route, convergence chart.
- **T-30 — Intercity hub graph + Pareto** (P2) · T-14 · 03 §5, 04 §5 · time-dependent search over schedules; no dominated option returned.
- **T-31 — Schedule & courier data entry** (P1) · — · 04 §3, §5 · CSV/YAML filled by humans with sources.

### LLM
- **T-32 — `/v1/parse`** (P1) · T-14 · 02 §4–5, 01 FR-05 · provider interface (Gemini / Ollama / none), JSON schema validation, cache, 503 fallback; tests with a fake provider.
- **T-33 — `llm/explain`** (P1) · T-32 · 01 FR-07, 02 §5 · number-check guard → template fallback.

### Delivery
- **T-34 — Demo script & backup video** (P4) · all Must · 06 §3 · scripted OD pairs, seeded incidents, recorded run.
