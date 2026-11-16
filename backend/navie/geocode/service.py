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
_HOUSE_NUM_PATTERN = re.compile(
    r"^(?:so\s+|hem\s+)?(\d+[a-z0-9/-]*)\s+(.+)$", re.IGNORECASE
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
        online_search: Callable[..., list[Place]] | None = None,
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

        house_num: str | None = None
        street_needle: str | None = None
        street_words: set[str] = set()
        m = _HOUSE_NUM_PATTERN.match(needle)
        if m:
            house_num = m.group(1).upper()
            street_needle = m.group(2).strip()
            street_words = set(street_needle.split())

        ranked: list[tuple[float, str, Place]] = []
        needle_words = needle.split()
        for item in self._index:
            place_to_rank = item.place
            name = normalize(item.place.name)
            search_words = set(item.search_text.split())
            matching_words = sum(1 for w in needle_words if w in search_words)
            all_words_present = (matching_words == len(needle_words)) if needle_words else False

            score = max(
                float(fuzz.WRatio(needle, item.search_text)),
                float(fuzz.token_set_ratio(needle, item.search_text)),
            )

            if not all_words_present and len(needle_words) > 1 and needle not in item.search_text:
                match_fraction = matching_words / len(needle_words)
                if match_fraction < 0.5:
                    score *= 0.35
                else:
                    score *= 0.65

            if name == needle:
                score += 50.0
            elif name.startswith(needle):
                score += 35.0
            elif needle in name:
                score += 25.0
            elif all_words_present:
                score += 15.0

            # Match house number + street name (e.g. 123 Nguyen Thi Minh Khai)
            if house_num and street_needle and item.place.kind == "road":
                street_name = name
                street_score = max(
                    float(fuzz.WRatio(street_needle, item.search_text)),
                    float(fuzz.token_set_ratio(street_needle, item.search_text)),
                )
                if street_name == street_needle:
                    street_score += 65.0
                elif street_name.startswith(street_needle):
                    street_score += 45.0
                elif street_needle in street_name:
                    street_score += 35.0
                elif all(w in search_words for w in street_words):
                    street_score += 25.0

                if street_score > score:
                    score = street_score
                    place_to_rank = Place(
                        name=f"{house_num} {item.place.name}",
                        address=f"{item.place.name}, TP. Hồ Chí Minh",
                        latlon=item.place.latlon,
                        kind="address",
                    )

            if place_to_rank.kind not in ("road", "unknown", "place"):
                score += 10.0

            if near is not None:
                distance_km = (
                    haversine_m(near[0], near[1], place_to_rank.latlon[0], place_to_rank.latlon[1])
                    / 1_000
                )
                # Stronger boost for nearby places (up to 20 points within 5 km)
                score += max(0.0, 20.0 - distance_km * 2.0)

            if score >= 55.0:
                ranked.append((score, normalize(place_to_rank.name), place_to_rank))

        ranked.sort(key=lambda row: (-row[0], row[1]))
        local = [place for _score, _name, place in ranked[:limit]]
        has_exact_local_poi = any(
            normalize(place.name) == needle and place.kind not in ("road", "unknown")
            for place in local
        )
        top_score = ranked[0][0] if ranked else 0.0
        top_is_poi = (ranked[0][2].kind not in ("road", "unknown")) if ranked else False
        has_strong_poi = (top_is_poi and top_score >= 85.0) or has_exact_local_poi

        if self.online_search is None or has_strong_poi:
            return local

        try:
            online = self.online_search(query, limit, near=near)
        except TypeError:
            online = self.online_search(query, limit)

        combined: list[Place] = []
        seen: set[tuple[str, float, float]] = set()

        def place_rank_key(p: Place) -> tuple[int, float, str]:
            p_norm = normalize(p.name)
            is_exact = p_norm == needle
            is_poi = p.kind not in ("road", "unknown")
            prio = 0 if (is_exact and is_poi) else (1 if is_exact else (2 if is_poi else 3))
            dist = (
                haversine_m(near[0], near[1], p.latlon[0], p.latlon[1]) / 1000.0
                if near is not None
                else 0.0
            )
            return (prio, dist, p.name)

        candidates = sorted(online + local, key=place_rank_key)
        for place in candidates:
            key = (normalize(place.name), round(place.latlon[0], 5), round(place.latlon[1], 5))
            if key not in seen:
                seen.add(key)
                combined.append(place)
            if len(combined) == limit:
                break
        return combined


_NOMINATIM_CACHE: dict[tuple[object, ...], list[Place]] = {}
_NOMINATIM_LOCK = threading.Lock()
_LAST_NOMINATIM_REQUEST = 0.0


def search_osm_online(
    city: str,
    query: str,
    limit: int,
    near: tuple[float, float] | None = None,
) -> list[Place]:
    """Use bounded OSM Photon as a rate-limited fallback for missing local POIs."""
    global _LAST_NOMINATIM_REQUEST

    near_key = (round(near[0], 2), round(near[1], 2)) if near else None
    key = (city, normalize(query), limit, near_key)
    if key in _NOMINATIM_CACHE:
        return _NOMINATIM_CACHE[key]

    south, west, north, east = config.CITY_BBOX[city]
    params_dict = {
        "q": query,
        "bbox": f"{west},{south},{east},{north}",
        "limit": limit,
    }
    if near is not None:
        params_dict["lat"] = str(near[0])
        params_dict["lon"] = str(near[1])

    params = urllib.parse.urlencode(params_dict)
    request = urllib.request.Request(
        f"https://photon.komoot.io/api/?{params}",
        headers={"User-Agent": "NaVie-class-project/0.1 (OSM Photon place search)"},
    )
    try:
        with _NOMINATIM_LOCK:
            wait_seconds = 0.25 - (time.monotonic() - _LAST_NOMINATIM_REQUEST)
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
                str(properties[k]).strip()
                for k in ("housenumber", "street", "district", "city")
                if properties.get(k)
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
        geocoder.online_search = lambda query, limit, near=None: search_osm_online(
            city, query, limit, near=near
        )
    return geocoder
