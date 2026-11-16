# NaVie clients

The browser client in `web_app/` is the complete interface demo. The Flutter
client in `lib/` shares its bilingual copy and implements the planner and driver
journey. Both use the existing team-owned routing algorithms through FastAPI.
Neither requires paid services, an LLM, or a map API key.

## Run the browser app

Start the API from the repository root:

```sh
cd backend
python -m uvicorn navie.main:app --host 127.0.0.1 --port 8000
```

In another terminal, from the repository root:

```sh
python -m http.server 8080 --bind 127.0.0.1 --directory app/web_app
```

Open http://127.0.0.1:8080. The browser uses the current hostname and port 8000
for the API. Build the graph and place index with `make data` if they are absent.
GPS requires localhost or HTTPS and the user's location permission. Map tiles
require internet. Places, routing, and route playback do not require a language
model. Voice guidance uses the installed browser/device voices when available.

### Browser flow

- Search for both endpoints, use your location, or use the pin buttons to pick
  locations on the map. Drag/pinch/scroll to explore; keyboard arrows pan the
  focused map, +/- zoom, and Enter selects its center while picking a point.
- Compare modes, sort returned options locally, inspect turn instructions, and
  save the selected destination. Unverified prices display as unavailable,
  never as a free motorized journey.
- **Start** requests live GPS. **Preview drive** replays the actual route using
  its API duration at 1/3/5/10×, with pause/resume and an arrival dialog. Preview
  never claims to be real driving or displays invented physical speed.
- Live navigation projects GPS onto route segments. Three accurate fixes more
  than 40 m off-route request a fresh A* route via `/v1/route`. Fixes with accuracy
  worse than 40 m are ignored for rerouting/arrival. Failed reroutes retry on
  subsequent fixes with a 10-second cooldown. Leaving navigation cancels the
  GPS watcher, timer, pending reroute and speech.
- Voice prompts are deduplicated at 500/200/50 m (walking: 50 m only). Road speed
  limits remain unknown unless supplied by a future API contract.
- Saved/recent places and settings stay in local browser storage. Settings
  include Vietnamese/English, day/night/system theme, voice, and reduced motion.
- Route lab compares A*, Dijkstra, Greedy, or bidirectional Dijkstra using real
  API statistics and up to 5,000 explored points per request.

## Run Flutter

```sh
cd app
flutter pub get
flutter gen-l10n
flutter run -d chrome --web-port 8080
```

Stop the standalone browser server first if it occupies port 8080. For a device
or another backend address, pass `--dart-define=NAVIE_API_URL=http://HOST:8000`.
The current repository includes web platform scaffolding; Android packaging,
manifest location permissions, and physical-device verification remain separate
setup work. Flutter provides responsive search/results, square map tiles with
pan/pinch/zoom, heading-up driver map, device GPS and TTS, rerouting, simulator,
and session language/theme preferences. Saved places and the algorithm lab are
currently browser features.

## Shared copy and verification

UI copy lives in `lib/l10n/app_vi.arb` and `app_en.arb`. After editing copy, run
from the root:

```sh
python scripts/build_web_locales.py
cd app
flutter gen-l10n
```

The generated `web_app/locales.mjs` lets the browser demo run from a plain static
server. Node's built-in test runner checks parity with both ARB sources.

```sh
make lint && make test
```

Without GNU make, run the recipes directly: backend `ruff check`, `ruff format
--check`, `mypy navie`, and `pytest`; app `flutter analyze` and `flutter test`;
root `node --test app/web_app/tests/*.test.mjs` and `node --check app/web_app/app.js`.
No additional package is needed for browser tests.

## Remaining project work

This upgrade does **not** complete the separate backend roadmap cards for the
traffic Bayesian Network, shared incidents/WebSocket alerts, logistics, intercity
schedules, or verified fares. It does not implement tilt/lane guidance, GPX import,
or injected detours. Estimated ETAs inherit the current road-speed dataset's
verification status and exclude live traffic. The existing maneuver API provides
geometry-derived turns, usually without street names. Validate GPS/TTS and route
geometry on actual devices before relying on it for real-world navigation.

All map surfaces retain OpenStreetMap attribution.
