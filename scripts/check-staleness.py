#!/usr/bin/env python3
"""
Oracle staleness checker. Called by git post-commit hook with changed file paths as args.
Updates .product-oracle/.staleness.json to mark affected docs as stale.
"""
import json
import os
import sys
from datetime import datetime, timezone

STALENESS_PATH = ".product-oracle/.staleness.json"


def main():
    changed_files = sys.argv[1:]
    if not changed_files:
        sys.exit(0)

    if not os.path.exists(STALENESS_PATH):
        sys.exit(0)

    try:
        with open(STALENESS_PATH, "r") as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"Oracle: warning — could not read {STALENESS_PATH}: {e}", file=sys.stderr)
        sys.exit(0)

    documents = data.get("documents", {})
    changed_set = set(changed_files)
    stale_now = []

    for doc_path, meta in documents.items():
        if meta.get("stale"):
            continue  # already marked stale

        source_files = set(meta.get("sourceFiles", []))
        overlap = source_files & changed_set

        if overlap:
            meta["stale"] = True
            meta["stale_since"] = datetime.now(timezone.utc).isoformat()
            meta["stale_reason"] = sorted(overlap)
            stale_now.append((doc_path, len(overlap)))

    if not stale_now:
        print("Oracle: all docs up to date")
        sys.exit(0)

    try:
        with open(STALENESS_PATH, "w") as f:
            json.dump(data, f, indent=2)
    except IOError as e:
        print(f"Oracle: warning — could not write {STALENESS_PATH}: {e}", file=sys.stderr)
        sys.exit(0)

    parts = []
    for doc_path, count in stale_now:
        name = os.path.basename(doc_path)
        parts.append(f"{name} ({count} source file{'s' if count != 1 else ''} changed)")

    print(f"Oracle: {len(stale_now)} doc{'s' if len(stale_now) != 1 else ''} marked stale: {', '.join(parts)}")


if __name__ == "__main__":
    main()
