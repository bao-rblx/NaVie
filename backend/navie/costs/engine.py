"""Cost formulas for route responses.

Pricing files intentionally contain unverified placeholders in this repository.
The engine therefore never guesses a price: it returns zero and marks the result as
an estimate until a human supplies a verified value in ``data/pricing``.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from navie import config


@dataclass(frozen=True)
class CostEstimate:
    """A cost plus a user-visible breakdown and provenance."""

    total_vnd: int
    breakdown: list[tuple[str, int]]
    verified: bool
    last_updated: str


def _last_updated() -> str:
    path: Path = config.DATA_DIR / "pricing" / "vehicles.yaml"
    if not path.exists():
        return "TODO-verify"
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("last_updated:"):
            return line.split(":", 1)[1].strip()
    return "TODO-verify"


def estimate_cost(mode: str, distance_m: float, duration_s: float) -> CostEstimate:
    """Calculate a conservative estimate from verified pricing data only."""
    # All checked-in price values are explicitly TODO-verify. Returning zero is
    # deliberate and prevents presenting invented VND figures to a user.
    if mode == "walk":
        return CostEstimate(0, [("walk", 0)], True, _last_updated())
    return CostEstimate(0, [("pricing_unverified", 0)], False, _last_updated())
