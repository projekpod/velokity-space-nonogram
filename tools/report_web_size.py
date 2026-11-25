"""Report the complete Web artifact size and enforce the portal limit."""

import sys
from pathlib import Path

output = Path(sys.argv[1])
files = [path for path in output.rglob("*") if path.is_file()]
if not all((output / f"index.{extension}").is_file() for extension in ("html", "wasm", "pck")):
    raise SystemExit("Incomplete Web export")
total = sum(path.stat().st_size for path in files)
print(f"Web export: {total:,} bytes ({total / 1_000_000:.2f} MB), {len(files)} files")
if total > 50_000_000:
    raise SystemExit("Web export exceeds the 50 MB limit")
