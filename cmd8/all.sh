#!/bin/bash
TOK=05a580ce02c1b4b40b081cc9f6e028
API=https://api.paperspace.com/v1
for id in ps2wdgalkxz9 ps4mmfu9f2j0 psc7h6ova84p psl6y8sibqt4 psx06e5f11ke; do
  c=$(curl -s -m 30 -X PATCH -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' -d '{}' -o /tmp/r.json -w '%{http_code}' "$API/machines/$id/start")
  echo "$id PATCHstart $c $(head -c 160 /tmp/r.json)"
  sleep 2
done
echo "--- states"
curl -s -m 25 -H "Authorization: Bearer $TOK" "$API/machines" | python3 -c 'import json,sys
d=json.load(sys.stdin)
for m in sorted(d.get("items",[]),key=lambda x:x["id"]): print(m["id"],m["state"],m.get("publicIp"))'
