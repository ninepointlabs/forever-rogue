#!/usr/bin/env bash
# Copy the addon (only the files WoW needs) into an AddOns folder for testing.
#   tools/install-dev.sh "/path/to/AddOns"
# No default path on purpose: point it at a temp folder, or (only with Tim's OK)
# at the Forever client's _forever_/Interface/AddOns.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
addons="${1:?usage: tools/install-dev.sh /path/to/AddOns}"
[ -d "$addons" ] || { echo "AddOns folder not found: $addons" >&2; exit 1; }
dest="$addons/ForeverRogue"
mkdir -p "$dest"
rsync -a --delete \
  --include='*.toc' --include='Core/***' --include='Data/***' --include='Modules/***' --include='UI/***' \
  --include='LICENSE' --exclude='*' \
  "$repo/" "$dest/"
echo "Installed to: $dest"
echo "In game: /reload, then /frogue"
