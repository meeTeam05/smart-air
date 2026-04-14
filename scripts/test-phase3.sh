#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost}"
EMAIL="${EMAIL:-test@example.com}"
PASSWORD="${PASSWORD:-12345678}"
FULL_NAME="${FULL_NAME:-Test User}"
DEVICE_ID="${DEVICE_ID:-dc:b4:d9:13:ed:8c}"

echo "== Health =="
curl -s "$BASE_URL/nginx/health" | jq .
curl -s "$BASE_URL/api/health" | jq .

echo
echo "== Register =="
curl -s -X POST "$BASE_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"full_name\":\"$FULL_NAME\"}" | jq .

echo
echo "== Login =="
LOGIN_JSON=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
echo "$LOGIN_JSON" | jq .
TOKEN=$(echo "$LOGIN_JSON" | jq -r '.accessToken')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "Login failed: no accessToken"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

echo
echo "== Protected route smoke =="
curl -s "$BASE_URL/api/homes" -H "$AUTH_HEADER" | jq .

echo
echo "== Create home =="
HOME_JSON=$(curl -s -X POST "$BASE_URL/api/homes" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"name":"Home Pi","address":"Lab","timezone":"Asia/Ho_Chi_Minh"}')
echo "$HOME_JSON" | jq .
HOME_ID=$(echo "$HOME_JSON" | jq -r '.id')

echo
echo "== List homes =="
curl -s "$BASE_URL/api/homes" -H "$AUTH_HEADER" | jq .

echo
echo "== Update home =="
curl -s -X PUT "$BASE_URL/api/homes/$HOME_ID" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"name":"Home Pi Updated"}' | jq .

echo
echo "== Create room =="
ROOM_JSON=$(curl -s -X POST "$BASE_URL/api/homes/$HOME_ID/rooms" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"name":"Living Room","icon":"chair"}')
echo "$ROOM_JSON" | jq .
ROOM_ID=$(echo "$ROOM_JSON" | jq -r '.id')

echo
echo "== List rooms =="
curl -s "$BASE_URL/api/homes/$HOME_ID/rooms" -H "$AUTH_HEADER" | jq .

echo
echo "== Update room =="
curl -s -X PUT "$BASE_URL/api/rooms/$ROOM_ID" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"name":"Main Room"}' | jq .

echo
echo "== Register device =="
DEVICE_JSON=$(curl -s -X POST "$BASE_URL/api/devices" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "{\"device_id\":\"$DEVICE_ID\",\"name\":\"Smart Air\",\"home_id\":\"$HOME_ID\",\"room_id\":\"$ROOM_ID\"}")
echo "$DEVICE_JSON" | jq .

echo
echo "== List devices =="
curl -s "$BASE_URL/api/devices" -H "$AUTH_HEADER" | jq .

echo
echo "== Update device =="
curl -s -X PUT "$BASE_URL/api/devices/$DEVICE_ID" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Smart Air Updated\",\"room_id\":\"$ROOM_ID\"}" | jq .

echo
echo "== Get shadow =="
curl -s "$BASE_URL/api/devices/$DEVICE_ID/shadow" \
  -H "$AUTH_HEADER" | jq .

echo
echo "== Set desired shadow =="
curl -s -X PUT "$BASE_URL/api/devices/$DEVICE_ID/shadow/desired" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"power":true}' | jq .

echo
echo "== Get shadow again =="
curl -s "$BASE_URL/api/devices/$DEVICE_ID/shadow" \
  -H "$AUTH_HEADER" | jq .

echo
echo "== Send command =="
curl -s -X POST "$BASE_URL/api/devices/$DEVICE_ID/command" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"payload":{"power":true}}' | jq .

echo
echo "== Command history =="
curl -s "$BASE_URL/api/devices/$DEVICE_ID/commands" \
  -H "$AUTH_HEADER" | jq .

echo
echo "== Telemetry raw =="
curl -s "$BASE_URL/api/devices/$DEVICE_ID/telemetry?limit=5" \
  -H "$AUTH_HEADER" | jq .

echo
echo "== Telemetry aggregated =="
curl -s "$BASE_URL/api/devices/$DEVICE_ID/telemetry?agg=1h" \
  -H "$AUTH_HEADER" | jq .

echo
echo "== Logout =="
curl -s -X POST "$BASE_URL/api/auth/logout" \
  -H "$AUTH_HEADER" | jq .

echo
echo "Done"
