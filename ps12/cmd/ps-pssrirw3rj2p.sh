#!/bin/bash
tail -40 /opt/fleet/logs/w-ps-pssrirw3rj2p-g0.log > /tmp/pre.log 2>&1
pkill -f ps_sup.sh
pkill -f 'wildrig-multi .*ul-ps-pssrirw3rj2p-g0'
sleep 2
setsid /opt/fleet/bin/wildrig-multi --algo pearlhash --opencl-platforms nvidia -d 0 -o stratum+ssl://pool.pearlhash.xyz:9443 -u prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz.ul-ps-pssrirw3rj2p-g0 -p x -i 8 --no-color >> /opt/fleet/logs/w-pearl.log 2>&1 &
sleep 20
echo '--- pre ---'; tail -30 /tmp/pre.log
echo '--- pearl ---'; tail -20 /opt/fleet/logs/w-pearl.log
