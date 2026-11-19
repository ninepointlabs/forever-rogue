#!/usr/bin/env python3
"""Merge research/parts/{core,gear,rogue}.json into research/data.json."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
out = {}
for name in ("core", "gear", "rogue"):
    part = json.loads((HERE / "parts" / f"{name}.json").read_text(encoding="utf-8"))
    for k, v in part.items():
        if k in ("gaps", "conflicts") and k in out:
            out[k] = list(out[k]) + list(v)
        elif k == "sources" and k in out:
            out[k] = {**out[k], **v}
        elif k in out:
            raise SystemExit(f"merge: key {k!r} in two parts ({name})")
        else:
            out[k] = v
(HERE / "data.json").write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
print("wrote research/data.json:", ", ".join(f"{k}={len(v) if hasattr(v, '__len__') else v}" for k, v in out.items()))
