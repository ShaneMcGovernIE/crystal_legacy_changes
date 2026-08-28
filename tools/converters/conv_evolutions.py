#!/usr/bin/env python3
"""conv_evolutions.py — CL data/pokemon/evos_attacks.asm -> evolutions.lua
(dev-side, never shipped).

Parses the Crystal Legacy evolution source:
  - data/pokemon/evos_attacks.asm   -> per-species EVOLVE_* row lists
  - constants/pokemon_data_constants.asm -> EVOLVE_*/TR_*/ATK_* id mapping

Output: a plain data table of *changed* species carrying their FULL CL
evolution lists (the engine's pokemon registry is record-semantics: list
fields like `evolutions` REPLACE wholesale on patch, so every emitted species
must carry the complete CL list, not just changed rows).

Row shape (matches gold data/generated/pokemon.lua):
    { into = "STEELIX", item = "METAL_COAT", method = "EVOLVE_ITEM" }
    { into = "ALAKAZAM", level = 42, method = "EVOLVE_LEVEL" }
    { into = "ESPEON", method = "EVOLVE_HAPPINESS", time = "MORNDAY" }
    { into = "HITMONCHAN", level = 20, comparison = "ATK_LT_DEF", method = "EVOLVE_STAT" }

Diff vs gold generated/pokemon.lua evolutions (optional 3rd arg): species are
emitted only when their CL list differs from the gold baseline.

Usage:
    python3 conv_evolutions.py CL_SOURCE_DIR OUT_LUA [GOLD_POKEMON_LUA]
"""
import re
import sys
from pathlib import Path

EVOLVE_LEVEL, EVOLVE_ITEM, EVOLVE_TRADE, EVOLVE_HAPPINESS, EVOLVE_STAT = (
    "EVOLVE_LEVEL", "EVOLVE_ITEM", "EVOLVE_TRADE", "EVOLVE_HAPPINESS", "EVOLVE_STAT",
)
TIME_MAP = {"TR_ANYTIME": "ANYTIME", "TR_MORNDAY": "MORNDAY", "TR_NITE": "NITE"}
# CL asm label -> gold registry key normalization
SPECIES_ALIAS = {"NIDORANF": "NIDORAN_F", "NIDORANM": "NIDORAN_M"}


def parse_evos(asm_path: Path) -> dict[str, list[dict]]:
    """Return { SPECIES: [row, ...] } with row keys matching gold pokemon.lua."""
    src = asm_path.read_text()
    out = {}
    # blocks: \nSpeciesEvosAttacks: ... up to the next label at column 0
    for m in re.finditer(
        r"^(\w+?)EvosAttacks:\s*\n(.*?)(?=^\w+?EvosAttacks:\s*$|\Z)",
        src, re.M | re.S,
    ):
        species = m.group(1).upper()
        rows = []
        for line in m.group(2).splitlines():
            line = line.split(";")[0].strip()
            mm = re.match(r"^db\s+(.+)$", line)
            if not mm:
                continue
            toks = [t.strip() for t in mm.group(1).split(",")]
            if toks == ["0"]:
                break  # terminator
            if not toks:
                continue
            method = toks[0]
            if method == EVOLVE_LEVEL:
                rows.append({"into": toks[2], "level": int(toks[1]), "method": method})
            elif method == EVOLVE_ITEM:
                rows.append({"into": toks[2], "item": toks[1], "method": method})
            elif method == EVOLVE_TRADE:
                row = {"into": toks[2], "method": method}
                if len(toks) > 3:
                    row["item"] = toks[1]
                rows.append(row)
            elif method == EVOLVE_HAPPINESS:
                rows.append({"into": toks[2], "method": method, "time": TIME_MAP[toks[1]]})
            elif method == EVOLVE_STAT:
                rows.append({
                    "into": toks[3], "level": int(toks[1]),
                    "comparison": toks[2], "method": method,
                })
            else:
                print(f"WARN: unknown method {method} in {species}")
        out[species] = rows
    return out


def canonical(row: dict) -> tuple:
    """Order-independent signature for diffing (key order varies gold/CL)."""
    return tuple(sorted(row.items()))


def gold_evolutions(gold_pokemon_lua: Path) -> dict[str, list[dict]]:
    """Extract { SPECIES: [row, ...] } evolutions from gold generated/pokemon.lua."""
    src = gold_pokemon_lua.read_text()
    out = {}
    # species block:  \n  SPECIES = {\n ... \n  },\n (2-space indent)
    for m in re.finditer(r'^  (\w+) = \{\n(.*?)(?=^  \w+ = \{|\Z)', src, re.M | re.S):
        species = m.group(1)
        body = m.group(2)
        # handle empty inline `evolutions = {},` vs multi-line list
        m0 = re.search(r"evolutions\s*=\s*\{\s*\},", body)
        if m0:
            out[species] = []
            continue
        mm = re.search(r"evolutions\s*=\s*\{(.*?)\n    \},", body, re.S)
        if not mm:
            out[species] = []
            continue
        # inner rows are `      { ... },` chunks (6-space); split by brace depth
        inner = mm.group(1)
        chunks = []
        depth = 0
        chunk = []
        for line in inner.splitlines():
            if "{" in line:
                depth += line.count("{")
            chunk.append(line)
            if "}" in line:
                depth -= line.count("}")
                if depth == 0:
                    chunks.append("\n".join(chunk))
                    chunk = []
        rows = []
        for r in re.finditer(
            r"\{\s*((?:[a-zA-Z]+\s*=\s*(?:\"[^\"]*\"|\d+)\s*,\s*)*)\}", "\n".join(chunks)
        ):
            row = {}
            for kv in re.finditer(r"([a-zA-Z]+)\s*=\s*(\"[^\"]*\"|\d+)", r.group(1)):
                k, v = kv.group(1), kv.group(2)
                row[k] = v.strip('"') if v.startswith('"') else int(v)
            if row:
                rows.append(row)
        out[species] = rows
    return out


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    cl_dir = Path(sys.argv[1])
    out_path = Path(sys.argv[2])
    gold_lua = Path(sys.argv[3]) if len(sys.argv) > 3 else None

    all_evos = parse_evos(cl_dir / "data" / "pokemon" / "evos_attacks.asm")
    # normalize CL species keys to gold registry keys
    all_evos = {SPECIES_ALIAS.get(k, k): v for k, v in all_evos.items()}
    print(f"CL species with evolutions: {len(all_evos)}")

    if gold_lua:
        gold = gold_evolutions(gold_lua)
        print(f"gold species with evolutions: {len(gold)}")
        diff = {}
        for sp, rows in all_evos.items():
            gold_rows = gold.get(sp)
            gold_sig = {canonical(r) for r in gold_rows} if gold_rows else set()
            cl_sig = {canonical(r) for r in rows}
            if gold_sig != cl_sig:
                diff[sp] = rows
        # also catch species present in gold but absent in CL (none expected)
        print(f"diff species: {len(diff)}")
        for sp in sorted(diff):
            print(f"  {sp}: gold={len(gold.get(sp, []))} rows -> CL={len(diff[sp])} rows")
    else:
        diff = all_evos
        print("no gold baseline given; emitting ALL species")

    # ---- emit ----
    lines = [
        "-- Generated by tools/converters/conv_evolutions.py (dev-side; not shipped).",
        "-- Source: Crystal Legacy data/pokemon/evos_attacks.asm",
        "-- FULL CL evolution lists for changed species (pokemon=record semantics:",
        "-- evolutions list replaces wholesale on patch).",
        "-- Rows: { into, item|level|time|comparison (per method), method }",
        "return {",
        "  evolutions = {",
    ]
    for sp in sorted(diff):
        rows = diff[sp]
        lines.append(f"    {sp} = {{")
        for r in rows:
            parts = []
            for k in ("into", "item", "level", "time", "comparison", "method"):
                if k in r:
                    v = r[k]
                    if isinstance(v, int):
                        parts.append(f"{k} = {v}")
                    else:
                        parts.append(f'{k} = "{v}"')
            lines.append(f"      {{ {', '.join(parts)} }},")
        lines.append("    },")
    lines.append("  },")
    lines.append("}")
    out_path.write_text("\n".join(lines) + "\n")

    total_rows = sum(len(rows) for rows in diff.values())
    print(f"wrote {out_path}: {len(diff)} species, {total_rows} evolution rows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
