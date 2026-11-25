#!/bin/sh
# Reusable ACME certificate renewal wrapper for the Homelab Local CA.
#
# Usage: renew-cert-wrapper.sh <config-file>
#
# The config file is a POSIX shell snippet that sets variables.
# Required:
#   DOMAIN            primary certificate CN/SAN
# Optional:
#   ACME_SH           path to acme.sh (default: /root/.acme.sh/acme.sh)
#   LE_WORKING_DIR    acme.sh working dir (default: /root/.acme.sh)
#   ACME_SERVER       local CA ACME directory URL
#   ALT_NAMES         space-separated extra SANs
#   PRE_HOOK          command to run before renewal (e.g. stop service)
#   POST_HOOK         command to run after successful renewal
#   ALWAYS_HOOK       command to run on exit no matter what (e.g. start service)
#   CERT_DIR          base directory for assembled tls.pem
#   CERT_FILE         path to install leaf certificate
#   FULLCHAIN_FILE    path to install full chain
#   KEY_FILE          path to install private key
#   CA_FILE           path to install intermediate CA
#   KEY_OWNER         chown owner:group for key and tls.pem
#   TLS_PEM           "yes" to concatenate key + fullchain into CERT_DIR/tls.pem
#   FORCE_RENEW       "yes" to pass --force to acme.sh

set -eu

CONFIG_FILE="${1:?Usage: $0 <config-file>}"
# shellcheck source=/dev/null
. "$CONFIG_FILE"

DOMAIN="${DOMAIN:?DOMAIN must be set in $CONFIG_FILE}"

ACME_SH="${ACME_SH:-/root/.acme.sh/acme.sh}"
LE_WORKING_DIR="${LE_WORKING_DIR:-/root/.acme.sh}"
export LE_WORKING_DIR

ACME_SERVER="${ACME_SERVER:-}"
ALT_NAMES="${ALT_NAMES:-}"
CERT_DIR="${CERT_DIR:-}"
CERT_FILE="${CERT_FILE:-}"
FULLCHAIN_FILE="${FULLCHAIN_FILE:-}"
KEY_FILE="${KEY_FILE:-}"
CA_FILE="${CA_FILE:-}"
KEY_OWNER="${KEY_OWNER:-}"
TLS_PEM="${TLS_PEM:-no}"
PRE_HOOK="${PRE_HOOK:-}"
POST_HOOK="${POST_HOOK:-}"
ALWAYS_HOOK="${ALWAYS_HOOK:-}"
FORCE_RENEW="${FORCE_RENEW:-no}"

# Default CA so acme.sh knows where to renew against.
if [ -n "$ACME_SERVER" ]; then
    "$ACME_SH" --set-default-ca --server "$ACME_SERVER"
fi

# ALWAYS_HOOK runs even if renewal fails, so services are never left down.
cleanup() {
    if [ -n "$ALWAYS_HOOK" ]; then
        echo "[*] Running always-hook..."
        (eval "$ALWAYS_HOOK") || true
    fi
}
trap cleanup EXIT

if [ -n "$PRE_HOOK" ]; then
    echo "[*] Running pre-hook..."
    eval "$PRE_HOOK"
fi

# Build the ACME invocation with explicit argument boundaries.
set -- --renew --ecc
if [ "$FORCE_RENEW" = "yes" ]; then
    set -- "$@" --force
fi
set -- "$@" -d "$DOMAIN"
for alt in $ALT_NAMES; do
    set -- "$@" -d "$alt"
done
if [ -n "$ACME_SERVER" ]; then
    set -- "$@" --server "$ACME_SERVER"
fi

echo "[*] Renewing certificate for $DOMAIN..."
set +e
"$ACME_SH" "$@"
ACME_EXIT=$?
set -e

# acme.sh returns 2 when the cert is not yet in its renewal window.
# Treat that as success; the service hooks below still run.
if [ "$ACME_EXIT" -ne 0 ] && [ "$ACME_EXIT" -ne 2 ]; then
    echo "[!] acme.sh failed with exit code $ACME_EXIT"
    exit "$ACME_EXIT"
fi

if [ "$ACME_EXIT" -eq 2 ]; then
    echo "[*] acme.sh: renewal not due yet, skipping cert deployment."
else
    SRC_DIR="/root/.acme.sh/${DOMAIN}_ecc"

    if [ -n "$CERT_FILE" ]; then
        cp "$SRC_DIR/${DOMAIN}.cer" "$CERT_FILE"
        chmod 644 "$CERT_FILE"
    fi
    if [ -n "$FULLCHAIN_FILE" ]; then
        cp "$SRC_DIR/fullchain.cer" "$FULLCHAIN_FILE"
        chmod 644 "$FULLCHAIN_FILE"
    fi
    if [ -n "$KEY_FILE" ]; then
        cp "$SRC_DIR/${DOMAIN}.key" "$KEY_FILE"
        chmod 600 "$KEY_FILE"
        if [ -n "$KEY_OWNER" ]; then
            chown "$KEY_OWNER" "$KEY_FILE"
        fi
    fi
    if [ -n "$CA_FILE" ]; then
        cp "$SRC_DIR/ca.cer" "$CA_FILE"
        chmod 644 "$CA_FILE"
    fi
    if [ "$TLS_PEM" = "yes" ] && [ -n "$CERT_DIR" ]; then
        cat "$SRC_DIR/${DOMAIN}.key" "$SRC_DIR/fullchain.cer" > "$CERT_DIR/tls.pem"
        chmod 600 "$CERT_DIR/tls.pem"
        if [ -n "$KEY_OWNER" ]; then
            chown "$KEY_OWNER" "$CERT_DIR/tls.pem"
        fi
    fi
fi

if [ -n "$POST_HOOK" ]; then
    echo "[*] Running post-hook..."
    eval "$POST_HOOK"
fi

echo "[*] Done for $DOMAIN."
