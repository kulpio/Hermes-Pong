#!/usr/bin/env python3
"""Legacy entrypoint → pong gate."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))
from pong.cli.main import main

raise SystemExit(main(["gate", *sys.argv[1:]]))
