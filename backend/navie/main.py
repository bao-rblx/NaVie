"""FastAPI app factory."""

from __future__ import annotations

from fastapi import FastAPI

from navie import __version__


def create_app() -> FastAPI:
    """Build the NaVie API. Routes beyond /health arrive in T-12."""
    app = FastAPI(title="NaVie", version=__version__)

    @app.get("/health")
    def health() -> dict[str, object]:
        return {"status": "ok", "version": __version__, "llm_available": False}

    return app


app = create_app()
