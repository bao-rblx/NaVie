# NaVie — Data, Pipelines & Cost Formulas

All prices are **estimates** with a `last_updated` field. Person 1 (data) owns verifying every number before demo. Values below marked `TODO-verify` are placeholders — the agent must not invent "real" numbers; keep placeholders until a human fills them.

## 1. Coverage
| Area | Bounding box (south, west, north, east) |
|---|---|
| HCMC core | 10.70, 106.60, 10.88, 106.80 |
| Hanoi core | 20.95, 105.75, 21.10, 105.90 |
Start with HCMC only; add Hanoi once the pipeline works. Keep graphs ≤ ~300k nodes for laptop RAM.

## 2. Pipelines (`make data`)
| Step | Script | Output |
|---|---|---|
| Download OSM roads per bbox | `scripts/build_graph.py --city hcmc` (osmnx `graph_from_bbox`, `network_type="all"`, simplify) | `data/raw/hcmc.graphml` |
| Convert to CSR + flags | same script | `data/build/hcmc.npz`, `hcmc_names.json` |
| Landmarks for ALT | `scripts/build_landmarks.py` | `data/build/hcmc_alt_{mode}.npz` |
| POI / address index | `scripts/build_geocode.py` (OSM names, `amenity`, `addr:*`) | `data/build/hcmc_geocode.json` |
| Simulated traffic | `scripts/simulate_traffic.py --seed 42` | `data/traffic/simulated_observations.csv` |
| Fit BN | `scripts/fit_bn.py` | `data/build/bn_params.json` |
`data/raw` and `data/build` are git-ignored; scripts are deterministic and cached.

### Traffic simulation assumptions (document in essay)
- Peaks 07:00–09:00 and 16:30–19:00 weekdays; heavy rain lowers speeds and raises jam probability; primary roads congest more at peaks; holidays (Tết) shift patterns.
- Generate ≥ 50k observations with noise; keep generator parameters in `data/traffic/sim_config.yaml` so results are reproducible.
- Optional real data: team drives with GPS logging (driver mode, FR-23) → map-match → add rows with `source=real`.

## 3. Pricing files (`data/pricing/`)
### `fuel.yaml`
```yaml
last_updated: TODO-verify   # Petrolimex announcement date
currency: VND
ron95_per_l: TODO-verify
e5_ron92_per_l: TODO-verify
diesel_per_l: TODO-verify
source: "Petrolimex / Bộ Công Thương price announcement"
```
### `vehicles.yaml`
```yaml
motorbike_110cc: { fuel: e5_ron92, l_per_100km: 2.0, parking_vnd: 5000 }
car_sedan:       { fuel: ron95,    l_per_100km: 7.0, parking_vnd: 30000 }
van_1t:          { fuel: diesel,   l_per_100km: 10.0, capacity_kg: 1000 }
truck_5t:        { fuel: diesel,   l_per_100km: 18.0, capacity_kg: 5000 }
# consumption values are typical estimates — verify
```
### `taxi.yaml` (per brand, per vehicle)
```yaml
last_updated: TODO-verify
brands:
  grab_bike:  { open_vnd: TODO, first_km: 2, per_km_vnd: TODO, per_min_vnd: 0 }
  grab_car4:  { open_vnd: TODO, first_km: 2, per_km_vnd: TODO, per_min_vnd: TODO }
  xanh_sm:    { open_vnd: TODO, first_km: 1, per_km_vnd: TODO, per_min_vnd: TODO }
  be_bike:    { ... }
surge: { peak_multiplier: 1.3 }   # assumption, shown as range
```
### `tolls.csv`
`station_id,name,lat,lon,class1_vnd,class2_vnd,class3_vnd,class4_vnd,class5_vnd,last_updated`
Snap stations to graph edges at build time; edge flag `toll` + `toll_station_id`.

### `courier.yaml`
Per carrier (GHN, GHTK, Viettel Post, Ahamove, Lalamove): weight brackets × zone (`inner_city`, `intra_region`, `inter_region`) → VND. Fill from public rate pages manually.

## 4. Cost formulas (`backend/navie/costs/`)
| Mode | Formula |
|---|---|
| walk | 0 |
| motorbike (own) | `km × l_per_100km/100 × fuel_price + parking` |
| car (own) | `km × l_per_100km/100 × fuel_price + Σ tolls(class1) + parking` |
| taxi / ride-hail | `open + max(0, km − first_km) × per_km + minutes × per_min`, show `[base, base × surge]` at peaks; one option per brand, best shown first |
| truck (own) | fuel + tolls(class by tonnage) + `driver_vnd_per_h × hours` (assumption) |
| courier | rate table lookup by weight bracket and zone; volumetric weight = L×W×H(cm)/6000 |
| train / plane / coach / ferry | fare from schedule row (class chosen by user, default cheapest) + access/egress leg costs |
| CO₂ (info) | `km × g_per_km` per mode table (cite source) |

Rounding: round to nearest 1,000 VND for display; keep exact in JSON.

## 5. Schedules (`data/schedules/`) — hand-entered demo set
### `hubs.csv`
`hub_id,type(station|airport|bus_terminal|port),name,city,lat,lon,min_transfer_min`
Initial ~10 cities: Hà Nội, Hải Phòng, Huế, Đà Nẵng, Quy Nhơn, Nha Trang, Đà Lạt, TP.HCM, Cần Thơ, Phú Quốc.

### `trains.csv`, `flights.csv`, `coaches.csv`, `ferries.csv`
`service_id,carrier,from_hub,to_hub,depart_time,arrive_time,day_offset,days_of_week,class,fare_vnd,last_updated,source`
- Enter a realistic sample (e.g. SE1–SE8 Thống Nhất trains, a few daily VN/VJ flights per route, main coach operators, Phú Quốc ferries) from public timetables, marking `source` and date.
- Do **not** scrape ticketing sites; manual entry only.

## 6. Geocoding
- Normalizer: lowercase, strip accents (unidecode) for matching while keeping original for display; expand abbreviations (`q.`→`quận`, `p.`→`phường`, `tp`→`thành phố`, `đ.`→`đường`, `hcm`/`sg`→`hồ chí minh`); parse house numbers like `12/3`.
- Ranking: rapidfuzz `WRatio` score + proximity bonus to `near`.
- Note: 2025 administrative reorganization changed many ward/province names — accept both old and new names via an alias table `data/geocode/aliases.csv`.

## 7. Storage
SQLite `data/navie.db`: tables `incidents(id, type, lat, lon, created_at, expires_at, confirmations)`, `gps_samples(session_id, ts, lat, lon, speed, heading)` (opt-in, 30-day purge), `llm_cache(hash, response, created_at)`.

## 8. Licensing & compliance
- OSM data: ODbL — show "© OpenStreetMap contributors"; OpenFreeMap attribution.
- Hoàng Sa / Trường Sa: any custom label layer shows them as Vietnam; check base tile rendering before demo.
- Cite all data sources in the essay.
