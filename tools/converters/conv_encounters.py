#!/usr/bin/env python3
"""Convert CL (Pokemon Crystal Legacy) wild-encounter asm into the engine's
encounters.lua data shape (Gold gen2Encounters).

Source (read-only):  $CL_SOURCE/data/wild/*.asm  (default ~/dev/CL_source)
Output:              data/encounters.lua  (plain Lua table, sandbox-clean)

Output shape matches the engine's data.gen2Encounters record, keyed by
encounter kind first and map second (see src/mods/Schemas.lua gen2Keys):
  grass/swarmGrass: { [MAP] = { map, rates = {MORN,DAY,NITE}, slots = {MORN=[7],DAY=[7],NITE=[7]} } }
  water/swarmWater: { [MAP] = { map, rate, slots = [3] } }
  fishGroups:       { [FISHGROUP_X] = { id, index, chance, old, good, super } }  (rods: [{chance,level,species}])
  trees/rocks:      { [MAP] = "TREEMON_SET_X" }
  treeSets:         { ["TREEMON_SET_X"] = { common, rare } }  (slots: {chance,level,species})
  bugContest:       [ {chance,species,min,max} ]  (terminator row included, chance=255)
  roamMaps:         [ {map, to=[...]} ]

CL is Crystal-based; the asm grammar (RGBDS) differs from Gold's pokecrystal:
  - grass blocks:  def_grass_wildmons MAP / rate line / ;morn ;day ;nite 7-row tables / end_grass_wildmons
  - swarm blocks:  map_id MAP (no def_ macro) ... terminated by `db -1 ; end`
  - water blocks:  def_water_wildmons MAP / rate line / 3 rows / end_water_wildmons
  - fish:          fishgroup N percent + 1, .Label_Old, .Label_Good, .Label_Super  then `.Label:` tables
  - trees:         TreeMonSet_X: label, common rows, db -1, rare rows, db -1
  - maps:          treemon_map MAP, TREEMON_SET_X  (pointer-free; map_id macro used by engine)
  - contest:       db chance, SPECIES, min, max ... db -1 terminator (kept, chance=255)
  - roam:          roam_map START, TO1, TO2... (macro; engine reads db -1 terminator)

Percent encoding (engine stores raw bytes):
  `N percent`      -> N*255//100
  `N percent + 1`  -> N*255//100 + 1
  plain `db N`     -> N
"""
import os
import re
import sys
from pathlib import Path

WILD_DIR = Path(os.environ.get("CL_SOURCE", str(Path.home() / "dev" / "CL_source"))) / "data" / "wild"
OUT = Path(__file__).resolve().parent.parent.parent / "data" / "encounters.lua"

# ---------------------------------------------------------------- helpers

def pct(expr: str) -> int:
    """Evaluate an asm expression like `50 percent + 1`, `100 percent`, `90`,
    `-1` to the raw byte the engine stores.  `-1` is the 0xff terminator."""
    expr = expr.strip()
    if expr == "-1":
        return 255
    m = re.fullmatch(r"(\d+)\s*percent(?:\s*\+\s*1)?", expr)
    if m:
        return int(m.group(1)) * 255 // 100 + (1 if "+" in expr else 0)
    return int(expr)


def read_db_rows(body: str):
    """Yield (fields...) for each `db a, b, c...` line (raw tokens)."""
    for line in body.splitlines():
        line = line.split(";")[0].strip()
        if not line.startswith("db"):
            continue
        rest = line[2:].strip().rstrip(",")
        if not rest:
            continue
        yield [tok.strip() for tok in rest.split(",")]


def species_name(tok: str) -> str:
    """Species token -> Lua string. `time_group N` rows are the 0-species
    sentinel (engine resolves level via TimeFishGroups at runtime)."""
    if tok.startswith("time_group"):
        return "0"
    return f'"{tok}"'


def luakey(name: str) -> str:
    """Bare-identifier Lua key when safe (matches the engine's writer style)."""
    return name if re.fullmatch(r"[A-Za-z_]\w*", name) else f'["{name}"]'


# ---------------------------------------------------------------- sections

def parse_grass(files, out):
    """def_grass_wildmons MAP ... end_grass_wildmons blocks (johto/kanto)."""
    for f in files:
        src = (WILD_DIR / f).read_text()
        # blocks: def_grass_wildmons MAP \n ... end_grass_wildmons
        for m in re.finditer(
            r"def_grass_wildmons\s+(\w+)\n(.*?)end_grass_wildmons", src, re.S
        ):
            mapname = m.group(1)
            body = m.group(2)
            rates = {}
            for line in body.splitlines():
                mm = re.search(r"db\s+(.*?); encounter rates", line)
                if mm:
                    r = [pct(x) for x in mm.group(1).split(",")]
                    rates = {"MORN": r[0], "DAY": r[1], "NITE": r[2]}
                    break
            slots = {"MORN": [], "DAY": [], "NITE": []}
            cur = None
            for line in body.splitlines():
                mm = re.search(r";\s*(morn|day|nite)\b", line)
                if mm:
                    cur = mm.group(1).upper()
                    continue
                line = line.split(";")[0].strip()
                if not line.startswith("db"):
                    continue
                parts = [t.strip() for t in line[2:].strip().split(",")]
                if len(parts) == 2 and cur:
                    slots[cur].append(
                        {"level": int(parts[0]), "species": species_name(parts[1])}
                    )
            out[mapname] = {
                "map": mapname,
                "rates": rates,
                "slots": slots,
            }
    return out


def parse_swarm_grass(files, out):
    """map_id MAP blocks with the same 3x7 shape, terminated `db -1 ; end`."""
    for f in files:
        src = (WILD_DIR / f).read_text()
        # a swarm block starts at map_id MAP, ends at `db -1` (or next map_id)
        for m in re.finditer(
            r"map_id\s+(\w+)\n(.*?)(?=\n\s*map_id\s+\w+|\n\s*db\s+-1)", src, re.S
        ):
            mapname = m.group(1)
            body = m.group(2)
            rates = {}
            for line in body.splitlines():
                mm = re.search(r"db\s+(.*?); encounter rates", line)
                if mm:
                    r = [pct(x) for x in mm.group(1).split(",")]
                    rates = {"MORN": r[0], "DAY": r[1], "NITE": r[2]}
                    break
            slots = {"MORN": [], "DAY": [], "NITE": []}
            cur = None
            for line in body.splitlines():
                mm = re.search(r";\s*(morn|day|nite)\b", line)
                if mm:
                    cur = mm.group(1).upper()
                    continue
                line = line.split(";")[0].strip()
                if not line.startswith("db"):
                    continue
                parts = [t.strip() for t in line[2:].strip().split(",")]
                if len(parts) == 2 and cur:
                    slots[cur].append(
                        {"level": int(parts[0]), "species": species_name(parts[1])}
                    )
            out[mapname] = {
                "map": mapname,
                "rates": rates,
                "slots": slots,
            }
    return out


def parse_water(files, out):
    """def_water_wildmons MAP ... end_water_wildmons blocks."""
    for f in files:
        src = (WILD_DIR / f).read_text()
        for m in re.finditer(
            r"def_water_wildmons\s+(\w+)\n(.*?)end_water_wildmons", src, re.S
        ):
            mapname = m.group(1)
            body = m.group(2)
            rate = None
            slots = []
            for line in body.splitlines():
                line = line.split(";")[0].strip()
                if not line.startswith("db"):
                    continue
                parts = [t.strip() for t in line[2:].strip().split(",")]
                if len(parts) == 1 and rate is None:
                    rate = pct(parts[0])
                elif len(parts) == 2:
                    slots.append(
                        {"level": int(parts[0]), "species": species_name(parts[1])}
                    )
            out[mapname] = {"map": mapname, "rate": rate, "slots": slots}
    return out


def parse_fish(out):
    """fish.asm: fishgroup headers + .Label_Old/.Good/.Super tables.

    CL group order matches Gold's fishGroupOrder (SHORE..QWILFISH_NO_SWARM),
    so index/name follow the engine's constants; `time_group N` rows become
    species=0, level=N (engine fills the level from TimeFishGroups).
    """
    src = (WILD_DIR / "fish.asm").read_text()
    names = [
        "FISHGROUP_SHORE", "FISHGROUP_OCEAN", "FISHGROUP_LAKE", "FISHGROUP_POND",
        "FISHGROUP_DRATINI", "FISHGROUP_QWILFISH_SWARM", "FISHGROUP_REMORAID_SWARM",
        "FISHGROUP_GYARADOS", "FISHGROUP_DRATINI_2", "FISHGROUP_WHIRL_ISLANDS",
        "FISHGROUP_QWILFISH", "FISHGROUP_REMORAID", "FISHGROUP_QWILFISH_NO_SWARM",
    ]
    # (chance, old_label, good_label, super_label) per fishgroup row
    headers = []
    for line in src.splitlines():
        line = line.split(";")[0].strip()
        if line.startswith("fishgroup "):
            toks = [t.strip() for t in line[len("fishgroup "):].split(",")]
            headers.append((pct(toks[0]), toks[1].lstrip("."), toks[2].lstrip("."), toks[3].lstrip(".")))
    # collect rod tables: label (without leading dot) -> rows, only in the
    # block between `FishGroups:` and `TimeFishGroups:` (the latter holds
    # day/nite pairs, not rod rows).
    body = src.split("TimeFishGroups:", 1)[0]
    rods = {}
    cur_label = None
    for line in body.splitlines():
        line = line.split(";")[0].strip()
        ml = re.match(r"\.(\w+):", line)
        if ml:
            cur_label = ml.group(1)
            rods.setdefault(cur_label, [])
            continue
        if line.startswith("db") and cur_label:
            toks = [t.strip() for t in line[2:].strip().split(",")]
            # db chance, SPECIES, level   OR   db chance, time_group N, ...
            chance = pct(toks[0])
            if toks[1].startswith("time_group"):
                rods[cur_label].append(
                    {"chance": chance, "level": int(toks[1].split()[1]), "species": "0"}
                )
            else:
                rods[cur_label].append(
                    {"chance": chance, "level": int(toks[2]), "species": species_name(toks[1])}
                )
    # consecutive labels alias the next non-empty table (CL aliases
    # .Qwilfish_NoSwarm_* to .Qwilfish_*).
    rkeys = list(rods)
    for n, label in enumerate(rkeys):
        if not rods[label]:
            nxt = n + 1
            while nxt < len(rkeys) and not rods[rkeys[nxt]]:
                nxt += 1
            if nxt < len(rkeys):
                rods[label] = rods[rkeys[nxt]]
    for i, (chance, old, good, super_) in enumerate(headers):
        gname = names[i]
        out[gname] = {
            "id": gname,
            "index": i + 1,
            "chance": chance,
            "old": rods[old],
            "good": rods[good],
            "super": rods[super_],
        }
    return out


def parse_tree_sets(out):
    """treemons.asm: TreeMonSet_X: label + common rows + db -1 + rare rows + db -1.

    NOTE: CL aliases TreeMonSet_City:/TreeMonSet_Canyon: (consecutive labels,
    same body); both keys get the same tables.  TreeMonSet_Rock has only a
    common table (no rare section).
    """
    src = (WILD_DIR / "treemons.asm").read_text()
    # find each set block: label(s) then rows until next TreeMonSet_* label
    idx = [m.start() for m in re.finditer(r"^TreeMonSet_\w+:", src, re.M)]
    # blocks whose label line(s) are empty aliases inherit the NEXT block's
    # body (CL aliases TreeMonSet_City:/TreeMonSet_Canyon: to one table).
    bodies = {}
    for n, pos in enumerate(idx):
        end = idx[n + 1] if n + 1 < len(idx) else len(src)
        block = src[pos:end]
        labels = re.findall(r"^TreeMonSet_(\w+):", block, re.M)
        common_rows, rare_rows = [], []
        half = "common"
        for line in block.splitlines():
            line = line.split(";")[0].strip()
            if line.startswith("db"):
                toks = [t.strip() for t in line[2:].strip().split(",")]
                if toks[0] == "-1":
                    half = "rare"
                    continue
                row = {"chance": int(toks[0]), "level": int(toks[2]), "species": species_name(toks[1])}
                (common_rows if half == "common" else rare_rows).append(row)
        for label in labels:
            bodies[label] = {"common": common_rows, "rare": rare_rows}
    # fill aliases (empty bodies) with the next non-empty body
    keys = list(bodies)
    for n, label in enumerate(keys):
        if not bodies[label]["common"] and not bodies[label]["rare"]:
            nxt = n + 1
            while nxt < len(keys) and not bodies[keys[nxt]]["common"]:
                nxt += 1
            if nxt < len(keys):
                bodies[label] = bodies[keys[nxt]]
    for label, rows in bodies.items():
        out[f"TREEMON_SET_{label.upper()}"] = rows
    return out


def parse_tree_maps(out_trees, out_rocks):
    """treemon_maps.asm: TreeMonMaps:: and RockMonMaps:: sections of
    `treemon_map MAP, TREEMON_SET_X` rows -> { [MAP] = "TREEMON_SET_X" }."""
    src = (WILD_DIR / "treemon_maps.asm").read_text()
    for section, dst in (("TreeMonMaps", out_trees), ("RockMonMaps", out_rocks)):
        m = re.search(rf"{section}::\n(.*?)(?=\n\w+::|\n\w+:|$)", src, re.S)
        if not m:
            continue
        for line in m.group(1).splitlines():
            line = line.split(";")[0].strip()
            mm = re.match(r"treemon_map\s+(\w+),\s*(\w+)", line)
            if mm:
                dst[mm.group(1)] = f'"{mm.group(2)}"'
    return out_trees, out_rocks


def parse_bug_contest(out):
    """bug_contest_mons.asm: db chance, SPECIES, min, max rows; the `db -1`
    terminator row is KEPT (chance=255) exactly like the extractor does."""
    src = (WILD_DIR / "bug_contest_mons.asm").read_text()
    for toks in read_db_rows(src):
        out.append(
            {"chance": pct(toks[0]), "species": species_name(toks[1]),
             "min": int(toks[2]), "max": int(toks[3])}
        )
    return out


def parse_roam_maps(out):
    """roammon_maps.asm: roam_map START, TO1, TO2... rows (db -1 terminator
    is emitted by the macro, not a data row here)."""
    src = (WILD_DIR / "roammon_maps.asm").read_text()
    for line in src.splitlines():
        line = line.split(";")[0].strip()
        if line.startswith("roam_map "):
            toks = [t.strip() for t in line[len("roam_map "):].split(",")]
            out.append({"map": f'"{toks[0]}"', "to": [f'"{t}"' for t in toks[1:]]})
    return out


# ---------------------------------------------------------------- emitter

def emit_lua(grass, swarm_grass, water, swarm_water, fish, trees, rocks,
             tree_sets, contest, roam):
    L = []
    a = L.append

    def slot_lines(slot, indent):
        out = []
        for row in slot:
            out.append(f"{indent}{{level = {row['level']}, species = {row['species']}}},")
        return out

    def grass_entry(k, v, indent="      "):
        lines = [f"{indent}{luakey(k)} = {{"]
        lines.append(f"{indent}  map = \"{v['map']}\",")
        lines.append(f"{indent}  rates = {{")
        for tod in ("MORN", "DAY", "NITE"):
            lines.append(f"{indent}    {tod} = {v['rates'][tod]},")
        lines.append(f"{indent}  }},")
        lines.append(f"{indent}  slots = {{")
        for tod in ("MORN", "DAY", "NITE"):
            lines.append(f"{indent}    {tod} = {{")
            lines.extend(slot_lines(v["slots"][tod], indent + "      "))
            lines.append(f"{indent}    }},")
        lines.append(f"{indent}  }},")
        lines.append(f"{indent}}},")
        return lines

    def water_entry(k, v, indent="      "):
        lines = [f"{indent}{luakey(k)} = {{"]
        lines.append(f"{indent}  map = \"{v['map']}\",")
        lines.append(f"{indent}  rate = {v['rate']},")
        lines.append(f"{indent}  slots = {{")
        lines.extend(slot_lines(v["slots"], indent + "    "))
        lines.append(f"{indent}  }},")
        lines.append(f"{indent}}},")
        return lines

    a("-- auto-generated by tools/converters/conv_encounters.py -- DO NOT EDIT")
    a("return { kinds = {")
    a("  grass = {")
    for k, v in grass.items():
        a("\n".join(grass_entry(k, v)))
    a("  },")
    a("  swarmGrass = {")
    for k, v in swarm_grass.items():
        a("\n".join(grass_entry(k, v)))
    a("  },")
    a("  water = {")
    for k, v in water.items():
        a("\n".join(water_entry(k, v)))
    a("  },")
    a("  swarmWater = {")
    for k, v in swarm_water.items():
        a("\n".join(water_entry(k, v)))
    a("  },")
    a("  fishGroups = {")
    for k, v in fish.items():
        a(f"    {luakey(k)} = {{")
        a(f'      id = "{v["id"]}",')
        a(f"      index = {v['index']},")
        a(f"      chance = {v['chance']},")
        for rod in ("old", "good", "super"):
            a(f"      {rod} = {{")
            for row in v[rod]:
                a(f"        {{chance = {row['chance']}, level = {row['level']}, species = {row['species']}}},")
            a("      },")
        a("    },")
    a("  },")
    a("  trees = {")
    for k, v in trees.items():
        a(f"    {luakey(k)} = {v},")
    a("  },")
    a("  rocks = {")
    for k, v in rocks.items():
        a(f"    {luakey(k)} = {v},")
    a("  },")
    a("  treeSets = {")
    for k, v in tree_sets.items():
        a(f"    {luakey(k)} = {{")
        for half in ("common", "rare"):
            a(f"      {half} = {{")
            for row in v[half]:
                a(f"        {{chance = {row['chance']}, level = {row['level']}, species = {row['species']}}},")
            a("      },")
        a("    },")
    a("  },")
    a("  bugContest = {")
    for row in contest:
        a(f"    {{chance = {row['chance']}, species = {row['species']}, min = {row['min']}, max = {row['max']}}},")
    a("  },")
    a("  roamMaps = {")
    for row in roam:
        a(f"    {{map = {row['map']}, to = {{{', '.join(row['to'])}}}}},")
    a("  },")
    a("},")
    a("}")
    return "\n".join(L) + "\n"


def main():
    grass = parse_grass(["johto_grass.asm", "kanto_grass.asm"], {})
    swarm_grass = parse_swarm_grass(["swarm_grass.asm"], {})
    water = parse_water(["johto_water.asm", "kanto_water.asm"], {})
    swarm_water = parse_water(["swarm_water.asm"], {})
    fish = parse_fish({})
    tree_sets = parse_tree_sets({})
    trees, rocks = {}, {}
    parse_tree_maps(trees, rocks)
    contest = parse_bug_contest([])
    roam = parse_roam_maps([])

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(emit_lua(grass, swarm_grass, water, swarm_water, fish, trees,
                            rocks, tree_sets, contest, roam))

    def n(d):
        return len(d)

    print(f"grass        : {n(grass):3d} maps")
    print(f"swarmGrass   : {n(swarm_grass):3d} maps")
    print(f"water        : {n(water):3d} maps")
    print(f"swarmWater   : {n(swarm_water):3d} maps")
    print(f"fishGroups   : {n(fish):3d} groups ({sum(len(f['old']) for f in fish.values())} old rod rows)")
    print(f"trees        : {n(trees):3d} maps")
    print(f"rocks        : {n(rocks):3d} maps")
    print(f"treeSets     : {n(tree_sets):3d} sets")
    print(f"bugContest   : {n(contest):3d} rows")
    print(f"roamMaps     : {n(roam):3d} entries")
    print(f"-> {OUT}")


if __name__ == "__main__":
    main()
