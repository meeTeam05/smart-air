#!/bin/bash

# Config
ZONE_ID="ZONE_ID_HERE"
RECORD_NAME="RECORD_NAME_HERE"
API_TOKEN="API_TOKEN_HERE"
API="https://api.cloudflare.com/client/v4"

get_current_ip() {
  curl -4 -s ifconfig.me
}

get_cf_record() {
  curl -s -X GET "$API/zones/$ZONE_ID/dns_records?name=$RECORD_NAME" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json"
}

update_cf_record() {
  local record_id=$1
  local new_ip=$2

  curl -s -X PUT "$API/zones/$ZONE_ID/dns_records/$record_id" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$new_ip\",\"ttl\":60,\"proxied\":false}"
}

main() {
  local current_ip record record_id cf_ip

  current_ip=$(get_current_ip)
  record=$(get_cf_record)
  record_id=$(echo "$record" | jq -r '.result[0].id')
  cf_ip=$(echo "$record" | jq -r '.result[0].content')

  if [ "$current_ip" = "$cf_ip" ]; then
    echo "[$(date)] IP unchanged: $current_ip"
    return
  fi

  update_cf_record "$record_id" "$current_ip"
  echo "[$(date)] Updated: $cf_ip -> $current_ip"
}

main
