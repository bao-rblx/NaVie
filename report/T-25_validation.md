# T-25 · Planner-to-driver experience

Date: 2026-11-02 (Asia/Saigon)

The previous clients stopped at a route card and used stretched, fixed map tiles.
The browser client now provides a responsive planner, real place search, mode
comparison, route detail, saved/recent destinations, settings, and an algorithm
comparison view. The driver flow connects the selected API route to live GPS or
clearly labeled simulation, turn prompts, optional speech, rerouting, and arrival.
Flutter now provides the planner-to-driver flow with matching visual treatment,
shared translations, responsive maps, session settings, and device integrations.

No dependencies were added. No API contracts or production search algorithms were
changed by this task. Existing uncommitted backend work was retained.

## Validation

| Check | Result |
| --- | --- |
| Backend ruff check / format | Passed, 39 files formatted |
| Backend mypy | Passed, 25 source files |
| Backend pytest | 43 passed; 91% total coverage |
| Flutter analyze | Passed, no issues |
| Flutter tests | 7 passed |
| Browser Node tests | 9 passed |
| Browser JavaScript syntax | Passed |
| Flutter release web build | Passed |

`make lint && make test` was attempted, but GNU make is not installed. Its recipes
were executed directly instead. Flutter is available at `C:/src/flutter/bin` and
is not on the default shell PATH. Ruff must run from `backend/` as in the Makefile
to use that project's formatting configuration. The successful JavaScript release
build reports existing `flutter_tts` warnings for the optional Wasm dry run.

Tests cover: segment projection, geometry interpolation, unknown price ordering,
TripQuery request mapping, accurate off-route fixes, ignored weak GPS, simulation
clamping, one-point routes, duplicate geometry, voice threshold deduplication,
shared ARB parity, narrow Flutter layout, search/results/preview/exit, and stale
route responses after reset.

Browser verification used the live HCMC backend and actual geocoder results for
Chợ Bến Thành and Landmark 81. Verified four-mode comparison, route rendering,
destination saving across reload, preview start/pause/speed/end, English/night
mode/reduced motion, and actual A*/Dijkstra statistics. Verified responsive
planner, settings, saved-place, and driver layouts at 390 × 844. Browser console
reported no JavaScript errors during these flows. Mobile driver evidence is in
`report/ui/driver-mobile.png`.

## Human review and follow-ups

- Physical GPS and actual device voice output still need a road/device test.
  Do not interpret successful simulated driving as physical GPS validation.
- The repository still needs Android platform scaffolding and permission setup;
  this task validated the Flutter web build, not an Android APK.
- Native Flutter saved places and algorithm lab are not implemented; those
  features currently belong to the browser demo.
- Traffic BN, incident persistence/WebSocket alerts, logistics, intercity data,
  verified prices/speeds, tilt, GPX playback and injected detours remain separate
  roadmap work. This is not a claim that all Must acceptance criteria are met.
- Browser settings and saved places persist locally. Flutter settings currently
  last for the app session. Installed device/browser voices determine TTS support.
- Road geometry and turn text come from the existing route API; lane guidance
  and reliable named-street instructions are not provided by this client change.
- Review the Vietnamese copy, map rendering and accessibility on target devices.

The UI exposes these data limitations instead of fabricating live traffic, prices,
speed limits, or completed server-side functionality.
