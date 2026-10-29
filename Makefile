# NaVie — top-level commands (see AGENTS.md "Commands").
# On Windows, run from Git Bash with GNU make installed (winget install GnuWin32.Make).

PY ?= python
BACKEND := backend
CITY ?= hcmc
HAS_FLUTTER := $(shell command -v flutter 2>/dev/null)

.PHONY: setup data run test bench lint

setup:
	cd $(BACKEND) && $(PY) -m pip install -e ".[dev,data]"
ifdef HAS_FLUTTER
	cd app && flutter pub get
else
	@echo "flutter not found: skipping app setup"
endif

data:
	cd $(BACKEND) && $(PY) ../scripts/build_graph.py --city $(CITY)

run:
	cd $(BACKEND) && $(PY) -m uvicorn navie.main:app --port 8000 --reload

test:
	cd $(BACKEND) && $(PY) -m pytest
ifdef HAS_FLUTTER
	cd app && flutter test
else
	@echo "flutter not found: skipping app tests"
endif

bench:
	@echo "bench: not implemented yet (T-10)"

lint:
	cd $(BACKEND) && $(PY) -m ruff check . ../scripts && $(PY) -m ruff format --check . ../scripts && $(PY) -m mypy navie
ifdef HAS_FLUTTER
	cd app && flutter analyze
else
	@echo "flutter not found: skipping flutter analyze"
endif
