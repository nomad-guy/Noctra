#!/usr/bin/env bash
# Builds Noctra's GitHub-distribution artifacts LOCALLY and writes the
# release manifest the in-app updater consumes. It never uploads or
# publishes anything — publishing stays a manual GitHub step.
#
# Usage:
#   tool/build_release.sh            # per-ABI + universal APKs + manifest
#   tool/build_release.sh --no-build # only hash existing APKs + manifest
# Optional signing:
#   NOCTRA_UPDATE_MANIFEST_SIGNING_KEY=/path/to/ed25519-private.pem \
#     tool/build_release.sh
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
NO_BUILD=0
if [[ "${1:-}" == "--no-build" ]]; then NO_BUILD=1; fi

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
OUT="build/release"
rm -rf "$OUT"
mkdir -p "$OUT"

# --- version from pubspec.yaml (name+buildCode) ---------------------------
VERSION_LINE="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n1)"
VERSION="${VERSION_LINE%%+*}"
BUILD_CODE="${VERSION_LINE##*+}"
echo "Version: $VERSION (buildCode $BUILD_CODE)"

MIN_SDK="$(sed -n 's/.*minSdk[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
  android/app/build.gradle.kts | head -n1)"
MIN_SDK="${MIN_SDK:-26}"
echo "minimumAndroid: $MIN_SDK"

if [[ "$NO_BUILD" == "0" ]]; then
  echo "==> Building per-ABI release APKs (this takes a while)"
  "$FLUTTER_BIN" build apk --release --split-per-abi
  echo "==> Building universal release APK"
  "$FLUTTER_BIN" build apk --release
fi

# --- collect + rename artifacts -------------------------------------------
declare -A ABI_FILES=(
  [arm64-v8a]=app-arm64-v8a-release.apk
  [armeabi-v7a]=app-armeabi-v7a-release.apk
  [x86_64]=app-x86_64-release.apk
  [universal]=app-release.apk
)

FLUTTER_APK="build/app/outputs/flutter-apk"
PACKAGES_JSON=""
FIRST=1
for ABI in arm64-v8a armeabi-v7a x86_64 universal; do
  SRC="$FLUTTER_APK/${ABI_FILES[$ABI]}"
  if [[ ! -f "$SRC" ]]; then
    echo "!! Missing $SRC — skipping $ABI" >&2
    continue
  fi
  DEST="$OUT/Noctra-${VERSION}-${ABI}.apk"
  cp "$SRC" "$DEST"
  if command -v sha256sum >/dev/null 2>&1; then
    SHA="$(sha256sum "$DEST" | awk '{print $1}')"
  elif command -v python >/dev/null 2>&1; then
    SHA="$(python -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$DEST")"
  elif command -v python3 >/dev/null 2>&1; then
    SHA="$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$DEST")"
  else
    echo "!! No SHA-256 hasher available (sha256sum/python)" >&2
    exit 1
  fi
  echo "  $ABI -> $(basename "$DEST")  sha256=$SHA"
  if [[ "$FIRST" == "0" ]]; then PACKAGES_JSON+=","; fi
  FIRST=0
  PACKAGES_JSON+="
    \"$ABI\": {
      \"file\": \"$(basename "$DEST")\",
      \"sha256\": \"$SHA\"
    }"
done

cat > "$OUT/noctra-update-manifest.json" <<EOF
{
  "version": "$VERSION",
  "versionCode": $BUILD_CODE,
  "minimumAndroid": $MIN_SDK,
  "packages": {$PACKAGES_JSON
  }
}
EOF

echo
echo "==> Release manifest: $OUT/noctra-update-manifest.json"
cat "$OUT/noctra-update-manifest.json"
echo
if [[ -n "${NOCTRA_UPDATE_MANIFEST_SIGNING_KEY:-}" ]]; then
  if [[ ! -f "$NOCTRA_UPDATE_MANIFEST_SIGNING_KEY" ]]; then
    echo "!! Manifest signing key was not found" >&2
    exit 1
  fi
  if ! command -v openssl >/dev/null 2>&1; then
    echo "!! OpenSSL is required to sign the release manifest" >&2
    exit 1
  fi
  openssl pkeyutl -sign -rawin \
    -inkey "$NOCTRA_UPDATE_MANIFEST_SIGNING_KEY" \
    -in "$OUT/noctra-update-manifest.json" | base64 | tr -d '\r\n' \
    > "$OUT/noctra-update-manifest.json.sig"
  echo "==> Detached manifest signature: $OUT/noctra-update-manifest.json.sig"
fi

echo "==> Upload ALL of the following to the GitHub release:"
echo "    - every Noctra-*.apk under $OUT/"
echo "    - noctra-update-manifest.json (exact name required)"
if [[ -n "${NOCTRA_UPDATE_MANIFEST_SIGNING_KEY:-}" ]]; then
  echo "    - noctra-update-manifest.json.sig (exact name required)"
fi
