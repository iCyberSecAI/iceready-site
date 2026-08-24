#!/usr/bin/env bash
# Build and sign the ICE Ready rights card as an Apple Wallet pass (.pkpass).
#
#   ./build.sh
#
# Reads config from environment or ./config.env (git-ignored):
#   PASS_TYPE_ID   e.g. pass.app.iceready.rights
#   TEAM_ID        your 10-character Apple Developer Team ID
#   PASS_CERT      path to the Pass Type ID certificate + key, as a .p12
#   PASS_CERT_PASS password for that .p12
#   WWDR_CERT      path to the Apple WWDR intermediate certificate (.pem)
#
# Output: dist/ice-ready-rights.pkpass
set -euo pipefail
cd "$(dirname "$0")"

[ -f config.env ] && . ./config.env

for v in PASS_TYPE_ID TEAM_ID PASS_CERT WWDR_CERT; do
  if [ -z "${!v:-}" ]; then
    echo "error: $v is not set. See the README, then create config.env." >&2
    exit 1
  fi
done

BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT
mkdir -p dist

# 1. pass.json with the real identifiers substituted in.
sed -e "s|PASS_TYPE_ID|$PASS_TYPE_ID|" -e "s|TEAM_ID|$TEAM_ID|" pass.json > "$BUILD/pass.json"

# 2. Icons. Wallet requires icon.png (29pt) and logo.png, at 1x/2x/3x.
#    Generated from the repo artwork so there is one source of truth.
SRC_ICON=../../ice_ready_fixed.png
SRC_LOGO=../../shield-clean.png
resize() { # resize <src> <px> <dest>
  if command -v sips >/dev/null 2>&1; then
    sips -z "$2" "$2" "$1" --out "$3" >/dev/null
  elif command -v magick >/dev/null 2>&1; then
    magick "$1" -resize "${2}x${2}" "$3"
  elif python3 -c "import PIL" 2>/dev/null; then
    python3 -c "from PIL import Image;i=Image.open('$1');i.resize(($2,$2)).save('$3')"
  else
    echo "error: need sips, ImageMagick, or python3 with Pillow to resize icons." >&2
    exit 1
  fi
}
resize "$SRC_ICON" 29  "$BUILD/icon.png"
resize "$SRC_ICON" 58  "$BUILD/icon@2x.png"
resize "$SRC_ICON" 87  "$BUILD/icon@3x.png"
resize "$SRC_LOGO" 50  "$BUILD/logo.png"
resize "$SRC_LOGO" 100 "$BUILD/logo@2x.png"
resize "$SRC_LOGO" 150 "$BUILD/logo@3x.png"

# 3. manifest.json — SHA-1 of every file in the bundle.
( cd "$BUILD" && python3 - <<'PY'
import hashlib, json, os
m = {f: hashlib.sha1(open(f,'rb').read()).hexdigest()
     for f in sorted(os.listdir('.')) if os.path.isfile(f)}
json.dump(m, open('manifest.json','w'), indent=2)
PY
)

# 4. Detached PKCS#7 signature over the manifest.
openssl pkcs12 -in "$PASS_CERT" -clcerts -nokeys -out "$BUILD/cert.pem" \
  -passin "pass:${PASS_CERT_PASS:-}" -legacy 2>/dev/null || \
openssl pkcs12 -in "$PASS_CERT" -clcerts -nokeys -out "$BUILD/cert.pem" \
  -passin "pass:${PASS_CERT_PASS:-}"
openssl pkcs12 -in "$PASS_CERT" -nocerts -nodes -out "$BUILD/key.pem" \
  -passin "pass:${PASS_CERT_PASS:-}" -legacy 2>/dev/null || \
openssl pkcs12 -in "$PASS_CERT" -nocerts -nodes -out "$BUILD/key.pem" \
  -passin "pass:${PASS_CERT_PASS:-}"

openssl smime -binary -sign \
  -certfile "$WWDR_CERT" \
  -signer "$BUILD/cert.pem" \
  -inkey "$BUILD/key.pem" \
  -in "$BUILD/manifest.json" \
  -out "$BUILD/signature" \
  -outform DER

rm -f "$BUILD/cert.pem" "$BUILD/key.pem"

# 5. Zip it up. The pass files must be at the archive root, not in a folder.
OUT="$PWD/dist/ice-ready-rights.pkpass"
rm -f "$OUT"
( cd "$BUILD" && zip -q -r "$OUT" . -x '.*' )

echo "built $OUT"
echo "copy it to ../../passes/ to publish it:  mkdir -p ../../passes && cp \"$OUT\" ../../passes/"
