#!/usr/bin/env bash
# Regenerate the engine's override icon set (overrides/icons/gen2) from the
# canonical art in assets/icons.  Gen 2 screens (party menu, summary, boxes,
# dex, battle HUD) resolve icon paths through the engine's asset-override
# pipeline, so a fresh clone must run this before playtesting.  The release
# workflow regenerates the copy inside the packed zip itself.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf overrides/icons/gen2
mkdir -p overrides/icons/gen2
cp -R assets/icons/. overrides/icons/gen2/
count=$(find overrides/icons/gen2 -name '*.png' | wc -l | tr -d ' ')
echo "overrides/icons/gen2 synced ($count pngs)"
