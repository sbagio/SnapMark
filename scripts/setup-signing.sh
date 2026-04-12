#!/usr/bin/env bash
# SnapMark — One-time signing certificate setup
#
# Creates a self-signed code-signing certificate in your login keychain.
# TCC (Screen Recording permission) tracks apps by signing identity.
# A stable certificate means the permission persists across rebuilds.
#
# Run once: ./scripts/setup-signing.sh
# Re-run only if the certificate expires (valid 10 years by default).

set -euo pipefail

CERT_NAME="SnapMark Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

# ── Already installed? ──────────────────────────────────────────────────────
if security find-certificate -c "$CERT_NAME" "$KEYCHAIN" &>/dev/null; then
    echo "✓ Certificate '$CERT_NAME' already exists — nothing to do."
    exit 0
fi

echo "Creating self-signed code-signing certificate: '$CERT_NAME'"
echo "(Valid 10 years, stored in login keychain)"
echo ""

# ── Generate key + certificate ───────────────────────────────────────────────
openssl genrsa -out "$TMPDIR_WORK/key.pem" 2048 2>/dev/null

cat > "$TMPDIR_WORK/cert.cfg" <<EOF
[req]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
x509_extensions    = v3

[dn]
CN = $CERT_NAME
O  = SnapMark Local
C  = US

[v3]
keyUsage         = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
subjectKeyIdentifier = hash
EOF

openssl req -new -x509 \
    -key "$TMPDIR_WORK/key.pem" \
    -out "$TMPDIR_WORK/cert.pem" \
    -days 3650 \
    -config "$TMPDIR_WORK/cert.cfg" 2>/dev/null

# ── Bundle as PKCS12 ─────────────────────────────────────────────────────────
PASS="snapmark-local-$(date +%s)"
openssl pkcs12 -export \
    -out  "$TMPDIR_WORK/snapmark.p12" \
    -inkey "$TMPDIR_WORK/key.pem" \
    -in   "$TMPDIR_WORK/cert.pem" \
    -passout "pass:$PASS" 2>/dev/null

# ── Import into login keychain ───────────────────────────────────────────────
security import "$TMPDIR_WORK/snapmark.p12" \
    -k "$KEYCHAIN" \
    -P "$PASS" \
    -T /usr/bin/codesign \
    -f pkcs12

# Allow codesign to access the key without prompting each build.
# This asks for your macOS login password once.
echo ""
echo "Granting codesign access to the key (your login password may be required):"
security set-key-partition-list \
    -S "apple-tool:,apple:,codesign:" \
    -s \
    "$KEYCHAIN" 2>/dev/null || {
    echo ""
    echo "Note: Could not set partition list automatically."
    echo "If codesign prompts for permission during builds, run:"
    echo "  security set-key-partition-list -S apple-tool:,apple:,codesign: -s ~/Library/Keychains/login.keychain-db"
}

echo ""
echo "✓ Done. Certificate '$CERT_NAME' installed."
echo ""
echo "Next steps:"
echo "  1. make build          (will now sign with the stable certificate)"
echo "  2. make install"
echo "  3. Grant Screen Recording once — it will persist across all future builds"
