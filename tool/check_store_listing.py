"""Validate STORE_LISTING.md against the consoles' hard character limits.

Both stores truncate or reject silently depending on the field, and a
listing edit after publishing goes back through review — so the copy is
worth checking before it is pasted, not after.

Also flags replacement characters (U+FFFD), which is what a mangled
non-ASCII paste leaves behind and which is invisible in a diff. That is not
hypothetical: it is how two corrupted words got into the Ukrainian
description and survived a read-through.

Run from anywhere:

    python tool/check_store_listing.py

Exits non-zero if anything is over limit or mangled, so it can go in a hook.
"""

import pathlib
import re
import sys

# Relative to this file, so the script works on whatever machine has the
# repo checked out — the Mac used for iOS builds included.
DOC = pathlib.Path(__file__).resolve().parent.parent / "STORE_LISTING.md"

LIMITS = {
    "App name": 30,
    "Subtitle": 30,
    "Short description": 80,
    "Promotional text": 170,
    "Keywords": 100,
    "Full description": 4000,
}

# **Field name** (optional parenthetical), then a fenced block.
BLOCK = re.compile(
    r"^\*\*(?P<field>[A-Za-z ]+?)\*\*(?: \([^)]*\))?\s*\n```\n(?P<body>.*?)\n```",
    re.MULTILINE | re.DOTALL,
)

SECTION = re.compile(r"^## (.+)$", re.MULTILINE)


def main() -> int:
    if not DOC.exists():
        print(f"not found: {DOC}")
        return 2

    text = DOC.read_text(encoding="utf-8")

    # Which locale heading each match falls under.
    headings = [(m.start(), m.group(1)) for m in SECTION.finditer(text)]

    def locale_at(pos: int) -> str:
        name = "?"
        for start, title in headings:
            if start < pos:
                name = title
            else:
                break
        return name

    failures = 0
    checked = 0

    for m in BLOCK.finditer(text):
        field = m.group("field")
        body = m.group("body")
        limit = LIMITS.get(field)
        if limit is None:
            continue

        checked += 1
        where = f"{locale_at(m.start()):<12} {field:<18}"
        n = len(body)

        if "�" in body:
            print(f"MANGLED  {where} contains U+FFFD replacement chars")
            failures += 1
            continue

        if n > limit:
            print(f"TOO LONG {where} {n}/{limit} (+{n - limit})")
            failures += 1
        else:
            headroom = limit - n
            flag = "tight" if headroom <= 3 else ""
            print(f"ok       {where} {n}/{limit} {flag}")

    print(f"\n{checked} fields checked, {failures} problem(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
