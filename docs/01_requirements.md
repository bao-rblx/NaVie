# NaVie — Requirements

Priority: M = Must, S = Should, C = Could. Each requirement has acceptance criteria (AC) the agent must turn into tests.

## 1. Trip planning
**FR-01 (M) Pick origin/destination** — by map tap, search box (geocoder), or "my location".
- AC: tapping map sets a pin; search "Chợ Bến Thành" returns a result inside HCMC within 2 s.

**FR-02 (M) Compare modes** — one request returns options for walk, motorbike, car, taxi (and others enabled by scope).
- AC: each option has `distance_m`, `duration_s`, `cost_vnd`, `geometry`, `legs[]`, `cost_breakdown`.
- AC: walking is never offered for trips > 10 km unless explicitly requested.

**FR-03 (M) Optimize preference** — Fastest / Cheapest / Balanced / Fewest transfers.
- AC: switching preference re-sorts client-side without a new request.

**FR-04 (M) Departure time** — "now" or a chosen time; traffic model uses it.
- AC: same OD at 08:00 weekday vs 03:00 gives different car durations.

**FR-05 (S) Natural-language input** — e.g. "chở 200kg gạo từ Thủ Đức đến Quận 7 rẻ nhất".
- AC: parsed into the `TripQuery` JSON schema; invalid LLM output is rejected by validation and the user sees the pre-filled form to correct.
- AC: app works fully when the LLM is unavailable.

**FR-06 (S) Intercity multimodal** — HCMC ↔ Hanoi / Da Nang / Nha Trang etc. combining access leg + train/plane/coach/ferry + egress leg.
- AC: returns the Pareto set over (time, cost, transfers); no returned option is dominated by another.

**FR-07 (S) AI summary** — 1–3 sentence explanation of top options. Numbers in the text must come from the result JSON (template fallback).

## 2. Algorithm lab (for grading and demo)
**FR-10 (M) Algorithm selector** — user (or dev panel) chooses UCS, Greedy, A*, Weighted A*, Bidirectional Dijkstra, Bidirectional A*, IDA*, ALT.
- AC: response includes `stats {nodes_expanded, runtime_ms, peak_memory_kb, path_cost}`.

**FR-11 (M) Explored-node visualization** — show expanded nodes as an animated heat layer on the map.
- AC: Dijkstra vs A* on the same OD visibly differs; max 20k points sent (sampled).

**FR-12 (M) Benchmark runner** — CLI script runs all algorithms over N random OD pairs, outputs CSV + plots.

## 3. Traffic & dynamic obstacles
**FR-20 (M) Time-dependent traffic** — edge travel time depends on Bayesian Network congestion estimate for (time of day, day type, weather, road class, incidents).
- AC: BN inference matches `pgmpy` oracle within 1e-6 on test queries.

**FR-21 (M) Incident reports** — user taps report type (tai nạn / ngập / công trình / kẹt xe / cảnh sát) at current location.
- AC: report affects edges within 50 m; expires after type-specific TTL (e.g. jam 30 min, flood 3 h); duplicate reports within 100 m merge.

**FR-22 (M) Rerouting on obstacles** — active routes crossing a new blocking incident get a "Đường mới nhanh hơn X phút" prompt.

**FR-23 (C) Crowdsourced speeds** — driver mode sends anonymized speed samples; server blends them into edge speeds.

## 4. Driver mode
**FR-30 (M) Navigation view** — heading-up camera, tilted map, large next-maneuver banner, distance-to-turn, ETA, remaining km, current speed, speed limit (if known).

**FR-31 (M) Turn instructions** — Vietnamese text ("Sau 200 m, rẽ phải vào đường Lê Lợi") generated from route geometry.
- AC: turn classification from bearing change: straight <20°, slight 20–45°, turn 45–135°, sharp >135°, U-turn >170°.

**FR-32 (M) Voice guidance** — device TTS `vi-VN` at 500 m / 200 m / 50 m before a maneuver (walk: 50 m only).

**FR-33 (M) Off-route detection & reroute** — off-route if > 40 m from route for 3 consecutive fixes → reroute from current position and heading.
- AC: reroute response < 1.5 s for HCMC trips < 20 km.

**FR-34 (M) GPS simulator** — replay a route (or recorded GPX) at configurable speed, with optional injected detour, so the demo works indoors.

**FR-35 (M) Mode-specific rules** — motorbike never uses motorways (`highway=motorway`) or roads tagged `motorcycle=no`; truck obeys `maxweight`/`maxheight` and truck-ban windows (C); walk uses footways and ignores one-way.

**FR-36 (S) Day/night theme and simplified driving UI** — no text input while speed > 10 km/h (voice only).

**FR-37 (C) Voice commands** — "tìm cây xăng gần nhất", "tránh đường ngập" → speech-to-text → LLM intent → action.

## 5. Logistics
**FR-40 (S) Light cargo comparison** — weight/size → courier price estimates from rate tables + motorbike/car/van route.

**FR-41 (S) Multi-stop ordering** — depot + up to 30 stops → order minimizing total time using SA; compare Hill Climbing, nearest neighbour, brute force (n ≤ 9).
- AC: SA result ≤ nearest-neighbour result on 95% of random instances.

**FR-42 (C) Fleet (multi-agent)** — k vehicles, capacity constraint → VRP via SA.

**FR-43 (C) Heavy truck** — load-aware routing (FR-35) + tonnage-based cost.

## 6. Non-functional
| ID | Requirement |
|---|---|
| NFR-01 | City route (≤ 20 km) with A* < 1 s on a laptop; graph load < 10 s |
| NFR-02 | Navigation never depends on the LLM; all AI-service failures degrade gracefully |
| NFR-03 | $0 running cost; no paid API keys required to run |
| NFR-04 | All prices show `last_updated` and "ước tính / estimate" label; unverified data flagged |
| NFR-05 | Privacy: GPS samples anonymized (random session id, no account), deleted after 30 days, opt-in toggle |
| NFR-06 | UI in Vietnamese (default) and English |
| NFR-07 | Accessibility: min tap target 48 dp, contrast ≥ 4.5:1, screen-reader labels on all buttons |
| NFR-08 | Test coverage ≥ 80% for `backend/navie/search`, `traffic`, `logistics` |
| NFR-09 | Map attribution for OpenStreetMap shown; Hoàng Sa / Trường Sa labeled as Vietnam in any custom map layer |
| NFR-10 | Reproducible: `make setup && make data && make run` works on a clean machine (Windows + Linux) |
