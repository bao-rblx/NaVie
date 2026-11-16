# 07 · Work plan — 4 people, 7 waves, 28 packs

Companion to `05_roadmap.md` (task cards) and `01_requirements.md` (acceptance criteria).
Written 2026-11-15. Target: code freeze 21/11, submission 22/11, oral 19/11.

**One pack = one branch = one PR = one task card.** 7 waves x 4 people = **28 packs**.
Every wave is a day: W1 = 15/11 … W7 = 21/11.

---

## 1. Roles

Keeps the roster in `05_roadmap.md` §1 (P1–P4) and matches what each person already owns in git history.

| Person | Role | Owns (write scope) | Reviews | Also responsible for |
|---|---|---|---|---|
| **Luu Gia Bao** | **P2 — Backend & Algorithms** | `backend/navie/search/`, `graph/`, `planner/`, `schemas.py`, `errors.py`, `main.py` | Quang Minh | Essay §2 (formulation), §3 (algorithms) |
| **Tran Quang Minh** | **P1 — Data & AI** | `backend/navie/traffic/`, `geocode/`, `costs/`, `llm/`, `data/`, `scripts/build_*` | Bao | Essay §4 (Bayesian network) |
| **Nguyen Trung Duc** | **P3 — App** | `app/lib/`, `app/web_app/`, `app/test/`, `app/web/` | Minh Nguyen | Essay §1 (introduction), §7 (conclusion); the live demo |
| **Nguyen Vo Minh Nguyen** | **P4 — QA, Infra, Bench & Logistics** | `Makefile`, `backend/pyproject.toml`, `.github/`, `scripts/bench*`, `scripts/plots.py`, `backend/navie/logistics/`, `report/` | Duc | Essay §5 (local search), §6 (experiments); final assembly + formatting |

Review pairing is fixed: **Bao <- Quang Minh**, **Quang Minh <- Bao**, **Duc <- Minh Nguyen**, **Minh Nguyen <- Duc**.
Two people share the name *Minh*, so spell them out: **Quang Minh** and **Minh Nguyen**.

---

## 2. How a pack works

1. Branch `feat/T-XX-short-name` off `main` (or off the previous pack in the same wave if stacked).
2. Commit messages: `T-XX: short summary` (AGENTS.md).
3. The pack must leave the tree green: `make lint && make test` — or, while `make` is still missing on this machine, the four direct commands listed in `app/README.md`.
4. Paste the command output summary into the PR description.
5. Append one row to `report/ai_usage_log.md` (date, card, what was generated, open issues) — needed for the AI-use disclosure.
6. **Write the essay paragraph for your own pack while the code is fresh**, into `report/essay/<section>.md`. Do not leave the essay to W7.
7. One reviewer approves. The reviewer checks: acceptance criteria, no invented data (`verified: false` + `TODO(source)` when unverified), and that the tests actually test something.

**Wave gate.** A wave is done only when all four PRs are merged, `main` is green, and the wave's exit check (below) was demonstrated. Never start the next wave with a red `main`.

**Stacking rule.** Inside a wave, merge in the listed order (backend → data/AI → app → QA/infra) so each PR is green when it lands. Later waves may modify files earlier waves created.

---

## 3. Wave calendar

| Wave | Date | Theme | Exit check |
|---|---|---|---|
| W1 | 15/11 | Land what is already written: contracts, costs, geocoder, browser shell, environment | `make lint && make test` green from a clean checkout; browser shell renders |
| W2 | 16/11 | Route + plan end-to-end; algorithms stop lying; pricing becomes real | Search a place, get 4 modes with VND, same route from both clients |
| W3 | 17/11 | Flutter parity + first benchmark figures | Flutter draws the same route; `report/figures/E1..E4.png` exist |
| W4 | 18/11 | Local search exists (the PDF bullet); Bayesian network fitted | `/v1/logistics/optimize` orders 30 stops; BN matches pgmpy within 1e-6 |
| W5 | 19/11 | Traffic reaches the route; logistics reaches the UI — **oral presentation** | 08:00 vs 03:00 gives different ETAs |
| W6 | 20/11 | Dynamic obstacles: an incident provokes a reroute | Report a flood on the route → "Đường mới nhanh hơn X phút" |
| W7 | 21/11 | Freeze, document, submit | Clean-machine rehearsal passes; essay + deck + zip ready |

---

## 4. The 28 packs

**Files** = exact paths to `git add`. (new) = does not exist yet. **(m)** = modifies a file from an earlier pack.

### W1 — Foundation lands (15/11)

| Pack | Owner | Card / PR title | Files | Depends | Verify |
|---|---|---|---|---|---|
| **W1.1** | Minh Nguyen | `T-01b: reproducible environment, CI gates and audit evidence` | `.gitignore`, `Makefile`, `backend/pyproject.toml`, `app/pubspec.yaml`, `app/.gitignore`, `app/.metadata`, `app/analysis_options.yaml`, `app/README.md`, `report/ai_usage_log.md`, `report/T-25_validation.md`, `report/REQUIREMENTS_AUDIT_BACKEND.md`, `report/REQUIREMENTS_AUDIT_APP.md`, `report/PROJECT_STATUS_2026-11-15.md`, `report/course_pdf_text.txt` | — | `make lint && make test` |
| **W1.2** | Quang Minh | `T-13/T-15: cost engine, geocoder and place-index builder` | `backend/navie/costs/__init__.py`, `backend/navie/costs/engine.py`, `backend/navie/geocode/__init__.py`, `backend/navie/geocode/service.py`, `scripts/build_geocode.py`, `backend/tests/test_geocode.py`, `docs/04_data_and_costs.md` | — | `pytest -q`; `/v1/geocode?q=ben+thanh` returns a place |
| **W1.3** | Bao | `T-12/T-14: pydantic contracts, /v1/route and /v1/plan` | `backend/navie/schemas.py`, `backend/navie/errors.py`, `backend/navie/main.py`, `backend/navie/planner/__init__.py`, `backend/navie/planner/service.py`, `backend/navie/search/__init__.py`, `backend/navie/search/greedy.py`, `backend/navie/search/ida_star.py`, `backend/navie/search/bidir.py`, `backend/tests/test_api_vertical.py`, `docs/02_architecture.md` | W1.2 | `pytest -q`; `POST /v1/route` Bến Thành → Landmark 81 |
| **W1.4** | Duc | `T-23a: browser shell, icons and bilingual copy pipeline` | `app/web_app/index.html`, `app/web_app/styles.css`, `app/web_app/icons.mjs`, `app/web_app/locales.mjs`, `app/web/favicon.png`, `app/web/icons/Icon-192.png`, `app/web/icons/Icon-512.png`, `app/web/icons/Icon-maskable-192.png`, `app/web/icons/Icon-maskable-512.png`, `app/web/index.html`, `app/web/manifest.json`, `scripts/build_web_locales.py` | — | static server renders `app/web_app/index.html`; `node --test app/web_app/tests/*.test.mjs` |

### W2 — Honest algorithms and real prices (16/11)

| Pack | Owner | Card / PR title | Files | Depends | Verify |
|---|---|---|---|---|---|
| **W2.1** | Bao | `T-38: real bidirectional A*, explicit NOT_IMPLEMENTED, opt-in memory, street names` | `backend/navie/graph/core.py` (m), `backend/navie/search/bidir.py` (m), `backend/navie/search/__init__.py` (m), `backend/navie/planner/service.py` (m), `backend/navie/errors.py` (m), `backend/navie/main.py` (m), `backend/tests/test_bidir.py`, `backend/tests/test_route_fixes.py`, `backend/tests/fixtures/graphs.py` (m) | W1.3 | `algorithm=alt` → HTTP 422; `bidir_astar` expands strictly less than `bidir_dijkstra` at equal cost |
| **W2.2** | Quang Minh | `T-39: verified pricing data and per-mode cost formulas` | `data/pricing/fuel.yaml` (m), `data/pricing/taxi.yaml` (m), `data/pricing/vehicles.yaml` (m), `data/pricing/tolls.csv` (m), `backend/navie/costs/engine.py` (m), `backend/tests/test_costs.py` (new) | W1.2 | `cost_vnd > 0` for motorbike/car/taxi; one hand-computed test per formula; every value has `source` + `last_updated` |
| **W2.3** | Duc | `T-23b: browser planner, mode comparison and drive session` | `app/web_app/app.js`, `app/web_app/navigation.mjs`, `app/web_app/tests/navigation.test.mjs` | W1.4, W1.3 | search → 4 mode cards with VND; route line drawn; `node --test` green |
| **W2.4** | Minh Nguyen | `T-10: benchmark harness v1 (E1 grid)` | `scripts/bench.py` (new), `report/results/E1_algorithm_comparison.csv` (new), `backend/tests/test_bench_harness.py` (new), `Makefile` (m) | W1.3 | `make bench` writes the CSV for 500 OD pairs x {ucs, greedy, astar, weighted_astar, bidir_dijkstra, bidir_astar} |

### W3 — Flutter parity and the first figures (17/11)

| Pack | Owner | Card / PR title | Files | Depends | Verify |
|---|---|---|---|---|---|
| **W3.1** | Bao | `T-05b: real-graph oracle suite and NFR-01 numbers` | `backend/tests/test_real_graph.py` (new), `scripts/verify_against_networkx.py` (new), `docs/03_algorithms.md` (m) | W2.1 | 200 random OD pairs match networkx within 1e-6; measured A* ms and graph-load time recorded in the doc |
| **W3.2** | Quang Minh | `T-16: reproducible traffic simulator` | `scripts/simulate_traffic.py` (new), `data/traffic/sim_config.yaml` (new), `data/traffic/simulated_observations.csv` (new), `backend/tests/test_traffic_sim.py` (new) | — | same seed → identical CSV; >= 50k rows; assumptions documented |
| **W3.3** | Duc | `T-23c: Flutter planner and map` | `app/lib/main.dart`, `app/lib/features/planner/planner_screen.dart`, `app/lib/features/planner/route_map.dart`, `app/lib/l10n/app_vi.arb` (m), `app/lib/l10n/app_en.arb` (m), `app/lib/l10n/app_localizations.dart`, `app/lib/l10n/app_localizations_vi.dart`, `app/lib/l10n/app_localizations_en.dart`, `app/test/widget_test.dart`, `app/test/planner_states_test.dart`, `app/test/route_map_test.dart` | W1.3 | `flutter analyze` clean, `flutter test` green, tap A → tap B draws a route |
| **W3.4** | Minh Nguyen | `T-35: plots and figure export` | `scripts/plots.py` (new), `report/figures/E1_nodes_expanded.png` (new), `report/figures/E2_runtime_vs_distance.png` (new), `report/figures/E3_weighted_astar_tradeoff.png` (new), `report/figures/E4_explored_maps.png` (new), `backend/pyproject.toml` (m: add matplotlib), `Makefile` (m) | W2.4 | `make bench` produces all four figures and logs the machine specs |

### W4 — Local search and the Bayesian network (18/11)

| Pack | Owner | Card / PR title | Files | Depends | Verify |
|---|---|---|---|---|---|
| **W4.1** | Bao | `T-28a: /v1/logistics/optimize contract and distance matrix` | `backend/navie/logistics/__init__.py` (new), `backend/navie/logistics/service.py` (new), `backend/navie/logistics/distance_matrix.py` (new), `backend/navie/schemas.py` (m), `backend/navie/main.py` (m), `backend/tests/test_logistics_api.py` (new) | W1.3 | endpoint validates 1..30 stops, builds the matrix with UCS, 422 on bad input |
| **W4.2** | Quang Minh | `T-17: Bayesian network fit and own inference` | `backend/navie/traffic/__init__.py` (new), `backend/navie/traffic/bn.py` (new), `backend/navie/traffic/fit.py` (new), `scripts/fit_bn.py` (new), `data/build/bn_params.json` (new), `backend/tests/test_bn.py` (new) | W3.2 | enumeration and variable elimination agree; both match pgmpy within 1e-6 (pgmpy test-only) |
| **W4.3** | Duc | `T-25/T-26: Flutter driver mode and smooth playback` | `app/lib/features/driver/driver_screen.dart`, `app/lib/features/driver/navigation_progress.dart`, `app/test/driver_smoothness_test.dart`, `app/test/heading_smoothing_test.dart`, `app/test/navigation_progress_test.dart` | W3.3 | preview drive runs at measured speed; heading never snaps; TTS never queues a stale prompt |
| **W4.4** | Minh Nguyen | `T-28b: nearest neighbour, brute force, hill climbing, simulated annealing` | `backend/navie/logistics/nn.py` (new), `backend/navie/logistics/brute_force.py` (new), `backend/navie/logistics/hill_climb.py` (new), `backend/navie/logistics/anneal.py` (new), `backend/tests/test_tsp.py` (new) | W4.1 | FR-41 AC: SA <= NN on >= 95% of random instances; brute force is ground truth for n <= 9; fixed seeds |

### W5 — Traffic reaches the route, logistics reaches the screen (19/11 — oral)

| Pack | Owner | Card / PR title | Files | Depends | Verify |
|---|---|---|---|---|---|
| **W5.1** | Bao | `T-18: time-dependent edge weights from the network` | `backend/navie/traffic/weights.py` (new), `backend/navie/planner/service.py` (m), `backend/navie/schemas.py` (m), `backend/tests/test_time_dependent.py` (new) | W4.2 | FR-04 AC: same OD at 08:00 vs 03:00 gives different car durations; bucket cache hit rate logged |
| **W5.2** | Quang Minh | `T-16b/T-17b: experiment data for the essay (E5, E8)` | `scripts/export_experiments.py` (new), `report/results/E5_traffic_effect.csv` (new), `report/results/E8_bn_inference.csv` (new), `report/figures/E5_traffic_effect.png` (new), `report/figures/E8_bn_inference.png` (new) | W5.1 | CSVs regenerate from a fixed seed; the numbers in them are the numbers quoted in essay §4 |
| **W5.3** | Duc | `T-27: settings, i18n and accessibility` | `app/lib/features/settings/settings_screen.dart`, `app/lib/main.dart` (m), `app/lib/l10n/app_vi.arb` (m), `app/lib/l10n/app_en.arb` (m), `app/lib/l10n/app_localizations*.dart` (m), `app/pubspec.yaml` (m — ASK before adding a persistence dependency, per AGENTS.md rule 9) | W3.3 | NFR-06/07: vi default survives a restart, >= 48 dp targets, semantics labels on every button and result card |
| **W5.4** | Minh Nguyen | `T-28c: local-search experiments and convergence figures (E7)` | `scripts/bench_tsp.py` (new), `report/results/E7_local_search.csv` (new), `report/figures/E7_convergence.png` (new) | W4.4 | SA vs HC vs NN vs brute on 50 instances, n in {10,20,30}; gap to brute force reported |

### W6 — Dynamic obstacles close the loop (20/11)

| Pack | Owner | Card / PR title | Files | Depends | Verify |
|---|---|---|---|---|---|
| **W6.1** | Bao | `T-19/T-22: incident store, TTL, replan reroute` | `backend/navie/incidents/__init__.py` (new), `backend/navie/incidents/store.py` (new), `backend/navie/nav/replan.py` (new), `backend/navie/main.py` (m), `backend/navie/schemas.py` (m), `backend/tests/test_incidents.py` (new), `backend/tests/test_reroute.py` (new) | W5.1 | a report affects edges within 50 m, TTL per type, duplicates within 100 m merge, `/v1/nav/reroute` < 1.5 s |
| **W6.2** | Quang Minh | `T-15b: POI pass and administrative aliases for the geocoder` | `scripts/build_geocode.py` (m), `backend/navie/geocode/service.py` (m), `data/geocode/aliases.csv` (new), `backend/tests/test_geocode_poi.py` (new) | W1.2 | FR-01 AC: "Chợ Bến Thành" returns the market inside HCMC within 2 s; old and new ward names both resolve |
| **W6.3** | Duc | `T-29/T-40: logistics screen, incident button, faster-route prompt, tilt and dark map` | `app/web_app/app.js` (m), `app/web_app/index.html` (m), `app/web_app/styles.css` (m), `app/lib/features/logistics/logistics_screen.dart` (new), `app/lib/features/driver/driver_screen.dart` (m), `app/lib/features/planner/route_map.dart` (m) | W5.3, W6.1 | report a flood on the active route → "Đường mới nhanh hơn X phút" prompt appears; convergence chart renders |
| **W6.4** | Minh Nguyen | `T-36: QA, mobile playtest and accessibility audit` | `report/QA_2026-11-20.md` (new), `report/ui/driver-mobile.png`, `report/ui/planner.png`, `backend/tests/test_smoke.py` (new) | W2.3, W4.3 | device-simulator evidence at 390x844; every Must AC walked; flaky tests fixed or deleted |

### W7 — Freeze and submit (21/11)

| Pack | Owner | Card / PR title | Files | Depends | Verify |
|---|---|---|---|---|---|
| **W7.1** | Bao | `T-12b: error catalogue, OpenAPI polish, release notes, v1.0 tag` | `backend/navie/main.py` (m), `backend/navie/errors.py` (m), `README.md` (new), `report/RELEASE_NOTES.md` (new), `docs/02_architecture.md` (m) | all Must | every error code documented; `make run` smoke; tag `v1.0` |
| **W7.2** | Quang Minh | `T-32: rule-based natural-language parse with the LLM optional` | `backend/navie/llm/__init__.py` (new), `backend/navie/llm/parser.py` (new), `backend/navie/main.py` (m), `backend/tests/test_parse.py` (new) | W1.3 | "chở 200kg gạo từ Thủ Đức đến Quận 7 rẻ nhất" → valid `TripQuery` with no network; unknown text falls back to the form |
| **W7.3** | Duc | `T-34: demo script, screenshots and backup video` | `report/DEMO_SCRIPT.md` (new), `report/ui/*.png` (m), `report/figures/E4_explored_maps.png` (m) | W6.3 | scripted OD pairs, seeded incidents, rehearsed 15 min x3, recording saved |
| **W7.4** | Minh Nguyen | `T-37: essay assembly, submission checklist, clean-machine rehearsal` | `report/essay/*.md` (new, assembled), `report/SUBMISSION_CHECKLIST.md` (new), `report/ai_usage_log.md` (m), `docs/06_report_and_presentation.md` (m) | all | 10 pages double-spaced + cover page with all four names and student IDs; references complete; clean checkout passes `make setup && make test` |

---

## 5. Coverage map — nothing is orphaned

Every file that is uncommitted today is assigned to exactly one pack.

| Area | Count | Pack |
|---|---|---|
| `backend/navie/{schemas,errors,main}.py`, `planner/`, `search/{__init__,greedy,ida_star,bidir}`, `tests/test_api_vertical.py`, `docs/02_architecture.md` | 11 | W1.3 |
| `backend/navie/{costs,geocode}/`, `scripts/build_geocode.py`, `tests/test_geocode.py`, `docs/04_data_and_costs.md` | 7 | W1.2 |
| `app/web_app/{index.html,styles.css,icons.mjs,locales.mjs}`, `app/web/**`, `scripts/build_web_locales.py` | 12 | W1.4 |
| repo root, `app/pubspec.yaml`, `app/.gitignore`, `app/.metadata`, `app/analysis_options.yaml`, `app/README.md`, `report/*.md`, `report/course_pdf_text.txt` | 14 | W1.1 |
| `app/web_app/{app.js,navigation.mjs}`, `tests/navigation.test.mjs` | 3 | W2.3 |
| `app/lib/{main,features/planner/*,l10n/*}`, `app/test/{widget,planner_states,route_map}_test.dart` | 11 | W3.3 |
| `app/lib/features/driver/*`, `app/test/{driver_smoothness,heading_smoothing,navigation_progress}_test.dart` | 5 | W4.3 |
| `app/lib/features/settings/*` | 1 | W5.3 |
| `backend/navie/graph/core.py`, `tests/{test_bidir,test_route_fixes}.py`, `tests/fixtures/graphs.py` | 4 | W2.1 |
| `report/ui/planner.png`, `report/ui/driver-mobile.png` | 2 | W6.4 |

Total: 70 files, each counted once at its **first landing**. Some of them are touched again by a later pack — `planner/service.py` and `search/bidir.py` by W2.1/W5.1, `main.py` and `errors.py` by W2.1/W4.1/W6.1/W7.1/W7.2, `search/__init__.py` by W2.1 — and that is expected, not double work. Anything not listed here is already committed; check `git log -- <path>` before assuming otherwise.

---

## 6. Essay and slides (not code, but graded)

Handled inside the packs, not bolted on at the end: **every pack ships its own paragraph** into `report/essay/`.

| Section | Pages | Owner | Lands in |
|---|---|---|---|
| 1 Introduction (Vietnam traffic, motorbike majority, flooding, goal, contributions) | 1 | Duc | W2.3, W3.3 |
| 2 Problem formulation (graph, state, cost, per-mode constraints, time-dependent costs) | 1 | Bao | W1.3, W5.1 |
| 3 Search algorithms (UCS, Greedy, A*, WA*, bidirectional, IDA*, admissibility proof sketch + citations) | 2 | Bao | W1.3, W2.1, W3.1 |
| 4 Traffic under uncertainty (BN structure, MLE + Laplace, variable elimination, congestion → speed) | 1.5 | Quang Minh | W4.2, W5.2 |
| 5 Dynamic obstacles and local search (replan, SA vs HC) | 1 | Minh Nguyen (+ Bao for replanning) | W4.4, W5.4, W6.1 |
| 6 Experiments and discussion (E1–E8, tables, limitations) | 2.5 | Minh Nguyen | W3.4, W5.4, W6.4 |
| 7 Conclusion and future work | 0.5 | Duc | W7.3 |
| Assembly + formatting (10 pages, double-spaced, cover page with the four names and IDs, references) | — | Minh Nguyen | W7.4 |

Slides: Minh Nguyen owns the deck skeleton in W5.4; each person fills their own slides in W7.

---

## 7. If a wave slips — cut in this order

Cut from the bottom, never the top:

1. W7.2 rule-based parse (Should, FR-05) — ship the 503 fallback and say so.
2. W6.2 POI geocoder pass (Should) — only if the demo never types a POI name.
3. W5.4 / W4.4 extra logistic experiments — keep the SA-vs-HC result, drop the plots.
4. W6.1 incident TTL/merge detail — keep blocking floods only.
5. W3.1 real-graph oracle suite — keep the fixture oracle tests.

**Never cut:** W2.4 + W3.4 (the benchmark comparison is the graded core), W4.4 (local search is named in the PDF), W7.4 (the essay is the deliverable), W1.1 (the repo must build).

If two waves have to become one, merge W5.4 into W4.4 and W7.2 into W7.1 — the least coupled pairs. You still land 28 PRs.

---

## 8. Definition of done for the whole plan

- [ ] 28 merged PRs, one per pack, each with its reviewer's approval
- [ ] `main` green: backend 69+ tests, Flutter analyze clean + 27+ tests, browser 11+ tests
- [ ] `report/figures/E1..E8` exist and match the CSVs they came from
- [ ] Every Must AC in `01_requirements.md` walked in `report/QA_2026-11-20.md` with pass/fail + evidence
- [ ] Essay: 10 pages, double-spaced, cover page with the four names and IDs, intro/discussion/conclusion, references
- [ ] Deck: 15-minute run sheet rehearsed three times, backup recording saved
- [ ] `report/ai_usage_log.md` has one row per pack (AI-use disclosure)
- [ ] Clean checkout: `make setup && make data && make test` passes on a machine that is not this one
