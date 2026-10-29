# AGENTS.md — Rules for AI coding agents working on NaVie

Read this file first, then `docs/00_brief.md`, then the docs referenced by your task card in `docs/05_roadmap.md`.

## Project in one paragraph
NaVie is a class project (Intro to AI) — a Vietnam route planner + driver-mode app. The graded part is **our own implementations** of search algorithms (A*, IDA*, bidirectional, ALT, D* Lite), a Bayesian Network traffic model, and local search (Hill Climbing, Simulated Annealing). Backend: Python 3.11 + FastAPI. App: Flutter (web + Android). Running cost must be $0.

## Hard rules
1. **Never** use library shortest-path / inference / optimization functions in production code (`networkx.shortest_path`, `pgmpy` inference, `scipy.optimize`, Valhalla, OSRM, OR-Tools). They are allowed **only in `backend/tests/`** as oracles.
2. **Never invent data.** Prices, fares, timetables, speeds, tolls come from files in `data/`. If a value is missing, add a placeholder with `verified: false` and a `TODO(source)` comment — do not guess silently.
3. The LLM (`navie/llm/`) only parses text into `TripQuery` and writes explanations. It never computes routes, durations or prices. Validate all LLM output with pydantic; on failure, fall back.
4. Navigation (`nav/`, `search/`) must work with the LLM disabled and with no internet except map tiles.
5. No paid APIs, no API keys committed. Secrets go in `.env` (git-ignored); provide `.env.example`.
6. Do one task card per PR. Stay inside its scope; note follow-ups in the PR description instead of doing them.
7. Every change ships with tests. Run `make lint && make test` before declaring done; paste the summary in the PR.
8. `backend/navie/schemas.py` is the single source of truth for the API contract in `docs/02_architecture.md` §4. Change both together.
9. Pin dependency versions exactly. Ask before adding a new dependency not listed in `docs/02_architecture.md` §3.
10. Map layers must keep OSM attribution; any custom label of Hoàng Sa / Trường Sa must show them as Vietnam.

## Code conventions
- Python: type hints, ruff-formatted, docstrings on public functions; algorithms return `SearchResult` (see `docs/03_algorithms.md`).
- Units: meters, seconds, VND (int), coordinates `[lat, lon]`, time zone `+07:00`.
- Determinism: any randomness takes a `seed` argument; tests fix seeds.
- Flutter: riverpod for state, go_router, feature folders under `app/lib/features/`, all strings in ARB files (vi default, en).
- Commits: `T-XX: short summary`.

## Commands
| Command | Does |
|---|---|
| `make setup` | install backend + app deps |
| `make data` | download OSM, build graphs, simulate traffic, fit BN |
| `make run` | start backend on :8000 |
| `make test` | pytest (with coverage) + flutter test |
| `make bench` | run benchmarks → `report/figures/` |
| `make lint` | ruff + mypy + flutter analyze |

## After each task
Append to `report/ai_usage_log.md`: date, card ID, what you generated, open issues for the human reviewer.
