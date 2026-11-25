"""Package a single-threaded Godot Web export for itch.io."""

import argparse
import re
from pathlib import Path
from tempfile import TemporaryDirectory
from zipfile import ZIP_DEFLATED, ZipFile

REQUIRED = {
    "index.html",
    "index.js",
    "index.pck",
    "index.wasm",
    "playgama-bridge.js",
    "playgama-bridge-config.json",
    "playgama-bridge-LICENSE.txt",
}


def package(export: Path, archive: Path) -> None:
    export = export.resolve()
    archive = archive.resolve()
    if archive.is_relative_to(export):
        raise ValueError("Write the ZIP outside the Web export directory.")
    files = sorted(path for path in export.rglob("*") if path.is_file())
    names = {path.relative_to(export).as_posix() for path in files}
    missing = REQUIRED - names
    if missing:
        raise ValueError("Missing Web export files: " + ", ".join(sorted(missing)))
    if len(files) >= 1000:
        raise ValueError("The itch.io build must contain fewer than 1,000 files.")
    shell = (export / "index.html").read_text(encoding="utf-8")
    if not re.search(r"\bGODOT_THREADS_ENABLED\s*=\s*false\s*;", shell):
        raise ValueError("Export the Web preset with thread support disabled.")

    archive.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=archive.parent) as staging:
        temporary = Path(staging) / archive.name
        with ZipFile(temporary, "w", ZIP_DEFLATED, compresslevel=6) as zf:
            for path in files:
                zf.write(path, path.relative_to(export))
        temporary.replace(archive)
    print(f"{archive.name}: {len(files)} files, {archive.stat().st_size:,} bytes")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export", type=Path)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    try:
        package(args.export, args.archive)
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
