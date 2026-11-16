"""Build a local OSM place/address index for ``GET /v1/geocode``.

Road names come from the already-built NaVie graph. Named POIs are downloaded
from Overpass once during ``make data`` and stored locally; runtime search does
not call a third-party geocoder.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from navie import config  # noqa: E402
from navie.geocode.service import normalize  # noqa: E402
from navie.graph.core import load  # noqa: E402

OVERPASS_ENDPOINTS = (
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass-api.de/api/interpreter",
)
POI_TAGS = (
    "amenity",
    "shop",
    "tourism",
    "leisure",
    "office",
    "public_transport",
    "railway",
    "aeroway",
    "historic",
    "place",
    "building",
)


def overpass_query(city: str) -> str:
    """Return the bounded query for named user-facing places."""
    south, west, north, east = config.CITY_BBOX[city]
    bbox = f"{south},{west},{north},{east}"
    selectors = "\n".join(f'nwr["name"]["{tag}"]({bbox});' for tag in POI_TAGS)
    return f"[out:json][timeout:180];(\n{selectors}\n);out center tags;"


def download_osm_places(city: str) -> list[dict[str, Any]]:
    """Download named OSM features, retrying the public mirrors conservatively."""
    data = urllib.parse.urlencode({"data": overpass_query(city)}).encode()
    headers = {"User-Agent": "NaVie-class-project/0.1 (offline geocode index builder)"}
    errors: list[str] = []
    for attempt in range(3):
        for endpoint in OVERPASS_ENDPOINTS:
            request = urllib.request.Request(endpoint, data=data, headers=headers, method="POST")
            try:
                with urllib.request.urlopen(request, timeout=240) as response:
                    payload = json.load(response)
                return list(payload.get("elements", []))
            except (OSError, urllib.error.HTTPError, json.JSONDecodeError) as exc:
                errors.append(f"{endpoint}: {exc}")
        if attempt < 2:
            time.sleep(2**attempt)
    raise RuntimeError("Overpass download failed: " + "; ".join(errors[-4:]))


def address_from_tags(tags: dict[str, Any]) -> str | None:
    """Build an address only from explicit OSM ``addr:*`` fields."""
    street = str(tags.get("addr:street", "")).strip()
    house_number = str(tags.get("addr:housenumber", "")).strip()
    locality = next(
        (
            str(tags[key]).strip()
            for key in ("addr:suburb", "addr:district", "addr:city")
            if tags.get(key)
        ),
        "",
    )
    first_line = " ".join(part for part in (house_number, street) if part)
    value = ", ".join(part for part in (first_line, locality) if part)
    return value or None


def poi_places(elements: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Convert Overpass nodes/way centers/relation centers to API place records."""
    places: list[dict[str, Any]] = []
    for element in elements:
        tags = element.get("tags") or {}
        name = str(tags.get("name:vi") or tags.get("name") or "").strip()
        center = element.get("center") or element
        if not name or "lat" not in center or "lon" not in center:
            continue
        kind = next((str(tags[tag]) for tag in POI_TAGS if tags.get(tag)), "place")
        places.append(
            {
                "name": name,
                "address": address_from_tags(tags),
                "latlon": [float(center["lat"]), float(center["lon"])],
                "kind": kind,
            }
        )
    return places


def road_places(city: str) -> list[dict[str, Any]]:
    """Create one representative point for every OSM road name in the graph."""
    graph = load(city)
    sources = graph.edge_source()
    seen: set[int] = set()
    places: list[dict[str, Any]] = []
    for edge_id, name_id_value in enumerate(graph.name_id):
        name_id = int(name_id_value)
        if name_id < 0 or name_id in seen:
            continue
        seen.add(name_id)
        node = int(sources[edge_id])
        places.append(
            {
                "name": graph.names[name_id],
                "address": None,
                "latlon": [float(graph.node_lat[node]), float(graph.node_lon[node])],
                "kind": "road",
            }
        )
    return places


def deduplicate(places: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Remove duplicate OSM representations without merging distinct branches."""
    unique: dict[tuple[str, float, float], dict[str, Any]] = {}
    for place in places:
        lat, lon = place["latlon"]
        key = (normalize(place["name"]), round(float(lat), 4), round(float(lon), 4))
        existing = unique.get(key)
        if existing is None or (not existing.get("address") and place.get("address")):
            unique[key] = place
    return sorted(unique.values(), key=lambda place: normalize(place["name"]))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--city", default="hcmc", choices=sorted(config.CITY_BBOX))
    parser.add_argument(
        "--from-json",
        type=Path,
        help=(
            "Use a saved Overpass JSON response instead of downloading "
            "(for reproducible rebuilds)."
        ),
    )
    parser.add_argument(
        "--roads-only",
        action="store_true",
        help="Build immediately from graph road names without downloading POIs.",
    )
    args = parser.parse_args()

    if args.roads_only:
        elements: list[dict[str, Any]] = []
    elif args.from_json:
        payload = json.loads(args.from_json.read_text(encoding="utf-8"))
        elements = list(payload.get("elements", []))
    else:
        print(f"downloading named OSM places for {args.city} ...")
        elements = download_osm_places(args.city)

    places = deduplicate(road_places(args.city) + poi_places(elements))
    output = config.BUILD_DIR / f"{args.city}_geocode.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(
            {"city": args.city, "source": "OpenStreetMap contributors", "places": places},
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    print(f"wrote {output}: {len(places):,} places")


if __name__ == "__main__":
    main()
