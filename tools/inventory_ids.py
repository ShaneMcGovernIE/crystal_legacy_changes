#!/usr/bin/env python3
"""Scan data/encounters.lua + data/trainers.lua for every referenced
species / move / item / music id, and emit Lua seed lines for the test suite.

Integration helper only (never shipped - covered by .modkitignore).
"""
import re, sys, collections, os

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")

SPECIES_RE = re.compile(r'species = "([^"]+)"')
MOVE_RE = re.compile(r'moves = \{(.*?)\}')
ITEM_RE = re.compile(r'item = "([^"]+)"|items = \{(.*?)\}')
MUSIC_RE = re.compile(r'encounterMusic = "([^"]+)"')

def scan(path, counters):
    for line in open(path, encoding="utf-8"):
        m = MOVE_RE.search(line)
        if m:
            for mv in re.findall(r'"([^"]+)"', m.group(1)):
                counters["move"][mv] += 1
        m = ITEM_RE.search(line)
        if m:
            if m.group(1):
                counters["item"][m.group(1)] += 1
            else:
                for it in re.findall(r'"([^"]+)"', m.group(2)):
                    counters["item"][it] += 1
        m = SPECIES_RE.search(line)
        if m:
            counters["species"][m.group(1)] += 1
        m = MUSIC_RE.search(line)
        if m:
            counters["music"][m.group(1)] += 1

counters = collections.defaultdict(collections.Counter)
for fn in ("encounters.lua", "trainers.lua"):
    p = os.path.join(DATA, fn)
    if os.path.exists(p):
        scan(p, counters)

for kind in ("species", "move", "item", "music"):
    print(f"===== {kind} ({len(counters[kind])} unique) =====")
    for val in sorted(counters[kind]):
        print(f"  {val}  x{counters[kind][val]}")

print("\n===== lua seed lines =====")
seed_var = {
    "species": "seedPokemon",
    "move": "seedMove",
    "item": "seedItem",
    "music": "seedMusic",
}[None or "species"]
# emit one block per kind
for kind, fn in (("species", "seedPokemon"), ("move", "seedMove"),
                 ("item", "seedItem"), ("music", "seedMusic")):
    names = sorted(counters[kind])
    print(f"\n-- {kind}: {len(names)}")
    for i in range(0, len(names), 6):
        chunk = names[i:i+6]
        args = ", ".join('"%s"' % c for c in chunk)
        print("%s(%s)" % (fn, args))
