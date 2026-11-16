# NaVie — Project Brief

## 1. Course context
- Course: 261_72ITSE30303_01 – Introduction to AI (Dr. Huy T. Nguyen)
- Primary topic: **Category 1 – Pathfinding in Complex Environments** (city map with traffic)
  - Required: implement and compare search algorithms (A*, IDA*, bidirectional, local search).
  - Extensions used: **dynamic obstacles** (live incidents/flooding → rerouting) and **multiple agents** (delivery fleet).
- Supporting topics (bonus depth, not separate projects):
  - Category 3 – Bayesian Network for traffic congestion prediction (parameters learned from simulated data).
  - Category 1 – Local search (Hill Climbing, Simulated Annealing) for multi-stop delivery ordering.
- Deliverables: 10-page double-spaced essay (+ cover page with names and student IDs), 15-min oral presentation, working demo.

## 2. Deadlines (from course PDF)
| Date | Milestone |
|---|---|
| 10/09/2026 | Team & topic submitted |
| 02/10/2026 | Proposal presentation (10 min) |
| 12/11/2026 | Last lecture — **code freeze, final ready** |
| 19/11/2026 | Oral presentation (15 min) |
| 22/11/2026 | ETC submission (essay + code) |

## 3. One-liner
NaVie is a Vietnam map app that finds the best way from A to B for any need — walking, motorbike, car, taxi, truck, train, plane, coach bus, ferry, cargo — comparing distance, time and cost (VND), with a Google-Maps-style driver mode that reroutes around traffic and incidents. Every route is computed by search algorithms **the team implements**.

## 4. What is graded vs what is product
| Graded (must be excellent) | Product (must work for the demo) |
|---|---|
| Own implementations of UCS/Dijkstra, Greedy, A*, Bidirectional, IDA*, Weighted A*, ALT | Flutter app (web + Android) |
| Benchmark experiments and analysis | Map display, search box, results list |
| Dynamic replanning (replan-A*, D* Lite stretch) | Driver mode UI, voice guidance |
| Bayesian Network traffic model + inference | LLM natural-language input |
| Simulated Annealing vs Hill Climbing for multi-stop routes | Cost comparison per mode |
| Essay + presentation | |

Rule: library shortest-path functions (networkx, Valhalla, OSRM) may be used **only as test oracles / baselines**, never as the production algorithm.

## 5. Scope (MoSCoW)
**Must**
- City road graphs for Ho Chi Minh City and Hanoi from OpenStreetMap, per-mode profiles (walk, motorbike, car, truck).
- Search algorithms listed above + benchmark harness + "explored nodes" visualization in the app.
- Trip planner: compare walk / motorbike / car / taxi with distance, time, VND cost.
- Time-of-day traffic via Bayesian Network → time-dependent edge weights.
- Driver mode: follow route, turn instructions (Vietnamese), voice, off-route rerouting, GPS simulator for demos.
- Incident reports (accident, flood, roadwork, jam) → dynamic obstacles → rerouting.

**Should**
- Intercity multimodal (train, plane, coach, ferry) from a small hand-entered timetable, Pareto results (time, cost, transfers).
- LLM natural-language query parsing (Gemini free tier / local Ollama).
- Logistics: light cargo courier comparison; multi-stop delivery ordering with Simulated Annealing.

**Could**
- D* Lite incremental replanning, ALT landmarks.
- Multi-agent fleet (VRP with k vehicles) and congestion-aware multi-agent routing.
- Heavy truck rules (weight limits, city truck-ban hours).
- Crowdsourced GPS speeds from team test drives.

**Won't (this semester)**
- Real-time commercial traffic feeds, ticket booking, iOS App Store release, nationwide street-level routing, lane guidance.

## 6. Geographic scope
- Street level: HCMC and Hanoi (bounding boxes in `docs/04_data_and_costs.md`).
- Intercity: hub graph (stations, airports, bus terminals, ports in ~10 cities) + major-road skeleton for car/bus legs.

## 7. Cost constraint
$0. Everything runs on team laptops (backend) and free services. Demo backend is exposed with a free tunnel (Cloudflare Quick Tunnel) if a phone needs to connect.

## 8. Questions to confirm with the lecturer (before 10/09/2026)
1. Is AI-assisted code generation allowed, and how should it be disclosed in the essay? (The course penalizes plagiarism — get this in writing.)
2. Is one combined project (Category 1 core + Category 3 BN) acceptable, or must we pick exactly one listed project?
3. Must the essay include code listings or only algorithm descriptions?

## 9. Document index
| File | Contents |
|---|---|
| `AGENTS.md` | Rules for the AI coding agent (read first) |
| `docs/01_requirements.md` | Functional & non-functional requirements with acceptance criteria |
| `docs/02_architecture.md` | Components, repo layout, tech stack, API contract, AI call map |
| `docs/03_algorithms.md` | Graph model, algorithms, traffic BN, local search, experiments |
| `docs/04_data_and_costs.md` | Data sources, pipelines, cost formulas, file schemas |
| `docs/05_roadmap.md` | Weekly plan, roles, agent task cards |
| `docs/06_report_and_presentation.md` | Essay and slide outlines |
| `docs/07_work_plan.md` | Who does what: 4 roles, 7 waves, 28 PR-sized packs with exact file scopes |
