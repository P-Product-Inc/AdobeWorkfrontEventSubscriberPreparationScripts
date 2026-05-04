#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-./jwt-keys/linux-jwt-assets}"
CERT_SUBJECT="${CERT_SUBJECT:-/CN=JWTAssets}"
KEY_BITS="${KEY_BITS:-2048}"
VALID_DAYS="${VALID_DAYS:-730}"
PFX_PASSWORD="${PFX_PASSWORD:-$(openssl rand -base64 24 | tr -d '\n')}"

mkdir -p "$OUT_DIR"

PRIVATE_KEY="$OUT_DIR/private.key"
PUBLIC_CERT_CRT="$OUT_DIR/certificate_pub.crt"
PUBLIC_CERT_PEM="$OUT_DIR/certificate_pub.pem"
PFX_FILE="$OUT_DIR/private_key.pfx"
PFX_PASSWORD_FILE="$OUT_DIR/private_key_pfx_password.txt"
PFX_B64_FILE="$OUT_DIR/private_key_pfx_base64.txt"
RSA_JSON_FILE="$OUT_DIR/rsa-params.json"
RSA_MIN_B64_FILE="$OUT_DIR/rsa_params.min.b64.txt"

openssl req -x509 -sha256 -nodes -newkey "rsa:${KEY_BITS}" \
  -keyout "$PRIVATE_KEY" \
  -out "$PUBLIC_CERT_CRT" \
  -subj "$CERT_SUBJECT" \
  -days "$VALID_DAYS" >/dev/null 2>&1

cp "$PUBLIC_CERT_CRT" "$PUBLIC_CERT_PEM"

openssl pkcs12 -export \
  -out "$PFX_FILE" \
  -inkey "$PRIVATE_KEY" \
  -in "$PUBLIC_CERT_CRT" \
  -passout "pass:${PFX_PASSWORD}" >/dev/null 2>&1

printf "%s" "$PFX_PASSWORD" > "$PFX_PASSWORD_FILE"
openssl base64 -A -in "$PFX_FILE" > "$PFX_B64_FILE"

export PRIVATE_KEY RSA_JSON_FILE RSA_MIN_B64_FILE
python3 <<'PY'
import base64
import json
import os
from cryptography.hazmat.primitives import serialization

private_key_path = os.environ["PRIVATE_KEY"]
rsa_json_file = os.environ["RSA_JSON_FILE"]
rsa_min_b64_file = os.environ["RSA_MIN_B64_FILE"]

with open(private_key_path, "rb") as f:
    key = serialization.load_pem_private_key(f.read(), password=None)

numbers = key.private_numbers()
public_numbers = numbers.public_numbers

def to_b64(i: int) -> str:
    length = (i.bit_length() + 7) // 8
    return base64.b64encode(i.to_bytes(length, "big")).decode("ascii")

payload = {
    "modulus": to_b64(public_numbers.n),
    "exponent": to_b64(public_numbers.e),
    "d": to_b64(numbers.d),
    "p": to_b64(numbers.p),
    "q": to_b64(numbers.q),
    "dp": to_b64(numbers.dmp1),
    "dq": to_b64(numbers.dmq1),
    "inverseQ": to_b64(numbers.iqmp),
}

with open(rsa_json_file, "w", encoding="ascii") as f:
    json.dump(payload, f, indent=2)

min_json = json.dumps(payload, separators=(",", ":")).encode("utf-8")
with open(rsa_min_b64_file, "w", encoding="ascii") as f:
    f.write(base64.b64encode(min_json).decode("ascii"))
PY

echo "Created artifacts in: $OUT_DIR"
echo "- certificate_pub.crt               (upload to your target JWT/OAuth app)"
echo "- private.key                       (PEM private key)"
echo "- private_key.pfx                   (optional)"
echo "- private_key_pfx_password.txt      (single-line password)"
echo "- private_key_pfx_base64.txt        (single-line Base64)"
echo "- rsa-params.json                   (readable RSA params)"
echo "- rsa_params.min.b64.txt            (single-line Base64 for connector)"
