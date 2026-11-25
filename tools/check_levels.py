"""Check that every shipped puzzle is covered by a validator."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    for mode in ("levels", "daily"):
        files = sorted((ROOT / "data" / mode).glob("*.json"))
        if files:
            raise SystemExit(f"{mode}: {len(files)} puzzle files lack a uniqueness validator.")
        print(f"{mode}: no puzzles yet")


if __name__ == "__main__":
    main()
