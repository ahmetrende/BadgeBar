# Shared signing configuration, sourced by build.sh and setup-signing.sh so the
# two can't drift. The password guards only a throwaway LOCAL self-signed dev
# keychain (no private key of value leaves the machine), so it is intentionally
# not a secret. Override via the environment if you like.
: "${IDENTITY:=BadgeBar Self-Signed}"
: "${KC_PASS:=badgebar}"
: "${KEYCHAIN:=$HOME/Library/Keychains/badgebar-signing.keychain-db}"
export IDENTITY KC_PASS KEYCHAIN
