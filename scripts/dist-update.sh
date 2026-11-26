#!/usr/bin/env bash
# dist-update.sh — the ONLY step that touches the network.
#
# Fetches the upstream release tarballs pinned in manifest/dist.tsv into dist/
# (kept as shipped, sha256-checked) and writes VERSIONS. A tarball already in
# dist/ with the pinned sha256 is reused, not downloaded. Run it deliberately
# on a connected machine (curl, sha256sum), review the diff, commit.
# build-dist.sh never downloads anything.
# A tarball over 95 MiB (GitHub refuses files over 100 MiB) is stored as
# FILE.part00, FILE.part01, … (split -d); build-dist.sh joins them. The pin is
# the whole file's sha256.
#
#   manifest/dist.tsv   name <TAB> kind <TAB> version <TAB> file <TAB> url <TAB> sha256
#                       (cmake, onnxruntime, ACE+TAO, OpenDDS, RapidJSON, PROJ, GEOS, GDAL)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# fetched into a staging dir; dist/ is replaced only when the whole run succeeded
D=$ROOT/dist.staging
VERSIONS=$(mktemp)
trap 'rm -rf "$D" "$VERSIONS"' EXIT
rm -rf "$D"
mkdir -p "$D"

log() { printf '\033[1m==> %s\033[0m\n' "$*"; }

SPLIT=95M
# whole: DIR FILE — FILE from DIR to stdout, joined from its parts if split
whole() { if [[ -f $1/$2 ]]; then cat "$1/$2"; else cat "$1/$2".part[0-9][0-9]; fi; }

while IFS=$'\t' read -r name kind version file url sha; do
  [[ -z $name || $name == \#* ]] && continue
  if [[ $(whole "$ROOT/dist" "$file" 2>/dev/null | sha256sum) == "$sha  -" ]]; then
    whole "$ROOT/dist" "$file" >"$D/$file"
  else
    log "dist $name $version"
    curl -fsSL --retry 5 --retry-delay 10 --retry-all-errors "$url" -o "$D/$file"
    echo "$sha  $D/$file" | sha256sum -c --quiet - || { echo "sha256 mismatch: $url" >&2; exit 1; }
  fi
  if (( $(stat -c %s "$D/$file") > $(numfmt --from=iec "$SPLIT") )); then
    split -b "$SPLIT" -d "$D/$file" "$D/$file.part"
    rm "$D/$file"
  fi
  printf '%-28s %s %s\n' "dist/$name" "$url" "$version ($kind)" >>"$VERSIONS"
done <"$ROOT/manifest/dist.tsv"

sort "$VERSIONS" >"$ROOT/VERSIONS"
rm -rf "$ROOT/dist"
mv "$D" "$ROOT/dist"
log "done — review 'git status' and VERSIONS, update the license table in README.md for a new component, then commit"
