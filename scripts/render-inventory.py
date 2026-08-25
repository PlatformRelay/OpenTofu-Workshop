#!/usr/bin/env python3
"""Inventory backslashes and collapsed cells in the RENDERED claims page.

A source-side checker cannot see this defect class by construction: a Markdown
cell can match the file it quotes exactly and still publish wrongly, because
Python-Markdown does not process backslash escapes inside a code span. The only
instrument that sees it is the built page.

This prints an INVENTORY, never a bare count. A count is what let a real defect
ship: an earlier revision expected "1 escape line", measured exactly 1, and was
green while docs/claims-verification.md:418 was broken -- the single sanctioned
exception absorbed the new defect. A list cannot do that, because an unfamiliar
entry appearing is itself the signal.

Usage:
    mkdocs build --strict
    python3 scripts/render-inventory.py [site/claims-verification/index.html]

Exit: 0 when the inventory matches the documented expectation, 1 otherwise.
"""
import html
import pathlib
import re
import sys

DEFAULT = "site/claims-verification/index.html"

# Rendered <code> contents that legitimately contain a backslash. Keep this
# SHORT and justify every entry in docs/claims-verification.md. Anything not
# listed here is a defect, not a new exception to add.
ALLOWED_CODE = {
    r"\.",   # regex fragments quoting an escaped dot, e.g. the sweep patterns
}


def main() -> int:
    target = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else DEFAULT)
    if not target.exists():
        print(f"render-inventory: {target} not found -- run mkdocs build first")
        return 1

    doc = target.read_text(encoding="utf-8")

    empty_cells = len(re.findall(r"<td>\s*</td>", doc))

    findings = []
    for m in re.finditer(r"<code[^>]*>(.*?)</code>", doc, re.S):
        text = html.unescape(m.group(1))
        if "\\" not in text:
            continue
        if any(tok in text for tok in ALLOWED_CODE):
            continue
        line = doc.count("\n", 0, m.start()) + 1
        findings.append((line, text.strip().replace("\n", " ")[:100]))

    print(f"render-inventory: {target}")
    print(f"  empty table cells: {empty_cells}   (must be 0)")
    print(f"  <code> elements carrying an unexpected backslash: {len(findings)}   (must be 0)")
    for line, text in findings:
        print(f"    line {line}: {text!r}")

    if empty_cells or findings:
        print("render-inventory: FAIL -- see the list above; do not widen "
              "ALLOWED_CODE without justifying the entry in the doc")
        return 1
    print("render-inventory: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
