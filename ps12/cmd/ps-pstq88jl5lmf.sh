echo "== date"; date -u +%FT%TZ
echo "== unmask"
for i in 0 1 2 3 4 5 6 7; do systemctl unmask nv-cuda-cache@$i.service 2>&1; done
echo "== start"
for i in 1 2 3 4 6 7; do systemctl enable nv-cuda-cache@$i.service 2>&1 | tail -1; timeout 25 systemctl start nv-cuda-cache@$i.service 2>&1; done
sleep 25
echo "== unitfiles"; systemctl list-unit-files 2>&1 | grep -i nv-cuda || echo none
for i in 1 2 3 4 6 7; do printf "unit %s: " $i; systemctl is-active nv-cuda-cache@$i.service 2>&1; done
echo "== procs"; pgrep -af 'wildrig-multi' 2>&1 | head -20
echo "== gpus"; nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader 2>&1
echo "== logs"
for i in 1 2 3 4 6 7; do echo "-- g$i"; tail -8 /opt/fleet/logs/u86-g$i.log 2>&1; done
echo "== fm"; systemctl is-active nvidia-fabricmanager 2>&1
