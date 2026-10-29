"""Paths and environment settings."""

from __future__ import annotations

import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = Path(os.environ.get("NAVIE_DATA_DIR", REPO_ROOT / "data"))
RAW_DIR = DATA_DIR / "raw"
BUILD_DIR = DATA_DIR / "build"

# Bounding boxes (south, west, north, east) from docs/04_data_and_costs.md §1.
CITY_BBOX: dict[str, tuple[float, float, float, float]] = {
    "hcmc": (10.70, 106.60, 10.88, 106.80),
    "hanoi": (20.95, 105.75, 21.10, 105.90),
}
