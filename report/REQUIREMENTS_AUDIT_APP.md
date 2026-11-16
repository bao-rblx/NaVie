# NaVie — Flutter/Browser App Requirements & Smoothness Audit

Scope: `app/lib/**`, `app/web_app/**`, `app/pubspec.yaml`, `app/test/**` vs `docs/01_requirements.md` and the course PDF demo expectations.
Method: full read of every file listed above; `flutter analyze` -> **No issues found**; `flutter test` -> **7/7 pass**; `node --test app/web_app/tests` -> **9/9 pass**. Static analysis only — no device/browser profiling was run, so the frame-time claims below are structural (code-path) claims, not measurements.

Two clients exist and they are **not** at feature parity: `app/web_app/` (complete demo: saved places, algorithm lab, reduced motion, toasts) and `app/lib/` (Flutter: planner + driver + settings only). Where they differ, both are cited.

---

## 1. FR coverage

Legend: DONE = AC met and reachable from a UI · PARTIAL = present but an AC clause is unmet or a screen is missing · MISSING = no UI path at all.

| ID | Requirement (short) | Status | Evidence |
|---|---|---|---|
| FR-01 | Pick origin/destination (tap, search, my location) | DONE | `planner_screen.dart:240-243` map tap -> pin; `:293-313` search box; `:162-185` my-location; geocode debounce 300 ms `:80` |
| FR-02 | Compare modes, one request | PARTIAL | `planner_screen.dart:11-17,354-366` mode chips incl. `all`; but `cost_breakdown`, `legs[]`, `geometry` never rendered — only distance/minutes/price `:441-445` |
| FR-03 | Fastest / Cheapest / Balanced / Fewest transfers | PARTIAL | Only 2 of 4: `planner_screen.dart:410-421`; `optimize` is hard-coded to balanced at `:122` so the dropdown never reaches the server |
| FR-04 | Departure time drives traffic model | MISSING | No `depart_at` anywhere in `app/lib` (0 grep hits); backend accepts it (`schemas.py:51`) but no control exists |
| FR-05 | Natural-language input | MISSING | `/v1/parse` always raises 503 (`backend/navie/main.py:110-116`); no text box, no pre-filled-form fallback UI |
| FR-06 | Intercity multimodal + Pareto | MISSING | No UI; `plan_trip` emits only one option per road mode (`planner/service.py:164-184`) |
| FR-07 | AI summary of top options | MISSING | `PlanResponse.summary` never read by either client (0 grep hits in `app/lib`) |
| FR-10 | Algorithm selector + stats | PARTIAL | Browser only: `web_app/index.html:53`, `app.js:321-348` — 4 of 8 algorithms (no Weighted A*, bidir A*, IDA*, ALT). Flutter has no lab screen at all |
| FR-11 | Explored-node heat layer | PARTIAL | `web_app/app.js:340-344` animated reveal at 80 ms; cap is 5 000 pts (`:331`) vs AC 20 000; Flutter: absent |
| FR-12 | Benchmark runner | MISSING | `make bench` prints 'not implemented yet (T-10)' (`Makefile:44`) |
| FR-20 | Time-dependent traffic (BN) | MISSING | `backend/navie/traffic/` contains 0 .py files; no `depart_at` sent by clients |
| FR-21 | Incident reports (5 types, TTL, merge) | MISSING | No report button/TTL UI in either client; `IncidentRequest` exists (`schemas.py:156`) but no route |
| FR-22 | 'Đường mới nhanh hơn X phút' prompt | MISSING | Reroute exists (`driver_screen.dart:162-193`) but no obstacle trigger and no faster-route prompt |
| FR-23 | Crowdsourced speeds | MISSING | No speed-upload path |
| FR-30 | Nav view: heading-up, tilt, banner, ETA, speed, limit | PARTIAL | `driver_screen.dart:240-337` banner/metrics OK; **no tilt**; speed limit hard-coded dash at `:327`; speed hidden during preview |
| FR-31 | Vietnamese turn instructions, bearing classes | DONE | Server `planner/service.py:36-56` (<20 straight, <45 slight, <=135 turn, >170 U-turn); rendered `driver_screen.dart:156,265-269` |
| FR-32 | TTS vi-VN at 500/200/50 m (walk 50) | PARTIAL | `driver_screen.dart:145-160` dedupe is correct; utterances queue and are never cancelled — see 2.7 |
| FR-33 | Off-route > 40 m x3 -> reroute | DONE | `navigation_progress.dart:70-95`; 10 s cooldown `driver_screen.dart:164-167`; parity in `navigation.mjs:72-78` |
| FR-34 | GPS simulator, speed, injected detour | PARTIAL | Replay 1/3/5/10x `driver_screen.dart:74-85,317-323`; no GPX import, no injected detour, and preview synthesises distance not GPS fixes, so FR-33 cannot be demoed indoors |
| FR-35 | Mode-specific edge rules | DONE (backend) | `graph/profiles.py:59-61`, `graph/build.py:123-127`; app forwards the mode `planner_screen.dart:210` |
| FR-36 | Day/night theme, no text input > 10 km/h | PARTIAL | `themeProvider` `settings_screen.dart:6` -> `main.dart:22`; but driver banner is hard-coded light green (`driver_screen.dart:245`) and the map has no dark tile treatment; the >10 km/h rule is unimplemented |
| FR-37 | Voice commands | MISSING | No speech-to-text anywhere |
| FR-40 | Light-cargo comparison | MISSING | No cargo UI; `backend/navie/logistics/` is empty |
| FR-41 | Multi-stop ordering (SA vs HC) | MISSING | No stops list/ordering screen |
| FR-42 | Fleet VRP | MISSING | — |
| FR-43 | Heavy truck rules | MISSING | `truck` accepted by `schemas.py:10` but absent from `_modeIcons` (`planner_screen.dart:11-17`) |
| NFR-06 | UI vi (default) + en | PARTIAL | ARB files in parity (133 keys each) but **63/133 keys unused**; hard-coded units `driver_screen.dart:225-227`, price `planner_screen.dart:442`, playback label `:321`; language is a Riverpod `StateProvider` (`settings_screen.dart:5`) with no persistence, so it resets each launch |
| NFR-07 | 48 dp targets, 4.5:1 contrast, screen-reader labels | PARTIAL | Only 7 `tooltip:` in `app/lib` and **0** `Semantics`/`semanticLabel`; result cards (`planner_screen.dart:431-446`) and metrics (`driver_screen.dart:339-344`) unlabelled; ChoiceChips (`:358`) and playback dropdown (`driver_screen.dart:317-323`) are < 48 dp; web switch is 46x28 (`styles.css:19`) |
| NFR-09 | OSM attribution shown | DONE | `route_map.dart:188-197` (10 px, outside the rotated layer); `settings_screen.dart:53`; `web_app/index.html:18` |

**Counts:** 26 FRs -> **4 DONE, 10 PARTIAL, 12 MISSING**; NFR-06/07/09 -> **1 DONE, 2 PARTIAL**. Overall **5 DONE / 12 PARTIAL / 12 MISSING** across 29 rows.

---

## 2. Smoothness & polish (the jank list)

Ordered by user-visible impact. Line numbers are current HEAD.

**2.1 The whole driver screen rebuilds 4x/s.** `driver_screen.dart:75-83` — `Timer.periodic(250 ms)` wraps everything in `setState`; it also runs during preview at 1x, so the banner, metrics, `RouteMap` and every `Image.network` tile widget rebuild 4 times a second for nothing. Line `:78` advances by a hard-coded 0.25 s instead of measured elapsed time, so playback drifts whenever the engine throttles the timer (the browser client gets this right — `app.js:273` uses `performance.now()` deltas). **Fix:** hold progress/position/speed in a `ValueNotifier` (or an `AnimationController` with `vsync`) and rebuild only the banner plus a `RepaintBoundary`-wrapped map; advance by `Stopwatch` delta.

**2.2 The polyline is re-projected and re-built every frame.** `route_map.dart:155` calls `widget.route.map(screen).toList()` inside `build` — hundreds of points, each through `_world()` (two `math.pow`, a `tan`, a `log`) on every rebuild, with no cache anywhere in the file. `_MapPainter.paint` then constructs a fresh `Path` and two `Paint`s per paint (`route_map.dart:216-233`). `RepaintBoundary` appears **0 times** in `app/lib`. **Fix:** project once per (zoom, center, size) and cache; hoist `Path`/`Paint` into the painter's constructor; wrap the `CustomPaint` and the tile `Stack` in `RepaintBoundary`.

**2.3 `shouldRepaint => true`.** `route_map.dart:248` forces a repaint every frame even when route, pins and camera are identical — a paused preview still redraws at 60 Hz. **Fix:** compare fields (`listEquals` for route, `!=` for the pins) instead of returning `true`.

**2.4 Heading-up camera snaps instead of animating.** `route_map.dart:93` derives the rotation straight from `_progress.heading`, and `navigation_progress.dart:33-47` returns a per-segment bearing that jumps at every vertex — the map whips at each turn and the pushpin rotates in 4 discrete steps per second during preview. No smoothing, no `AnimatedRotation`, and no angle unwrapping (359 -> 1 rotates the map backwards through 358 degrees). **Fix:** keep a displayed heading and apply a shortest-arc lerp each tick, or `AnimatedRotation(turns: -heading/360, duration: 300 ms, curve: Curves.easeOutCubic)`.

**2.5 Camera pans and zooms teleport.** `route_map.dart:34-47` — `didUpdateWidget` assigns `_center = widget.position!` and forces `_zoom = 17` with no animation, so every GPS fix / 250 ms tick re-centres instantly; `_fit()` (`:68-83`) also jumps zoom in one frame when a route is selected. Pinch zoom is integer-only with a 1.5x/0.66x threshold (`:116-121`), giving stepped zooming, and `_following` is killed by any stray `onScaleStart` (`:106-109`) with no `onScaleEnd` handling. **Fix:** animate center+zoom with an `AnimationController` (250-350 ms, `easeInOutCubic`) interpolated in Mercator space; make zoom a continuous double that settles over 150 ms.

**2.6 Map tiles churn and will get the demo rate-limited.** `route_map.dart:145-150` builds a new `Image.network` for `tile.openstreetmap.org` inside the build path with **no `gaplessPlayback`, no frameBuilder fade, no User-Agent, and an unbounded key space** — every zoom change blanks the grid until re-decoded. Fetching OSM tiles directly from an app also violates the OSM tile usage policy, which is exactly what `docs/05_roadmap.md:72` avoided by specifying an OpenFreeMap style. **Fix:** raster-tile cache painted via `CustomPainter` (the web client already does this — `app.js:18,83` `tileCache`), `imageCache.maximumSizeBytes`, `gaplessPlayback: true`, `filterQuality: FilterQuality.low`, and a policy-compliant source.

**2.7 TTS can queue, overlap and outlive the screen.** `driver_screen.dart:61-71` awaits `setLanguage` (a platform round-trip) then calls `speak`; `FlutterTts` queues by default and nothing calls `stop()` first, so a 500 m prompt still plays when the 200 m prompt is due — at 10x preview the user hears stale distances in sequence. `_announce` fires from both the timer (`:81`) and GPS (`:114`), and pause (`:315`) does not stop speech. **Fix:** `awaitSpeakCompletion(true)`, `_tts.stop()` before each utterance, `setSpeechRate(0.5)`, `setLanguage` once in `initState`, and drop announcements whose distance is already stale.

**2.8 Encoding corruption (mojibake) — 2 sites, 4 wrong glyphs.** `driver_screen.dart:321` — the playback dropdown label is built from a corrupted multiplication sign (should be U+00D7 x; file holds U+00C3 U+2014). `driver_screen.dart:327` — the speed line uses corrupted em-dash and middle-dot (should be U+2014 and U+00B7; file holds U+00E2 U+20AC U+201D U+00C2 U+00B7). A repo-wide scan of *.dart/*.arb/*.mjs/*.js/*.py/*.md found **no other** corrupted strings. **Fix:** restore the three characters and move them into ARB keys (`playbackMultiplier`) so a non-UTF-8 editor save cannot re-corrupt them.

**2.9 Hard-coded strings that bypass the ARB.** `driver_screen.dart:225-227` (space-m and space-km), `:321`, `:327` (km/h), `planner_screen.dart:442` (km and the dong sign). Violates AGENTS.md 'all strings in ARB files' and NFR-06. The 63 unused ARB keys (`noPlaces`, `searchingPlaces`, `loading`, `hoursShort`, `simulationPaused`, `stopNavigation`, `driverMode`, ...) are the intended replacements, so this is delete-and-wire, not new copy.

**2.10 No loading skeletons; weak empty and error states.** `planner_screen.dart:368-377` shows loading only by swapping the button label and spinner; the results area keeps the welcome card via `AnimatedSwitcher` (`:383-403`) while a request is in flight, so the layout lies for up to 45 s (`receiveTimeout` `:34`). A suggestion search with zero hits renders nothing (`:314`). Errors are a bare red `Text` with no icon and no retry (`:378-381`). **Fix:** 3 skeleton cards sized like the real `ListTile`s while `_loading`, an `l.noPlaces` empty row, and an error card with an icon plus Retry calling `_find()`.

**2.11 Abrupt state changes everywhere; almost no animation APIs.** `app/lib` contains **0** uses of `AnimatedContainer`, `AnimatedOpacity`, `AnimatedRotation`, `Hero` or `PageRouteBuilder` (one lone `AnimatedSwitcher` at `planner_screen.dart:383`). Selecting another option swaps the polyline instantly (`route_map.dart:39-42`) with no cross-fade; re-sorting (`planner_screen.dart:418-421`) reorders the list with no `AnimatedList`; `_drive` pushes a raw `MaterialPageRoute` (`:206`) while everything else is go_router (`main.dart:10-14`, `planner_screen.dart:256`) — two navigation stacks, default platform transition, no shared route map. **Fix:** `CustomTransitionPage` (fade-through 250 ms) for the driver route, `AnimatedSwitcher` around the option list, and camera animation instead of `_fit()`.

**2.12 Dark mode is broken on the two most visible surfaces.** The map paints a fixed `Color(0xffe5ede5)` backdrop (`route_map.dart:128`) and a fixed `#087f5b` polyline (`:222-224`) regardless of `ThemeMode`, and `driver_screen.dart:245,253-276` hard-codes `#087f5b` with white text. The browser client solved this (`styles.css:11` — `.dark #tiles` brightness/saturate filter, `.dark .route-line` stroke swap); Flutter has no equivalent, so dark theme shows a light map island inside a dark app. **Fix:** derive map colors from `colorScheme` and apply a `ColorFiltered` matrix over the tile layer in dark mode.

**2.13 Layout and tap-target risks.** (a) `planner_screen.dart:441-443` concatenates distance and price into one unlimited `Text`; with `priceUnavailable` the line wraps and `ListTile` heights jump — needs `maxLines: 1` + ellipsis. (b) `driver_screen.dart:265-269` banner text has no `maxLines`, so a long Vietnamese street name grows the banner and resizes the map mid-drive. (c) `planner_screen.dart:326-349` is `Row(TextButton.icon + Spacer + IconButton)` and can overflow at 320 dp with the vi label. (d) Tap targets under 48 dp: `ChoiceChip` (`:358`, M3 default 32), playback `DropdownButton<int>` (`driver_screen.dart:317-323`), web settings switch 46x28 (`styles.css:19`) — NFR-07 violation. (e) Typography is ad-hoc: hard-coded 27/29/22/17/11 px (`planner_screen.dart:250`, `driver_screen.dart:262,342,269,276`) mixed with `headlineMedium`/`labelSmall` on the same screen; the banner status line is 11 px white-on-green (about 4.6:1, borderline).

**2.14 Small refetch/flicker details, one line each.** `driver_screen.dart:184` sets a status of 'Route updated.' permanently, so the banner keeps a stale confirmation for the rest of the drive. `driver_screen.dart:233-235` computes ETA as `DateTime.now().toUtc().add(Duration(hours: 7))` — hard-coded +07:00, wrong on any device not on ICT, and `intl` is already a dependency but unused. `route_map.dart:100-105` drops a pin on `onTapUp` even when the gesture was a pan (no drag guard), and there is no visible 'picking A/B' state although `_picking` exists (`planner_screen.dart:40`). `planner_screen.dart:210` takes `modes.first` for an `all` option, silently choosing walk if a combined option ever appears.

**2.15 Browser client: same class of jank, different primitives.** `app.js:93-97` rebuilds `#route-layer` innerHTML (two polylines plus up to 5 000 circles) on every animation frame, recomputing `pixel()` (which calls `world()` with log/tan) per point per frame while dragging; `app.js:88,300` snaps camera rotation and pin rotation in 4 discrete steps per second; `app.js:88` writes the `#map-scene` transform with no CSS transition, so heading-up rotates in jumps; `styles.css:10` swaps the 484 px map inset in a single frame when driving starts; `app.js:261` calls `speechSynthesis.cancel()` before every utterance, cutting off the in-flight prompt; `app.js:83-87` prunes `tileCache` only by viewport, never by size, so memory grows while panning. **Fix:** mutate the existing polyline's `points` attribute instead of replacing children, precompute projected geometry on route change, add a transition on `#map`, lerp rotation in rAF, guard speech with `utterance.onend`, and cap the tile cache.

---

## 3. Prioritized fix list

### P0 — correctness / demo-blocking
1. Send a real `optimize` value (and `depart_at`) from the planner instead of hard-coding balanced — `app/lib/features/planner/planner_screen.dart:121-123`.
2. Add Balanced and Fewest-transfers to the sort control so FR-03's four AC values exist — `planner_screen.dart:410-421`.
3. Render `cost_breakdown`, `legs[]` and `data_version.last_updated` so FR-02 and NFR-04 are actually visible — `planner_screen.dart:441-445`.
4. Show `PlanResponse.summary` (FR-07) with a 'template' label — `planner_screen.dart:447`.
5. Fix the two mojibake strings (multiplication sign, em-dash, middle dot) — `app/lib/features/driver/driver_screen.dart:321,327`.
6. Replace the direct OSM tile fetch with a policy-compliant, cached tile source — `app/lib/features/planner/route_map.dart:145-150`.
7. Persist locale and theme so the vi default survives a restart — `app/lib/features/settings/settings_screen.dart:5-6`.
8. Time the preview with a `Stopwatch` instead of assuming 250 ms ticks, or the 10x demo is not 10x — `driver_screen.dart:78`.
9. Add the incident-report entry point (FR-21) and the faster-route prompt (FR-22) — `driver_screen.dart:240-337`.
10. Guard map taps against pans so a drag cannot drop a stray pin — `route_map.dart:100-105`.

### P1 — smoothness
11. Replace the 250 ms whole-screen setState with a notifier so only the banner and map repaint — `driver_screen.dart:75-83`.
12. Cache the projected polyline and hoist `Path`/`Paint` out of `paint()` — `route_map.dart:155,216-233`.
13. Make `shouldRepaint` compare fields instead of returning true — `route_map.dart:248`.
14. Animate bearing with shortest-arc easing — `route_map.dart:93` and `navigation_progress.dart:33-47`.
15. Animate camera center/zoom (250-350 ms easeInOutCubic, Mercator space) instead of assigning in `didUpdateWidget` / `_fit` — `route_map.dart:34-47,68-83`.
16. Add `RepaintBoundary` around the polyline painter and the tile grid — `route_map.dart:99-166`.
17. Set `gaplessPlayback`, low `filterQuality` and an image-cache budget on tiles — `route_map.dart:145-150`.
18. TTS: await completion, stop before speak, set language once, stop on pause — `driver_screen.dart:61-71,145-160`.
19. Skeleton cards, an `l.noPlaces` empty row, and an error card with Retry — `planner_screen.dart:314,368-381`.
20. One transition system: move the driver screen onto go_router with a fade-through page — `planner_screen.dart:204-214`.
21. Derive map and banner colors from `colorScheme`; dark-filter tiles (FR-36) — `route_map.dart:128,222` and `driver_screen.dart:245`.
22. Browser: mutate the polyline `points` attribute instead of rebuilding innerHTML each frame — `app/web_app/app.js:93-97`.
23. Browser: lerp camera rotation and add a CSS transition on `#map` — `app/web_app/app.js:88,300` and `styles.css:10`.

### P2 — polish
24. `maxLines` + ellipsis on the option subtitle and the maneuver banner — `planner_screen.dart:441`, `driver_screen.dart:265`.
25. Raise ChoiceChip, playback dropdown and the web switch to at least 48 dp (NFR-07) — `planner_screen.dart:358`, `driver_screen.dart:317`, `styles.css:19`.
26. Add `Semantics` labels to result cards, metrics and the live status line — `planner_screen.dart:431-446`, `driver_screen.dart:271-276,339-344`.
27. Move the last hard-coded unit strings into the ARB and delete the 63 dead keys — `driver_screen.dart:225-227,321,327`, `planner_screen.dart:442`.
28. Format ETA and price with `intl` and the Asia/Ho_Chi_Minh zone instead of the +7 h trick — `driver_screen.dart:233-235`.
29. Clear the status line after a few seconds instead of leaving 'Route updated.' forever — `driver_screen.dart:184`.
30. Add a visible picking-A/B affordance and `onScaleEnd` handling — `planner_screen.dart:296`, `route_map.dart:106-122`.
31. Add a web tile-cache size cap — `app/web_app/app.js:83-87`.

---

### Notes for the Lead
- `app/android/` and `app/ios/` **do not exist**; the Flutter app is web-only despite the brief's 'web + Android', so every device-GPS/TTS AC (FR-30/32/34) is unverified on real hardware.
- Five backend packages (`traffic/`, `nav/`, `logistics/`, `llm/`, `api/`) contain 0 Python files, which is the upstream cause of 12 of the MISSING rows.
- The two clients duplicate the whole planner/driver logic (`app.js` vs `planner_screen.dart`); every fix above has to be made twice. Picking one client for the 19/11 demo would remove roughly half of sections 2 and 3.
