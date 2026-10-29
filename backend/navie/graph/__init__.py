"""Road graph: CSR arrays + loader (docs/03_algorithms.md §1)."""

from navie.graph.core import (
    FLAG_BRIDGE,
    FLAG_FOOTWAY,
    FLAG_MOTORCYCLE_NO,
    FLAG_MOTORWAY,
    FLAG_TOLL,
    ONEWAY_AGAINST,
    ONEWAY_FORWARD,
    ONEWAY_NONE,
    ROAD_CLASSES,
    Graph,
    load,
    save,
)

__all__ = [
    "FLAG_BRIDGE",
    "FLAG_FOOTWAY",
    "FLAG_MOTORCYCLE_NO",
    "FLAG_MOTORWAY",
    "FLAG_TOLL",
    "ONEWAY_AGAINST",
    "ONEWAY_FORWARD",
    "ONEWAY_NONE",
    "ROAD_CLASSES",
    "Graph",
    "load",
    "save",
]
