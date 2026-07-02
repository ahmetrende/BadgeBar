#!/bin/bash
# One-time: create a STABLE self-signed code-signing identity so the
# Accessibility permission survives rebuilds.
#
# Ad-hoc signing ("-") changes the binary's cdhash on every build, which makes
# macOS treat each build as a new app and forget the granted permission. A
# stable certificate gives the app a constant "designated requirement", so the
# TCC grant sticks.
#
# This creates a DEDICATED keychain (it never touches your login keychain) and
# adds it to the search list. Safe and reversible: `security delete-keychain`.
set -euo pipefail

# shellcheck source=signing-config.sh
source "$(cd "$(dirname "$0")" && pwd)/signing-config.sh"

# A self-signed cert is "not trusted", so it won't show under `-v`; query
# without it.
if [ -f "$KEYCHAIN" ] && security find-identity -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$IDENTITY"; then
    echo "✓ Signing identity already exists: $IDENTITY"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $IDENTITY
[v3]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

echo "▸ Generating self-signed certificate…"
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -config "$TMP/openssl.cnf" >/dev/null 2>&1

# `-legacy` keeps the PKCS#12 in a format macOS `security import` accepts
# (OpenSSL 3's default encryption is too new for it).
openssl pkcs12 -export -legacy -out "$TMP/identity.p12" \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -passout pass:"$KC_PASS" >/dev/null 2>&1

echo "▸ Creating dedicated keychain…"
security delete-keychain "$KEYCHAIN" 2>/dev/null || true
security create-keychain -p "$KC_PASS" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"          # no auto-lock
security unlock-keychain -p "$KC_PASS" "$KEYCHAIN"

echo "▸ Importing identity…"
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$KC_PASS" -A -T /usr/bin/codesign >/dev/null 2>&1
security set-key-partition-list -S apple-tool:,apple: -s -k "$KC_PASS" "$KEYCHAIN" >/dev/null 2>&1

# Add our keychain to the user search list, keeping the login keychain.
security list-keychains -d user -s "$KEYCHAIN" "$HOME/Library/Keychains/login.keychain-db"

echo "✓ Created signing identity: $IDENTITY"
security find-identity -p codesigning "$KEYCHAIN" | grep "$IDENTITY" || true
