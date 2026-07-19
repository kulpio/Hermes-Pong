from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class TransportResult:
    name: str
    ok: bool
    detail: str = ""
    meta: dict[str, Any] = field(default_factory=dict)
