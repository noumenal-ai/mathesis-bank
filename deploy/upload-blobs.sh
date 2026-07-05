#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Upload the frozen export blobs to the `exports-v1` Release on mathesis-bank,
# named by sha256 so ci/fetch_exports.sh can pull them content-addressed.
#
# The blobs are the immutable frozen references (321 MB + 74 MB). They are
# PUBLIC + auditable by design (anyone can re-run the gate against them), and
# fit GitHub's 2 GB/asset limit. This is a credentialed action — run it as the
# account with push/release rights on noumenal-ai/mathesis-bank.
#
# Usage:
#   MATHESIS_BACKEND=/path/to/Mathesis-v4.31 bash deploy/upload-blobs.sh
# ---------------------------------------------------------------------------
set -euo pipefail

REPO="${MATHESIS_REPO:-noumenal-ai/mathesis-bank}"
TAG="${MATHESIS_EXPORT_TAG:-exports-v1}"
PRIV="${MATHESIS_BACKEND:-/Users/polaris/Documents/Epistemology and Zetesis/Noumenal/Mathesis-v4.31}"
EXPORTS="$PRIV/registry/_shared/exports"

blobs=(
  "040a6e477554a6bf9edf8d11f837130a80849c430a79c2737a4e83e2aef651f0.export"
  "6f334bc4a8aeabfd005bed459a5d876dcb20c52893f7a7d84c16922f438d5012.export"
)

for b in "${blobs[@]}"; do
  [ -f "$EXPORTS/$b" ] || { echo "FATAL: blob missing: $EXPORTS/$b"; exit 1; }
done

# Create the release if it does not exist yet (idempotent).
if ! gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" -R "$REPO" \
    --title "Mathesis frozen exports (v1)" \
    --notes "Content-addressed frozen .export blobs (sha256-named). Fetched by ci/fetch_exports.sh and re-derived by mathesis-adjudicate. Immutable references for the founding WMSpec volume."
fi

for b in "${blobs[@]}"; do
  echo "uploading $b ($(du -h "$EXPORTS/$b" | cut -f1)) ..."
  gh release upload "$TAG" -R "$REPO" "$EXPORTS/$b" --clobber
done

echo "Done. Assets on $REPO@$TAG:"
gh release view "$TAG" -R "$REPO" --json assets --jq '.assets[].name'
