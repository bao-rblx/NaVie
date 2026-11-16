# NaVie — Requirements verdict & smoothness pass
Date: 2026-11-15 (Asia/Saigon) · Auditor: Lead agent · Evidence: report/REQUIREMENTS_AUDIT_BACKEND.md, report/REQUIREMENTS_AUDIT_APP.md

## 1. Short answer

**No — the project does not yet meet all the requirements.** Every course-PDF obligation that is a *product* is largely done and honest; every obligation that is a *deliverable* is missing, and one of the two graded AI extensions (local search) plus the graded comparison experiment were never built.

Deadline pressure: code freeze was **12/11 (passed)**, oral is **19/11 (4 days)**, submission is **22/11 (7 days)**. Today is 15/11.

## 2. Course PDF, obligation by obligation

| PDF obligation | Where it sits | Status |
|---|---|---|
| Pathfinding on a complex map (Category 1) | HCMC OSM graph, 138,322 nodes / 351,154 edges, per-mode profiles | **DONE** |
| Implement **A\*** | `backend/navie/search/astar.py` | **DONE** (textbook-clean, admissible+consistent heuristic) |
| Implement **IDA\*** | `backend/navie/search/ida_star.py` | **PARTIAL** — correct, but exhausts its 2M-node budget on any real city trip and returns 404 NO_PATH. Only usable on small subgraphs. That is a legitimate finding to write up, but it cannot be demoed as a route. |
| Implement **bidirectional search** | `bidir.py` (Dijkstra + a real Ikeda–Dijkstra bidirectional A\*) | **DONE** (fixed today: `bidir_astar` used to be bidir Dijkstra wearing a different label) |
| Implement **local search (Hill Climbing / Simulated Annealing)** | `backend/navie/logistics/` | **MISSING** — empty directory, zero lines of code. This is named in the PDF's own bullet list. |
| **Compare** the algorithms | `scripts/bench.py`, `scripts/plots.py`, `report/figures/` | **MISSING** — `make bench` prints "not implemented yet". No figures exist. This is the single biggest grading gap: comparison *is* the assignment. |
| Complex map *with traffic* | `backend/navie/traffic/` (Bayesian network) | **MISSING** — empty directory. `depart_at` is accepted by the API and silently ignored; 08:00 and 03:00 return identical durations. |
| Extensions: multiple agents / dynamic obstacles | fleet VRP, incidents | **MISSING** — incident pydantic models exist but have no routes and no store. |
| 10-page double-spaced essay + cover page (title, members, student IDs) | `report/` | **MISSING** — no draft, no .docx/.tex/.pdf anywhere. `docs/06_report_and_presentation.md` is a 50-line outline, not prose. |
| Essay has introduction / discussion / conclusion | — | **MISSING** (outline only) |
| Proofs sketched with citations | citations are listed in `docs/06` §1, reasoning is in code comments | **PARTIAL** — no written proof sketch, no bibliography |
| 15-minute oral presentation | — | **MISSING** — no slide deck |
| No plagiarism / disclose AI use | `report/ai_usage_log.md` | **DONE** — unusually well kept, and extended again today |

## 3. Product requirements (docs/01_requirements.md)

Backend audit: **6 DONE · 10 PARTIAL · 12 MISSING · 1 UNVERIFIABLE** across 29 rows.
App audit: **5 DONE · 12 PARTIAL · 12 MISSING** across 29 rows.

Both audits independently land on the same root cause: five backend packages exist as **empty directories** — `traffic/`, `nav/`, `logistics/`, `llm/`, `api/`. Everything MISSING downstream (FR-04, FR-20, FR-21, FR-22, FR-40, FR-41, FR-42, FR-43) is blocked on those.

### Requirements that fail their own acceptance criterion today
- **FR-01** — the geocode index holds 25,801 entries and **all of them are roads**. Searching "Chợ Bến Thành" returns a road named Hồ Thành Biên; no entry contains "ben thanh". The AC is not met.
- **FR-02** — `cost_vnd` is **0 for every motorised mode** (`costs/engine.py` returns `pricing_unverified, 0` because `data/pricing/*.yaml` are unfilled placeholders). No VND comparison can be shown. The honesty is correct per AGENTS.md rule 2; the missing number is a data-entry task, not a coding task.
- **FR-03** — the server parses `optimize` and ignores it. The AC (client-side re-sort) does pass.
- **FR-04** — `depart_at` is parsed and dropped; identical durations at every hour.
- **FR-10** — of the eight listed algorithms, three were honest (UCS, Greedy, A\*), one had a hard-coded `w=1.5`, two were **silently substituted** (`bidir_astar`→bidir Dijkstra, `alt`→plain A\*), one was broken at city scale (IDA\*), one was advertised but absent (D\* Lite).
- **FR-31** — every maneuver had `street: null`, so instructions read "Rẽ phải", not "Rẽ phải vào Lê Lợi".

## 4. What was fixed in this session

### Backend (69 tests, was 43; coverage 93.08%, gate now enforced at 80%)
1. `weight="distance"` reported a **fabricated duration** — it divided the whole distance by the fastest speed in the profile. A path whose true time cost is 547 s was reported as 308 s (45% too fast). Now sums the time-cost array over the chosen edges.
2. Bidirectional search **rebuilt the reverse CSR on every call** (full argsort of 351k edges, 25.4 ms). Guarded; bidirectional is no longer slower than A\*.
3. `bidir_astar` is now a **real bidirectional A\*** (Ikeda potential, 3,688 expansions vs 8,378 for bidir Dijkstra, same cost). `alt` and `dstar_lite` now return **HTTP 422 NOT_IMPLEMENTED with a bilingual message** instead of quietly running A\*. `stats.algorithm` can no longer name an algorithm that did not run.
4. `tracemalloc` was forced on for **every** route request at a measured **5.3×** runtime cost. Now opt-in via `debug.track_memory`.
5. Maneuvers now carry **street names** (18/20 on the Bến Thành→Landmark 81 route) and the Vietnamese/English text includes them.
6. NFR-08 coverage floor added.

### Flutter client (27 tests, was 7; `flutter analyze` clean)
- The driver view rebuilt the **whole screen 4×/second**, including every `Image.network` tile. Now a `ValueNotifier` drives three subtrees; instrumented build count went from 4-per-4-ticks to 0.
- Playback advanced a hard-coded 0.25 s per tick, so the 10× demo was not 10×. Now measured with a `Stopwatch`; pause resets the clock.
- Heading **whips at every road vertex**. Now a shortest-arc lerp (359°→1° is 2°, not −358°).
- The map **teleported** on every GPS fix and forced zoom 17. Now one `AnimationController` eases centre, zoom and bearing (300 ms, easeInOutCubic, reduced-motion aware), ignores sub-pixel jitter, and `_fit()` computes a fractional zoom instead of stepping.
- The whole polyline was **re-projected through pow/tan/log on every build**; `shouldRepaint` returned `true` unconditionally; `RepaintBoundary` appeared nowhere. Now a projection cache, prebuilt `Path`, field-comparing `shouldRepaint`, and two `RepaintBoundary`s.
- Tiles: `gaplessPlayback`, low filter quality, keyed, integer-zoom fetches scaled to the fractional zoom.
- TTS queued stale prompts (a 500 m prompt played while the 200 m one was due). Now language set once, `stop()` before each utterance, `awaitSpeakCompletion`.
- **Mojibake fixed**: the playback multiplier showed `'Ã—'` and the speed line showed `'â€”'` / `'Â·'`. Both moved into the ARB and regenerated; a repo-wide scan for the corrupt sequences now returns zero files.
- Planner sends the selected `optimize` value, shows skeleton cards while loading, and truncates the option subtitle.

### Browser client (11 tests, was 9)
- Camera now eases on a rAF loop (90 ms exponential approach, frame-rate independent) while pan/pinch stay 1:1; reduced-motion snaps.
- Rotation uses shortest-arc for both the map and the driver pin.
- `#route-layer` was rebuilt as an **innerHTML string every animation frame** (2 polylines + up to 5,000 circles). The polylines are now created once; points are rewritten only when the route or integer zoom changes, and a group transform absorbs pan and in-flight zoom.
- Tile cache is a real LRU (cap 220), reuses nodes, never re-appends a visible tile.
- CSS: animated `#map` inset when driving starts, fading toast, staggered driver-panel entry, `will-change`, scale+fade press.
- Speech: `isSpeaking` guard cleared by `onend`/`onerror` — no more `cancel()` on every call.

## 5. What is still open, in the order it costs you marks

1. **Essay (10 pages, double-spaced, cover page) and the 15-minute deck — nothing exists.** Seven days. This is worth more than any remaining code.
2. **`make bench`** — the comparison experiment is the graded core and there is no harness and no figures. ~1 day of work, unblocks 7 essay figures.
3. **Local search (SA/HC for multi-stop ordering)** — named in the PDF bullet list, zero lines written. `docs/03_algorithms.md` §7 specifies it fully.
4. **Bayesian network traffic model** — the "Category 3 depth" the brief sells; also the only thing that makes `depart_at` mean anything.
5. **`cost_vnd` is 0** — a data-entry task for P1 against cited sources; the code path is ready and correctly refuses to invent numbers.
6. **Geocode index has no POIs** — "Chợ Bến Thành" does not resolve. Rebuilding the index needs the Overpass POI pass in `scripts/build_geocode.py` (currently roads-only).
7. **IDA\* cannot route a city trip** — keep it as a reported finding, not a demo path.
8. **ALT, D\* Lite, Replan A\*, incidents, intercity, logistics UI, fleet VRP** — now honestly rejected rather than faked; they are Could/Missing, not silent lies.
9. **Neither client can reach Weighted A\* or bidirectional A\* from the UI** — the lab dropdown offers 4 algorithms; the API now implements 6 honestly. Wiring the other two is a small client change.
10. **Flutter is web-only** — `app/android/` and `app/ios/` do not exist, so the brief's "web + Android" claim is unverified on device.

## 6. Reproducibility notes for the submission
- `make` is **not installed** on the dev machine, so `make setup && make data && make run` (NFR-10) has never run as written. Either install GnuWin32 Make or document the direct commands in the README.
- The backend venv was **incomplete** (missing rapidfuzz, Unidecode) until this session; `make setup` would have fixed it. Do a clean-checkout rehearsal before 22/11.
- `node --test app/web_app/tests/` (trailing slash) fails on Node 24; use the glob form `node --test app/web_app/tests/*.test.mjs`, which is what the Makefile does.
