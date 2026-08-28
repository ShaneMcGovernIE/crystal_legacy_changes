#!/usr/bin/env python3
"""conv_trainers.py -- convert CL data/trainers/*.asm into data/trainers.lua.

Dev-side converter (NEVER shipped -- see .modkitignore).  Mirrors the engine's
RomExtractorGen2.lua extractTrainers() contract so the generated file has the
exact Gold shape (src/mods/Schemas.lua gen2Fields):

    return {
      classes = {
        <CLASS> = {
          id, index, name,
          encounterMusic = "Music_X" | omitted,
          baseMoney, attributes = {i1, i2, money, aiwLo, aiwHi, aisLo, aisHi},
          items = {},            -- CL: every class carries NO_ITEM, NO_ITEM
          trainers = {
            { id, index, name, trainerType, party = { {level, species, item?, moves?} } }
          },
        },
        ...
      },
    }

Source files (all CL, read-only):
  constants/trainer_constants.asm     trainerclass blocks -> class order + member consts
  data/trainers/party_pointers.asm    70 dba XxxGroup in class order
  data/trainers/parties.asm           party groups (extended TRAINERTYPE_* handled)
  data/trainers/class_names.asm       70 li entries (charmap rendered)
  data/trainers/attributes.asm        70 x 4-line blocks (items/money/AI weight/AI switch)
  data/trainers/encounter_music.asm   71 db bytes (class 0 unused)

Engine-side (embedded, verified vs the real Gold cache trainers.lua):
  musicOrder = the engine's 93-entry 1-based music list; byte v -> musicOrder[v+1].

Deliberate deviations from the Gold extractor (all CL-preservation choices):
  * ALL parties per group are emitted (the Gold extractor would cap at
    #memberNames and silently DROP gym-leader rematch parties).
  * Overflow parties get fallback ids "<CLASS><N>" (the extractor's own
    "%s%d" format), e.g. FALKNER1/FALKNER2/FALKNER3/FALKNER4.
  * Extended TRAINERTYPE_* flags collapse to the Gold 0-3 schema by their
    ITEM/MOVES bits; NICKNAME/DVS/STAT_EXP/HAPPINESS/VARIABLE data is dropped.
  * encounterMusic beyond the 93-entry musicOrder (MUSIC_CLAIR=0x5d,
    MUSIC_MYSTICALMAN_ENCOUNTER=0x61) is omitted, exactly like the engine's
    extractor would for an out-of-range byte.
"""

import re
from pathlib import Path

CL = Path(__file__).resolve().parent.parent.parent.parent / "CL_source"
OUT = Path(__file__).resolve().parent.parent.parent / "data" / "trainers.lua"

# ----------------------------------------------------------------- constants

# trainer_data_constants.asm (CL == pokecrystal values)
TRAINERTYPE = {
    "TRAINERTYPE_NORMAL": 0,
    "TRAINERTYPE_MOVES": 1,
    "TRAINERTYPE_ITEM": 2,
    "TRAINERTYPE_ITEM_MOVES": 3,
    "TRAINERTYPE_NICKNAME": 4,
    "TRAINERTYPE_DVS": 8,
    "TRAINERTYPE_STAT_EXP": 16,
    "TRAINERTYPE_VARIABLE": 32,
    "TRAINERTYPE_HAPPINESS": 64,
}
TRAINERTYPE_NAMES = [
    "TRAINERTYPE_NORMAL",
    "TRAINERTYPE_MOVES",
    "TRAINERTYPE_ITEM",
    "TRAINERTYPE_ITEM_MOVES",
]

AI_FLAGS = {
    "NO_AI": 0,
    "AI_BASIC": 1 << 0,
    "AI_SETUP": 1 << 1,
    "AI_TYPES": 1 << 2,
    "AI_OFFENSIVE": 1 << 3,
    "AI_SMART": 1 << 4,
    "AI_OPPORTUNIST": 1 << 5,
    "AI_AGGRESSIVE": 1 << 6,
    "AI_CAUTIOUS": 1 << 7,
    "AI_STATUS": 1 << 8,
    "AI_RISKY": 1 << 9,
    "SWITCH_OFTEN": 1 << 0,
    "SWITCH_RARELY": 1 << 1,
    "SWITCH_SOMETIMES": 1 << 2,
    "CONTEXT_USE": 1 << 6,
}

# CL parties.asm ships `SUPER_NERD` in a move slot (CARA's Seadra, COOLTRAINERF).
# SUPER_NERD is a TRAINER CLASS const (value 29), so the assembled ROM stores
# move id 29 there -- the engine knows move 29 as HEADBUTT.  Map the stray
# const to the move the ROM actually contains.
SOURCE_MOVE_FIXES = {"SUPER_NERD": "HEADBUTT"}

# engine musicOrder (Gold manifest, 93 entries, 1-based in Lua): encounter_music
# byte v -> musicOrder[v+1] -> MUSIC_ORDER[v] here (0-based).
MUSIC_ORDER = [
    "Music_Nothing", "Music_TitleScreen", "Music_Route1", "Music_Route3",
    "Music_Route12", "Music_MagnetTrain", "Music_KantoGymBattle",
    "Music_KantoTrainerBattle", "Music_KantoWildBattle", "Music_PokemonCenter",
    "Music_LookHiker", "Music_LookLass", "Music_LookOfficer", "Music_HealPokemon",
    "Music_LavenderTown", "Music_Route2", "Music_MtMoon", "Music_ShowMeAround",
    "Music_GameCorner", "Music_Bicycle", "Music_HallOfFame", "Music_ViridianCity",
    "Music_CeladonCity", "Music_TrainerVictory", "Music_WildPokemonVictory",
    "Music_GymLeaderVictory", "Music_MtMoonSquare", "Music_Gym", "Music_PalletTown",
    "Music_ProfOaksPokemonTalk", "Music_ProfOak", "Music_LookRival",
    "Music_AfterTheRivalFight", "Music_Surf", "Music_Evolution", "Music_NationalPark",
    "Music_Credits", "Music_AzaleaTown", "Music_CherrygroveCity",
    "Music_LookKimonoGirl", "Music_UnionCave", "Music_JohtoWildBattle",
    "Music_JohtoTrainerBattle", "Music_Route30", "Music_EcruteakCity",
    "Music_VioletCity", "Music_JohtoGymBattle", "Music_ChampionBattle",
    "Music_RivalBattle", "Music_RocketBattle", "Music_ElmsLab", "Music_DarkCave",
    "Music_Route29", "Music_Route36", "Music_SSAqua", "Music_LookYoungster",
    "Music_LookBeauty", "Music_LookRocket", "Music_LookPokemaniac", "Music_LookSage",
    "Music_NewBarkTown", "Music_GoldenrodCity", "Music_VermilionCity",
    "Music_PokemonChannel", "Music_PokeFluteChannel", "Music_TinTower",
    "Music_SproutTower", "Music_BurnedTower", "Music_Lighthouse", "Music_LakeOfRage",
    "Music_IndigoPlateau", "Music_Route37", "Music_RocketHideout", "Music_DragonsDen",
    "Music_JohtoWildBattleNight", "Music_RuinsOfAlphRadio", "Music_SuccessfulCapture",
    "Music_Route26", "Music_Mom", "Music_VictoryRoad", "Music_PokemonLullaby",
    "Music_PokemonMarch", "Music_GoldSilverOpening", "Music_GoldSilverOpening2",
    "Music_MainMenu", "Music_RuinsOfAlphInterior", "Music_RocketTheme",
    "Music_DancingHall", "Music_ContestResults", "Music_BugCatchingContest",
    "Music_LakeOfRageRocketRadio", "Music_Printer", "Music_PostCredits",
]

# ------------------------------------------------------------------ helpers

def int_tok(t):
    return int(t, 16) if t.startswith("$") else int(t, 10)


def charmaps(s):
    """Engine charmaps: <PKMN> -> <PK><MN>, '#' -> 'POKé'."""
    s = s.replace("<PKMN>", "<PK><MN>")
    return s.replace("#", "POKé")


def clean_line(line):
    """Strip comment and whitespace."""
    return line.split(";")[0].strip()


# ------------------------------------------------------------ source parsers

def parse_classes(src):
    """trainer_constants.asm: trainerclass blocks -> [(name, [member consts])],
    TRAINER_NONE (class 0) dropped.  Phone contacts use the PHONECONTACT_
    prefix and are skipped; EQU aliases (CHRIS/KRIS/NUM_*) never match `const`."""
    classes = []
    cur = None
    for line in src.splitlines():
        l = clean_line(line)
        if l.startswith("trainerclass "):
            cur = [l.split()[1], []]
            classes.append(cur)
        elif l.startswith("const ") and cur is not None:
            name = l.split()[1]
            if not name.startswith("PHONECONTACT_"):
                cur[1].append(name)
    if classes and classes[0][0] == "TRAINER_NONE":
        classes = classes[1:]
    return classes


def parse_pointers(src):
    """party_pointers.asm: 70 `dba XxxGroup` labels in class order."""
    return re.findall(r"^\s*dba\s+(\w+Group)", src, re.M)


def parse_parties(src):
    """parties.asm -> {group_label: [clean lines]} (comments stripped, so the
    list holds blank lines, party headers, mon rows and db -1 terminators)."""
    groups, cur = {}, None
    for line in src.splitlines():
        l = clean_line(line)
        m = re.match(r"(\w+Group):", l)
        if m:
            cur = m.group(1)
            groups[cur] = []
        elif cur is not None:
            groups[cur].append(l)
    return groups


def parse_party(rows, i, ttype):
    """Parse one party starting at rows[i] (just past its header).  Returns
    (mons, next_index).  Extended-type mons carry their ITEM/MOVES (and any
    NICKNAME/DVS/STAT_EXP/HAPPINESS/VARIABLE) on the lines that follow the
    `db level, SPECIES` row, in canonical order; dropped data is skipped."""
    mons = []
    has_item = bool(ttype & TRAINERTYPE["TRAINERTYPE_ITEM"])
    has_moves = bool(ttype & TRAINERTYPE["TRAINERTYPE_MOVES"])
    dropped = [f for f in ("TRAINERTYPE_NICKNAME", "TRAINERTYPE_DVS",
                           "TRAINERTYPE_STAT_EXP", "TRAINERTYPE_VARIABLE",
                           "TRAINERTYPE_HAPPINESS") if ttype & TRAINERTYPE[f]]
    extended = bool(dropped)
    n = len(rows)

    def next_db(idx):
        """Return (tokens, next_idx) of the next non-blank db/dw field line."""
        while idx < n and not rows[idx]:
            idx += 1
        assert idx < n and rows[idx].startswith(("db", "dw")), \
            f"expected db/dw field, got: {rows[idx] if idx < n else 'EOF'}"
        toks = [t.strip() for t in rows[idx][2:].strip().split(",")]
        return toks, idx + 1

    while i < n:
        raw = rows[i]
        if not raw:
            i += 1
            continue
        if raw.startswith("db -1"):
            return mons, i + 1
        assert raw.startswith("db"), f"unexpected party content: {raw}"
        toks = [t.strip() for t in raw[2:].strip().split(",")]
        mon = {"level": int_tok(toks[0]), "species": toks[1]}
        i += 1
        if extended:
            for _ in dropped:
                _, i = next_db(i)
            if has_item:
                toks, i = next_db(i)
                if toks and toks[0] != "NO_ITEM":
                    mon["item"] = toks[0]
            if has_moves:
                toks, i = next_db(i)
                moves = [SOURCE_MOVE_FIXES.get(t, t) for t in toks
                         if t and t != "NO_MOVE"]  # trailing commas yield ""
                if moves:
                    mon["moves"] = moves
        else:
            rest = toks[2:]
            if has_item and rest:
                it = rest.pop(0)
                if it != "NO_ITEM":
                    mon["item"] = it
            if has_moves and rest:
                moves = [SOURCE_MOVE_FIXES.get(t, t) for t in rest
                         if t and t != "NO_MOVE"]  # trailing commas yield ""
                if moves:
                    mon["moves"] = moves
        mons.append(mon)
    return mons, i


def parse_party_list(rows, class_name, member_names):
    """Parse a group's lines into trainer records (Gold schema)."""
    trainers = []
    i, n = 0, len(rows)
    while i < n:
        raw = rows[i]
        if not raw:
            i += 1
            continue
        m = re.match(r'db\s+"([^"]*)"\s*,\s*(.+)$', raw)
        if not m:
            # unexpected non-header content (shouldn't happen once blanks skipped)
            i += 1
            continue
        name = charmaps(m.group(1))
        if name.endswith("@"):
            name = name[:-1]
        ttype = 0
        for tok in m.group(2).split("|"):
            tok = tok.strip()
            assert tok in TRAINERTYPE, f"unknown TRAINERTYPE token {tok!r}"
            ttype |= TRAINERTYPE[tok]
        party, i = parse_party(rows, i + 1, ttype)
        idx = len(trainers) + 1
        tid = member_names[idx - 1] if idx - 1 < len(member_names) else f"{class_name}{idx}"
        collapsed = (2 if ttype & 2 else 0) | (1 if ttype & 1 else 0)
        trainers.append({
            "id": tid,
            "index": idx,
            "name": name,
            "trainerType": TRAINERTYPE_NAMES[collapsed],
            "party": party,
        })
    return trainers


def parse_class_names(src):
    """class_names.asm: 70 `li "NAME"` entries (class order, charmap rendered)."""
    names = []
    for line in src.splitlines():
        m = re.search(r'li\s+"([^"]*)"', line)
        if m:
            names.append(charmaps(m.group(1)))
    assert len(names) == 70, f"expected 70 class names, got {len(names)}"
    return names


def parse_attributes(src):
    """attributes.asm: 70 x 4-line blocks -> rows [{items, money, aiw, ais}].

    Per class, positionally: `db A, B ; items` / `db N ; base reward` /
    `dw flags` (AI weight) / `dw flags` (AI item switch) -- the dw lines carry
    no comments, so this is a simple state machine."""
    rows = []
    state = 0  # 0=items, 1=reward, 2=aiw, 3=ais
    cur = {}
    for line in src.splitlines():
        l = clean_line(line)
        if not l:
            continue
        if state == 0 and l.startswith("db "):
            toks = [t.strip() for t in l[3:].strip().split(",")]
            cur["items"] = [t for t in toks if t != "NO_ITEM"]
            state = 1
        elif state == 1 and l.startswith("db "):
            cur["money"] = int_tok(l[3:].strip())
            state = 2
        elif state == 2 and l.startswith("dw "):
            cur["aiw"] = _eval_flags(l[3:])
            state = 3
        elif state == 3 and l.startswith("dw "):
            cur["ais"] = _eval_flags(l[3:])
            rows.append(cur)
            cur = {}
            state = 0
    assert len(rows) == 70, f"expected 70 attribute rows, got {len(rows)}"
    return rows


def _eval_flags(expr):
    val = 0
    for tok in expr.split("|"):
        tok = tok.strip()
        assert tok in AI_FLAGS, f"unknown AI flag {tok!r}"
        val |= AI_FLAGS[tok]
    return val


def parse_encounter_music(src):
    """encounter_music.asm: 71 `db MUSIC_X` bytes; returns 70 values
    (class 1..70), None when the value falls outside the engine musicOrder."""
    vals = []
    for line in src.splitlines():
        l = clean_line(line)
        if l.startswith("db "):
            tok = l[3:].strip()
            vals.append(MUSIC_CONSTS.get(tok))
    assert len(vals) == 71, f"expected 71 music bytes, got {len(vals)}"
    return vals[1:]  # drop class 0 (TRAINER_NONE)


def parse_music_constants(src):
    """music_constants.asm: sequential `const NAME` ids (const_def resets)."""
    out, cur = {}, 0
    for line in src.splitlines():
        l = clean_line(line)
        m = re.match(r"const\s+(\w+)", l)
        if m:
            out[m.group(1)] = cur
            cur += 1
        elif l.startswith("const_def"):
            cur = 0
    return out


MUSIC_CONSTS = parse_music_constants((CL / "constants" / "music_constants.asm").read_text())


# ------------------------------------------------------------------- build

def build(classes, pointers, parties, names, attrs, music):
    assert len(classes) == len(pointers) == len(names) == len(attrs) == len(music) == 70, \
        (len(classes), len(pointers), len(names), len(attrs), len(music))
    missing = set(pointers) - set(parties)
    assert not missing, f"party groups missing in parties.asm: {missing}"
    out = {}
    for i in range(70):
        cls_name, members = classes[i]
        group = pointers[i]
        a = attrs[i]
        rec = {
            "id": cls_name,
            "index": i + 1,
            "name": names[i],
            "baseMoney": a["money"],
            "attributes": [0, 0, a["money"],
                           a["aiw"] & 0xFF, a["aiw"] >> 8,
                           a["ais"] & 0xFF, a["ais"] >> 8],
            "items": a["items"],
            "trainers": parse_party_list(parties.get(group, []), cls_name, members),
        }
        mu = music[i]
        if mu is not None and 0 <= mu < len(MUSIC_ORDER):
            rec["encounterMusic"] = MUSIC_ORDER[mu]
        out[cls_name] = rec
    return out


# ------------------------------------------------------------------ emitter

def qlist(items):
    """'\"A\", \"B\"' for a list of name strings (avoids backslashes in f-strings)."""
    return ", ".join(f'"{i}"' for i in items)


def emit_lua(classes):
    L = []
    a = L.append
    a("-- auto-generated by tools/converters/conv_trainers.py -- DO NOT EDIT")
    a("return {")
    a("  classes = {")
    for cls_name in sorted(classes):
        c = classes[cls_name]
        a(f"    {cls_name} = {{")
        a(f"      attributes = {{ {', '.join(map(str, c['attributes']))} }},")
        a(f"      baseMoney = {c['baseMoney']},")
        if "encounterMusic" in c:
            a(f'      encounterMusic = "{c["encounterMusic"]}",')
        a(f'      id = "{c["id"]}",')
        a(f"      index = {c['index']},")
        a(f"      items = {{{qlist(c['items'])}}},")
        a(f'      name = "{c["name"]}",')
        a("      trainers = {")
        for t in c["trainers"]:
            a("        {")
            a(f'          id = "{t["id"]}",')
            a(f"          index = {t['index']},")
            a(f'          name = "{t["name"]}",')
            a("          party = {")
            for mon in t["party"]:
                bits = []
                if "item" in mon:
                    bits.append(f'item = "{mon["item"]}"')
                bits.append(f"level = {mon['level']}")
                if "moves" in mon:
                    bits.append(f"moves = {{{qlist(mon['moves'])}}}")
                bits.append(f'species = "{mon["species"]}"')
                a(f"            {{ {', '.join(bits)} }},")
            a("          },")
            a(f'          trainerType = "{t["trainerType"]}",')
            a("        },")
        a("      },")
        a("    },")
    a("  },")
    a("}")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------------- main

def main():
    src = CL / "data" / "trainers"
    classes = parse_classes((CL / "constants" / "trainer_constants.asm").read_text())
    pointers = parse_pointers((src / "party_pointers.asm").read_text())
    parties = parse_parties((src / "parties.asm").read_text())
    names = parse_class_names((src / "class_names.asm").read_text())
    attrs = parse_attributes((src / "attributes.asm").read_text())
    music = parse_encounter_music((src / "encounter_music.asm").read_text())

    out = build(classes, pointers, parties, names, attrs, music)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(emit_lua(out))

    print(f"classes       : {len(out):3d}")
    total = 0
    for cls_name in sorted(out):
        n = len(out[cls_name]["trainers"])
        total += n
        if n > 1 or cls_name in ("POKEMON_PROF", "BOSS", "RIVAL1", "RIVAL2"):
            print(f"  {cls_name:16s} {n:3d} parties")
    print(f"total parties : {total}")
    print(f"-> {OUT}")


if __name__ == "__main__":
    main()
