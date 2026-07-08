#!/bin/bash
# Generate self-signed TLS certificate for EMQX (dev only)
# For production: replace with a real certificate for the public MQTT hostname
#
# Usage: bash gen-certs.sh [PI_IP]
# Default PI_IP: 192.168.1.16

set -euo pipefail

CERT_DIR="$(cd "$(dirname "$0")" && pwd)/certs"
PI_IP="${1:-192.168.1.16}"

mkdir -p "$CERT_DIR"

echo "Generating self-signed cert..."
echo "  IP SAN: $PI_IP"

openssl req -x509 \
  -newkey rsa:2048 \
  -keyout "$CERT_DIR/server.key" \
  -out    "$CERT_DIR/server.crt" \
  -days   3650 \
  -nodes  \
  -subj   "/CN=smart-air-emqx/O=SmartAir/C=VN" \
  -addext "subjectAltName=IP:${PI_IP},IP:127.0.0.1,DNS:localhost"

chmod 600 "$CERT_DIR/server.key"
chmod 644 "$CERT_DIR/server.crt"

echo ""
echo "Done:"
echo "  certs/server.crt - dev-only cert for local testing"
echo "  certs/server.key - keep secret, never commit"
