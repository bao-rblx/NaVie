"""Error model shared by the API (docs/02_architecture.md §4)."""

from __future__ import annotations

from typing import Literal

ErrorCode = Literal[
    "NO_PATH",
    "OUT_OF_COVERAGE",
    "VALIDATION",
    "LLM_UNAVAILABLE",
    "NOT_IMPLEMENTED",
]


class NavieError(Exception):
    """Domain error carrying a code and bilingual messages."""

    def __init__(self, code: ErrorCode, message_vi: str, message_en: str) -> None:
        super().__init__(message_en)
        self.code = code
        self.message_vi = message_vi
        self.message_en = message_en

    def to_dict(self) -> dict[str, dict[str, str]]:
        return {
            "error": {
                "code": self.code,
                "message_vi": self.message_vi,
                "message_en": self.message_en,
            }
        }


def out_of_coverage() -> NavieError:
    return NavieError(
        "OUT_OF_COVERAGE",
        "Vị trí nằm ngoài vùng bản đồ được hỗ trợ.",
        "Location is outside the supported map area.",
    )


def not_implemented(name: str) -> NavieError:
    """Raise for an algorithm label the API advertises but does not implement yet.

    Never fall back to a different algorithm: ``stats.algorithm`` must only ever name
    the algorithm that actually ran.
    """
    return NavieError(
        "NOT_IMPLEMENTED",
        f"Thuật toán {name} chưa được hỗ trợ.",
        f"The {name} algorithm is not implemented yet.",
    )
