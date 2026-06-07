#!/usr/bin/env bash
# Restore the card media bundle (painted stills, motion clips, depth maps).
# The ~30MB of PNG/WebP is kept out of git to keep the repository small; it
# lives as an asset on a GitHub Release instead (free, no LFS quota).
#
#   ./tools/fetch_media.sh            # download if missing
#   ./tools/fetch_media.sh --force    # re-download
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="davidlevy115/citadels-3.0"
TAG="media-v1"
ASSET="citadels-media.tar.gz"
TMP="$(mktemp -d)/$ASSET"

if [ "${1:-}" != "--force" ] && ls assets/art/*.png >/dev/null 2>&1; then
	echo "media already present (use --force to re-download)"
	exit 0
fi

if command -v gh >/dev/null 2>&1; then
	gh release download "$TAG" --repo "$REPO" --pattern "$ASSET" --output "$TMP"
else
	curl -fL "https://github.com/$REPO/releases/download/$TAG/$ASSET" -o "$TMP"
fi

tar xzf "$TMP"
rm -f "$TMP"
echo "media restored into assets/ — Godot will import it on first open."
