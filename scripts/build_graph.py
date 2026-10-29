"""Download OSM roads for a city and build the CSR graph (T-02, docs/04 §2).

Usage: python scripts/build_graph.py --city hcmc [--force]

Outputs data/raw/{city}.graphml (cached download) and data/build/{city}.npz +
{city}_names.json. osmnx is used only to download and simplify the road network;
all routing uses our own code in navie/search.
"""

from __future__ import annotations

import argparse
import datetime as dt
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from navie import config  # noqa: E402
from navie.graph.build import EdgeRecord, build_graph  # noqa: E402
from navie.graph.core import save  # noqa: E402

TAGS = ["motorcycle", "toll", "bridge", "maxweight", "maxheight"]


def download(city: str, force: bool):  # type: ignore[no-untyped-def]
    import osmnx as ox

    raw = config.RAW_DIR / f"{city}.graphml"
    if raw.exists() and not force:
        print(f"using cached {raw}")
        return ox.load_graphml(raw)
    south, west, north, east = config.CITY_BBOX[city]
    ox.settings.useful_tags_way = list(set(ox.settings.useful_tags_way) | set(TAGS))
    print(f"downloading OSM roads for {city} bbox={config.CITY_BBOX[city]} ...")
    G = ox.graph_from_bbox((west, south, east, north), network_type="all", simplify=True)
    raw.parent.mkdir(parents=True, exist_ok=True)
    ox.save_graphml(G, raw)
    return G


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--city", default="hcmc", choices=sorted(config.CITY_BBOX))
    ap.add_argument("--force", action="store_true", help="re-download even if cached")
    args = ap.parse_args()

    G = download(args.city, args.force)
    node_ids = list(G.nodes)
    lat = [float(G.nodes[n]["y"]) for n in node_ids]
    lon = [float(G.nodes[n]["x"]) for n in node_ids]
    edges = []
    for u, v, d in G.edges(data=True):
        edges.append(
            EdgeRecord(
                u=u,
                v=v,
                length_m=float(d.get("length", 0.0)),
                highway=d.get("highway"),
                # osmnx adds both directions for two-way roads; oneway=True marks one-way ones.
                oneway=str(d.get("oneway", False)).lower() == "true",
                maxspeed=d.get("maxspeed"),
                name=d.get("name"),
                motorcycle=d.get("motorcycle"),
                toll=d.get("toll"),
                bridge=d.get("bridge"),
                maxweight=d.get("maxweight"),
                maxheight=d.get("maxheight"),
            )
        )
    version = f"{args.city}-{dt.date.today().isoformat()}"
    graph = build_graph(node_ids, lat, lon, edges, version=version)
    path = save(graph, args.city)
    print(f"wrote {path}: {graph.n_nodes} nodes, {graph.n_edges} edges ({version})")


if __name__ == "__main__":
    main()
