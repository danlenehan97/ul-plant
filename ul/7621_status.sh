#!/bin/bash
# status collector, runs ON the target host
set -u
SUDO=""; [ "$(id -u)" = 0 ] || SUDO="sudo -n"
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
echo "GPU_COUNT=$N"
i=0
while [ "$i" -lt "$N" ]; do
  echo "== card g$i"
  $SUDO systemctl is-active nv-cuda-cache@g$i.service 2>/dev/null || true
  curl -s -m 5 "http://127.0.0.1:333$i/" 2>/dev/null | head -c 300 || true
  echo
  L=$($SUDO ls -t /opt/ul/logs/*-g$i.log 2>/dev/null | head -1)
  if [ -n "$L" ]; then
    echo "LOG=$L"
    $SUDO grep -aE 'accepted|difficulty|stratum|hashrate|error' "$L" | tail -6 || true
  else
    echo "LOG=none"
  fi
  i=$((i+1))
done
echo "--- pgrep ---"
pgrep -af 'pearl-gpu-miner|wildrig' || echo none
echo "STATUS_DONE"
