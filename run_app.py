"""One-click standalone launcher for NaVie.

Starts FastAPI with the embedded web app and opens the browser.
"""

from __future__ import annotations

import os
import sys
import threading
import time
import webbrowser
from pathlib import Path

# Determine app root
if getattr(sys, "frozen", False):
    # Running from PyInstaller bundle
    APP_ROOT = Path(sys.executable).parent.resolve()
else:
    # Running from source
    APP_ROOT = Path(__file__).resolve().parent

# Ensure backend directory is in sys.path
backend_dir = APP_ROOT / "backend"
if backend_dir.is_dir() and str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

# Configure data directory
data_dir = APP_ROOT / "data"
os.environ["NAVIE_DATA_DIR"] = str(data_dir)

# Import app components
import uvicorn
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from navie.main import create_app

app = create_app()

# Mount the static web app
web_app_dir = APP_ROOT / "app" / "web_app"
if web_app_dir.is_dir():
    app.mount("/app", StaticFiles(directory=str(web_app_dir), html=True), name="web_app")

    @app.get("/", include_in_schema=False)
    def root() -> RedirectResponse:
        return RedirectResponse(url="/app/")


def open_browser() -> None:
    time.sleep(1.2)
    url = "http://127.0.0.1:8000/app/"
    print(f"\nOpening browser at {url} ...")
    webbrowser.open(url)


if __name__ == "__main__":
    print("=" * 60)
    print("  NaVie - Vietnam Multimodal Route Planner & Driver App")
    print("=" * 60)
    print(f"App Root: {APP_ROOT}")
    print(f"Data Directory: {data_dir}")
    print(f"Web Client: {web_app_dir}")
    print("Starting server on http://127.0.0.1:8000 ...")
    print("Press Ctrl+C in this terminal window to stop the server.")
    print("=" * 60)

    # Don't auto-open browser if --no-browser flag is passed (e.g. for testing)
    if "--no-browser" not in sys.argv:
        threading.Thread(target=open_browser, daemon=True).start()

    uvicorn.run(app, host="127.0.0.1", port=8000, log_level="info")
