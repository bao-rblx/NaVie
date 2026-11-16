"""Accent-insensitive local search over the OSM place index."""

from __future__ import annotations

import json
import re
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from rapidfuzz import fuzz
from unidecode import unidecode

from navie import config
from navie.geo import haversine_m
from navie.schemas import Place

_SPACE = re.compile(r"\s+")
_PUNCTUATION = re.compile(r"[^a-z0-9/]+")
_ABBREVIATIONS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"\btp\.?\s*hcm\b|\btphcm\b|\bsg\b"), "thanh pho ho chi minh"),
    (re.compile(r"\bq\.?\s*(\d+)\b"), r"quan \1"),
    (re.compile(r"\bp\.?\s*(\d+)\b"), r"phuong \1"),
    (re.compile(r"\bd\.?\s+"), "duong "),
    (re.compile(r"\btp\.?\s+"), "thanh pho "),
)


def normalize(text: str) -> str:
    """Normalize Vietnamese text for matching while preserving house-number slashes."""
    value = unidecode(text).lower().strip()
    for pattern, replacement in _ABBREVIATIONS:
        value = pattern.sub(replacement, value)
    return _SPACE.sub(" ", _PUNCTUATION.sub(" ", value)).strip()


@dataclass(frozen=True)
class IndexedPlace:
    """Compact normalized place record used by the in-memory index."""

    place: Place
    search_text: str


class Geocoder:
    """Rank local OSM places by fuzzy text similarity and optional proximity."""

    def __init__(
        self,
        places: list[Place],
        online_search: Callable[[str, int], list[Place]] | None = None,
    ) -> None:
        self.places = places
        self.online_search = online_search
        self._index = [
            IndexedPlace(place, normalize(" ".join(filter(None, (place.name, place.address)))))
            for place in places
        ]

    @classmethod
    def from_path(cls, path: Path) -> Geocoder:
        """Load a JSON index created by ``scripts/build_geocode.py``."""
        payload = json.loads(path.read_text(encoding="utf-8"))
        return cls([Place.model_validate(item) for item in payload["places"]])

    def search(
        self,
        query: str,
        near: tuple[float, float] | None = None,
        limit: int = 10,
    ) -> list[Place]:
        """Return the best text matches, using ``near`` only as a ranking bonus."""
        needle = normalize(query)
        if not needle:
            return []

        ranked: list[tuple[float, str, Place]] = []
        for item in self._index:
            name = normalize(item.place.name)
            score = max(
                float(fuzz.WRatio(needle, item.search_text)),
                float(fuzz.token_set_ratio(needle, item.search_text)),
            )
            if name == needle:
                score += 30.0
            elif name.startswith(needle):
                score += 18.0
            elif needle in name:
                score += 10.0

            if near is not None:
                distance_km = (
                    haversine_m(near[0], near[1], item.place.latlon[0], item.place.latlon[1])
                    / 1_000
                )
                score += max(0.0, 10.0 - distance_km / 2.0)

            if score >= 55.0:
                ranked.append((score, name, item.place))

        ranked.sort(key=lambda row: (-row[0], row[1]))
        local = [place for _score, _name, place in ranked[:limit]]
        has_exact_local = any(normalize(place.name) == needle for place in local)
        if self.online_search is None or has_exact_local:
            return local

        online = self.online_search(query, limit)
        combined: list[Place] = []
        seen: set[tuple[str, float, float]] = set()
        for place in online + local:
            key = (normalize(place.name), round(place.latlon[0], 5), round(place.latlon[1], 5))
            if key not in seen:
                seen.add(key)
                combined.append(place)
            if len(combined) == limit:
                break
        return combined


_NOMINATIM_CACHE: dict[tuple[str, str, int], list[Place]] = {}
_NOMINATIM_LOCK = threading.Lock()
_LAST_NOMINATIM_REQUEST = 0.0


def search_osm_online(city: str, query: str, limit: int) -> list[Place]:
    """Use bounded OSM Photon as a rate-limited fallback for missing local POIs."""
    global _LAST_NOMINATIM_REQUEST

    key = (city, normalize(query), limit)
    if key in _NOMINATIM_CACHE:
        return _NOMINATIM_CACHE[key]

    south, west, north, east = config.CITY_BBOX[city]
    params = urllib.parse.urlencode(
        {"q": query, "bbox": f"{west},{south},{east},{north}", "limit": limit}
    )
    request = urllib.request.Request(
        f"https://photon.komoot.io/api/?{params}",
        headers={"User-Agent": "NaVie-class-project/0.1 (OSM Photon place search)"},
    )
    try:
        with _NOMINATIM_LOCK:
            wait_seconds = 1.05 - (time.monotonic() - _LAST_NOMINATIM_REQUEST)
            if wait_seconds > 0:
                time.sleep(wait_seconds)
            with urllib.request.urlopen(request, timeout=8) as response:
                payload = json.load(response)
            _LAST_NOMINATIM_REQUEST = time.monotonic()
    except (OSError, urllib.error.HTTPError, json.JSONDecodeError):
        return []

    places: list[Place] = []
    for item in payload.get("features", []):
        properties = item.get("properties") or {}
        coordinates = (item.get("geometry") or {}).get("coordinates") or []
        name = str(properties.get("name") or "").strip()
        if len(coordinates) != 2:
            continue
        if not name:
            continue
        address = (
            ", ".join(
                str(properties[key]).strip()
                for key in ("housenumber", "street", "district", "city")
                if properties.get(key)
            )
            or None
        )
        places.append(
            Place(
                name=name,
                address=address,
                latlon=(float(coordinates[1]), float(coordinates[0])),
                kind=str(properties.get("osm_value") or properties.get("type") or "place"),
            )
        )
    _NOMINATIM_CACHE[key] = places
    return places


def load(city: str, build_dir: Path | None = None, online: bool = False) -> Geocoder:
    """Load ``data/build/{city}_geocode.json``."""
    directory = build_dir or config.BUILD_DIR
    path = directory / f"{city}_geocode.json"
    if not path.exists():
        raise FileNotFoundError(
            f"{path} missing; run `python scripts/build_geocode.py --city {city}`"
        )
    geocoder = Geocoder.from_path(path)
    if online:
        geocoder.online_search = lambda query, limit: search_osm_online(city, query, limit)
    return geocoder
