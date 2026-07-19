#!/usr/bin/env python3
"""Legacy entrypoint → pong delegate (job + transports)."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))

# Map old flags: remaining args after script name
args = ["delegate", *sys.argv[1:]]
from pong.cli.main import main

raise SystemExit(main(args))
