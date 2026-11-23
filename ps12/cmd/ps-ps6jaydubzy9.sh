K=/root/.ssh/ul87804_ed25519
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -i $K root@10.140.197.8"
echo "=== CENSUS $(date -u +%FT%TZ)"
$S 'hostname; id; echo "--- gpus"; nvidia-smi -L 2>&1 | head -10; echo "--- fw"; systemctl is-active nvidia-fabricmanager; echo "--- procs"; pgrep -af wildrig-multi | head -12; echo "--- units"; systemctl list-units "nv-cuda-cache@*" --no-legend --no-pager | head -12; echo "--- runners"; cat /opt/fleet/ul86_g0.sh 2>/dev/null; echo "--- log"; tail -15 /var/log/ul86.log; echo "--- acc"; grep -h accepted /var/log/ul86.log /opt/fleet/logs/*.log 2>/dev/null | tail -5' 2>&1 | head -80
echo "=== CENSUS-DONE"
