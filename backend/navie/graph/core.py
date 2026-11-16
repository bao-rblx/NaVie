"""CSR graph container, save/load.

Edge semantics
--------------
Every road segment is stored in both directions so that walking can ignore
one-way rules. The per-edge ``oneway`` array says which directions are legal
for vehicles:

* ``ONEWAY_NONE`` (0): two-way road.
* ``ONEWAY_FORWARD`` (1): one-way road, this edge follows the legal direction.
* ``ONEWAY_AGAINST`` (2): synthetic reverse of a one-way road (walk only).
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from numpy.typing import NDArray

from navie import config

# Edge flag bits (docs/03_algorithms.md §1).
FLAG_MOTORWAY = 1 << 0
FLAG_MOTORCYCLE_NO = 1 << 1
FLAG_TOLL = 1 << 2
FLAG_FOOTWAY = 1 << 3  # footway / path / steps / pedestrian / cycleway
FLAG_BRIDGE = 1 << 4

ONEWAY_NONE = 0
ONEWAY_FORWARD = 1
ONEWAY_AGAINST = 2

# road_class uint8 codes = index into this tuple. Never reorder (stored in .npz).
ROAD_CLASSES: tuple[str, ...] = (
    "other",
    "motorway",
    "trunk",
    "primary",
    "secondary",
    "tertiary",
    "residential",
    "unclassified",
    "service",
    "living_street",
    "footway",
    "path",
    "pedestrian",
    "steps",
    "cycleway",
    "track",
)

EDGE_ARRAYS: tuple[str, ...] = (
    "length_m",
    "road_class",
    "maxspeed_kmh",
    "oneway",
    "flags",
    "maxweight_t",
    "maxheight_m",
    "name_id",
)


@dataclass
class Graph:
    """Directed road graph in CSR form. Out-edges of node u are ``indptr[u]:indptr[u+1]``."""

    node_lat: NDArray[np.float64]
    node_lon: NDArray[np.float64]
    indptr: NDArray[np.int32]
    indices: NDArray[np.int32]
    length_m: NDArray[np.float64]
    road_class: NDArray[np.uint8]
    maxspeed_kmh: NDArray[np.float32]  # 0 = unknown
    oneway: NDArray[np.uint8]
    flags: NDArray[np.uint8]
    maxweight_t: NDArray[np.float32]  # 0 = no limit
    maxheight_m: NDArray[np.float32]  # 0 = no limit
    name_id: NDArray[np.int32]  # -1 = unnamed
    names: list[str] = field(default_factory=list)
    version: str = "unversioned"
    bbox: tuple[float, float, float, float] | None = None  # south, west, north, east
    # Reverse (transposed) CSR, filled by build_reverse().
    rev_indptr: NDArray[np.int32] | None = None
    rev_indices: NDArray[np.int32] | None = None
    rev_edge: NDArray[np.int32] | None = None  # rev slot -> forward edge id

    @property
    def n_nodes(self) -> int:
        return int(self.node_lat.shape[0])

    @property
    def n_edges(self) -> int:
        return int(self.indices.shape[0])

    def edge_source(self) -> NDArray[np.int32]:
        """Source node of every edge (length n_edges)."""
        counts = np.diff(self.indptr)
        return np.repeat(np.arange(self.n_nodes, dtype=np.int32), counts)

    def out_edges(self, u: int) -> range:
        return range(int(self.indptr[u]), int(self.indptr[u + 1]))

    def find_edge(self, u: int, v: int) -> int:
        """Return the first edge id u -> v, or -1."""
        for e in self.out_edges(u):
            if int(self.indices[e]) == v:
                return e
        return -1

    def py_csr(self) -> tuple[list[int], list[int]]:
        """CSR as Python lists (cached). Search loops index these: much faster than numpy."""
        cached: tuple[list[int], list[int]] | None = self.__dict__.get("_py_csr")
        if cached is None:
            indptr: list[int] = [int(x) for x in self.indptr]
            indices: list[int] = [int(x) for x in self.indices]
            cached = (indptr, indices)
            self.__dict__["_py_csr"] = cached
        return cached

    def ensure_reverse(self) -> None:
        """Build the transposed CSR only if it is missing (idempotent).

        load() and build_graph() already build it, so search calls must use this
        instead of build_reverse(): rebuilding is a full argsort over every edge
        (25 ms on the HCMC graph) that would otherwise be paid on every request.
        """
        if (
            self.rev_indptr is not None
            and self.rev_indices is not None
            and self.rev_edge is not None
        ):
            return
        self.build_reverse()

    def build_reverse(self) -> None:
        """Build the transposed CSR used by bidirectional search."""
        src = self.edge_source()
        order = np.argsort(self.indices, kind="stable").astype(np.int32)
        counts = np.bincount(self.indices, minlength=self.n_nodes)
        rev_indptr = np.zeros(self.n_nodes + 1, dtype=np.int32)
        np.cumsum(counts, out=rev_indptr[1:])
        self.rev_indptr = rev_indptr
        self.rev_indices = src[order].astype(np.int32)
        self.rev_edge = order

    def validate(self) -> None:
        """Raise ValueError if arrays are inconsistent."""
        n, m = self.n_nodes, self.n_edges
        if self.node_lon.shape[0] != n or self.indptr.shape[0] != n + 1:
            raise ValueError("node array length mismatch")
        if int(self.indptr[0]) != 0 or int(self.indptr[-1]) != m:
            raise ValueError("indptr must start at 0 and end at n_edges")
        if np.any(np.diff(self.indptr) < 0):
            raise ValueError("indptr must be non-decreasing")
        if m and (self.indices.min() < 0 or self.indices.max() >= n):
            raise ValueError("edge target out of range")
        for name in EDGE_ARRAYS:
            if getattr(self, name).shape[0] != m:
                raise ValueError(f"{name} length != n_edges")
        if np.any(self.length_m < 0):
            raise ValueError("negative edge length")


def _paths(city: str, build_dir: Path | None) -> tuple[Path, Path]:
    d = build_dir or config.BUILD_DIR
    return d / f"{city}.npz", d / f"{city}_names.json"


def save(graph: Graph, city: str, build_dir: Path | None = None) -> Path:
    """Write ``{city}.npz`` + ``{city}_names.json``; returns the .npz path."""
    graph.validate()
    npz_path, names_path = _paths(city, build_dir)
    npz_path.parent.mkdir(parents=True, exist_ok=True)
    arrays = {k: getattr(graph, k) for k in ("node_lat", "node_lon", "indptr", "indices")}
    arrays.update({k: getattr(graph, k) for k in EDGE_ARRAYS})
    np.savez_compressed(npz_path, **arrays)  # type: ignore[arg-type]
    names_path.write_text(
        json.dumps({"version": graph.version, "names": graph.names}, ensure_ascii=False),
        encoding="utf-8",
    )
    return npz_path


def load(city: str, build_dir: Path | None = None) -> Graph:
    """Load a built graph and its reverse CSR. Raises FileNotFoundError if not built."""
    npz_path, names_path = _paths(city, build_dir)
    if not npz_path.exists():
        raise FileNotFoundError(f"{npz_path} missing; run `make data CITY={city}`")
    t0 = time.perf_counter()
    with np.load(npz_path) as z:
        arrays = {k: z[k] for k in z.files}
    meta = {"version": "unversioned", "names": []}
    if names_path.exists():
        meta = json.loads(names_path.read_text(encoding="utf-8"))
    graph = Graph(
        **arrays,
        names=list(meta["names"]),
        version=str(meta["version"]),
        bbox=config.CITY_BBOX.get(city),
    )
    graph.validate()
    graph.build_reverse()
    graph.load_seconds = time.perf_counter() - t0  # type: ignore[attr-defined]
    return graph
