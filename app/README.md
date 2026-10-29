# NaVie app (Flutter)

The Flutter project is not generated yet: Flutter is not installed on the machine that created this skeleton. P3 generates it in place, keeping the folders below.

```sh
cd app
flutter create --project-name navie --org vn.navie --platforms web,android .
```

Then add the packages from `docs/02_architecture.md` §3 (maplibre_gl, geolocator, flutter_tts, dio, flutter_riverpod, go_router, intl) with exact versions, and enable `flutter gen-l10n` using `l10n.yaml`.

Layout (`AGENTS.md` code conventions):

- `lib/features/{planner,driver,lab,simulator,report}`: one folder per feature.
- `lib/l10n/app_vi.arb` (default) and `app_en.arb`: every UI string lives here.
- Map layers keep the OSM attribution; any custom label of Hoàng Sa / Trường Sa shows them as Vietnam.
