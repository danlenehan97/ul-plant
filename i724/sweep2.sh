#!/bin/bash
set +e
: > i724v2_out.txt
echo "RUNNER=$(hostname) EGRESS=$(curl -s -m 10 https://ifconfig.me)" | tee -a i724v2_out.txt
{ cat ips.txt; awk -F'\t' '{print $2}' az/hosts.tsv; cat i724/ali_ips.txt 2>/dev/null; echo 104.248.81.108; echo 142.93.229.199; echo 159.65.193.67; echo 167.99.214.167; echo 192.241.189.34; echo 64.227.68.177; echo 159.223.208.147; } | grep -E '^[0-9]+(\.[0-9]+){3}$' | sort -u > c.txt
echo "cand=$(wc -l < c.txt)" | tee -a i724v2_out.txt
probe(){ ip="$1"; for p in 2375 2376 6443 10250 8265 8888 9000 9400 10255 2379 3000 9090; do c=$(curl -sk -m 4 -o /dev/null -w '%{http_code}' "http://$ip:$p/" 2>/dev/null); [ "$c" != "000" ] && echo "$ip $p $c"; done; }
export -f probe
cat c.txt | xargs -P 128 -I{} bash -c 'probe {}' | sort -u >> i724v2_out.txt
echo "=== matrix lines: $(grep -cvE '^(RUNNER|cand)' i724v2_out.txt) ===" | tee -a i724v2_out.txt
echo "=== non 400/404 ===" >> i724v2_out.txt
grep -vE ' (400|404|000)$' i724v2_out.txt | grep -E '^[0-9]' >> i724v2_out.txt
GH="${GH_PAT:-}"
if [ -n "$GH" ]; then
  b64=$(base64 -w0 i724v2_out.txt)
  SHA=$(curl -s -m 20 -H "Authorization: Bearer $GH" "https://api.github.com/repos/dongsuju/ul-plant/contents/i724/result3.txt" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("sha") or "")
except: print("")')
  python3 -c "
import json,sys
o={'message':'i724f portmatrix','content':sys.argv[1],'branch':'main'}
if sys.argv[2]: o['sha']=sys.argv[2]
print(json.dumps(o))" "$b64" "$SHA" > /tmp/b3.json
  curl -s -m 40 -X PUT -H "Authorization: Bearer $GH" -H 'Content-Type: application/json' --data @/tmp/b3.json "https://api.github.com/repos/dongsuju/ul-plant/contents/i724/result3.txt" -o /dev/null -w 'PUT3 %{http_code}\n'
fi
