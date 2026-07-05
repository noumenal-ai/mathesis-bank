#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Mathesis — fetch frozen export blobs by content address (sha256).
#
# The .export blobs (the 321 MB / 74 MB frozen references) live in object
# storage, NOT git (they exceed GitHub's 100 MB/file push limit). This script
# resolves every sha256 referenced by a Results manifest, downloads each blob
# from the configured store, and VERIFIES sha256 AFTER download. Because the
# blobs are content-addressed, a corrupted or SUBSTITUTED blob is caught right
# here, before the re-derivation gate ever parses it — the fetch is itself a
# trust boundary, not a plain download.
#
# Store is chosen by MATHESIS_EXPORT_STORE:
#   gh:owner/repo@tag   -> gh release download <tag> -R owner/repo -p <sha>.export   (default in CI)
#   https://.../path    -> curl <STORE>/<sha>.export
#   /local/dir          -> cp   <STORE>/<sha>.export                                 (local sim / self-host)
#
# Destination is MATHESIS_EXPORTS_DIR (default: <repo>/registry/_shared/exports),
# which is exactly where _verify_check.py looks.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="${VERIFY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DEST="${MATHESIS_EXPORTS_DIR:-$ROOT/registry/_shared/exports}"
STORE="${MATHESIS_EXPORT_STORE:?set MATHESIS_EXPORT_STORE (gh:owner/repo@tag | https://... | /local/dir)}"
mkdir -p "$DEST"

sha_of() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

# Unique sha256s referenced by Results manifests.
shas="$(python3 - "$ROOT" <<'PY'
import json, glob, os, sys
root = sys.argv[1]; s = set()
for p in glob.glob(os.path.join(root, "registry", "results", "*", "manifest.json")):
    fe = (json.load(open(p)).get("frozen_export") or {})
    if fe.get("sha256"):
        s.add(fe["sha256"])
print("\n".join(sorted(s)))
PY
)"

[ -n "$shas" ] || { echo "fetch_exports: no frozen_export sha256s referenced — nothing to fetch."; exit 0; }

n=0
for sha in $shas; do
  out="$DEST/$sha.export"
  if [ -f "$out" ] && [ "$(sha_of "$out")" = "$sha" ]; then
    echo "have     $sha"; n=$((n+1)); continue
  fi
  echo "fetch    $sha  <- $STORE"
  case "$STORE" in
    https://*|http://*)
      curl -fsSL "$STORE/$sha.export" -o "$out" ;;
    gh:*)
      spec="${STORE#gh:}"; tag="${spec##*@}"; repo="${spec%@*}"
      gh release download "$tag" -R "$repo" -p "$sha.export" -D "$DEST" --clobber ;;
    *)
      cp "$STORE/$sha.export" "$out" ;;
  esac
  got="$(sha_of "$out")"
  if [ "$got" != "$sha" ]; then
    echo "FATAL: sha256 mismatch for $sha (downloaded $got) — refusing to place a non-content-matching blob." >&2
    rm -f "$out"; exit 1
  fi
  echo "verified $sha"; n=$((n+1))
done
echo "fetch_exports: $n blob(s) present + sha256-verified in $DEST"
