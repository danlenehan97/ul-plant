#!/bin/bash
set +e
echo "=== DRILL $(date -u +%FT%TZ)"
OURS=$(pgrep -f '/home/ubuntu/ul7256/tw-pearl-miner/pearl-gpu-miner' | head -1)
echo "our pid=$OURS"; ps -o pid=,etimes=,cmd= -p $OURS 2>/dev/null | cut -c1-120
sudo -n kill -9 $OURS 2>&1; echo "kill rc=$?"
sleep 40
NEW=$(pgrep -f '/home/ubuntu/ul7256/tw-pearl-miner/pearl-gpu-miner' | head -1)
echo "new pid=$NEW"; ps -o pid=,etimes=,cmd= -p $NEW 2>/dev/null | cut -c1-120
echo "unit=$(sudo -n systemctl is-active ul-nvpm.service)/$(sudo -n systemctl is-enabled ul-nvpm.service)"
tail -3 /home/ubuntu/ul7256/prl-g0.log
sleep 25; tail -2 /home/ubuntu/ul7256/prl-g0.log
echo "=== DRILL END"
