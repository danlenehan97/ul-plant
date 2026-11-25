#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
H=192.168.0.22
log(){ echo "$@" | cut -c1-700; }
log "### START-P3 $(date -u +%FT%TZ)"
log "### P18000-PATHS"
timeout 8 curl -s -m 6 http://$H:18000/openapi.json > /tmp/o18.json
python3 - <<'PY' 
import json
d=json.load(open('/tmp/o18.json'))
for p,m in d.get('paths',{}).items():
    for meth,op in m.items():
        rb=json.dumps(op.get('requestBody',{}))[:180]
        print(meth.upper(),p,'|',rb)
PY
log "### P14998-PATHS"
timeout 8 curl -s -m 6 http://$H:14998/openapi.json > /tmp/o14.json
python3 - <<'PY'
import json
d=json.load(open('/tmp/o14.json'))
for p,m in d.get('paths',{}).items():
    for meth,op in m.items():
        if meth=='get': continue
        rb=json.dumps(op.get('requestBody',{}))[:90]
        print(meth.upper(),p,'|',rb)
print('SCHEMAS:', ','.join(d.get('components',{}).get('schemas',{}).keys()))
PY
log "### RDB"
for s in "select sqlite_version() as v" "select version() as v" "select * from sqlite_master limit 5" "PRAGMA database_list" "select current_user as u, current_database() as db" "select name from sqlite_temp_master limit 5"; do
  R=$(timeout 10 curl -s -m 8 -X POST http://$H:18000/execute -H 'Content-Type: application/json' -d "$(SQL="$s" python3 -c 'import json,os;print(json.dumps({"engine":"relational_db","operation":"query","arguments":{"sql":os.environ["SQL"]}}))')" -w "|%{http_code}")
  log "RDB <<$s>> => $(echo "$R"|tr '\n' ' ')"
done
log "### RDB-WRITE-TRY"
for s in "select readfile('/etc/passwd') as t" "COPY (SELECT 'ULRDB') TO '/tmp/ul_rdb.txt'" "attach database '/tmp/ul_att.db' as x" "create table x.t(a int)"; do
  R=$(timeout 10 curl -s -m 8 -X POST http://$H:18000/execute -H 'Content-Type: application/json' -d "$(SQL="$s" python3 -c 'import json,os;print(json.dumps({"engine":"relational_db","operation":"query","arguments":{"sql":os.environ["SQL"]}}))')" -w "|%{http_code}")
  log "RDBW <<$s>> => $(echo "$R"|tr '\n' ' ')"
done
log "### PDFOCR"
for a in '{"path":"/etc/passwd","operation":"x"}' '{"file":"/etc/passwd"}' '{"path":"/tmp/nonexist.pdf","query":"x"}'; do
  R=$(timeout 10 curl -s -m 8 -X POST http://$H:18000/execute -H 'Content-Type: application/json' -d "{\"engine\":\"pdf_ocr\",\"operation\":\"parse\",\"arguments\":$a}" -w "|%{http_code}")
  log "PDF $a => $(echo "$R"|tr '\n' ' ')"
done
log "### BAD-ENGINE-TRACE"
R=$(timeout 10 curl -s -m 8 -X POST http://$H:18000/execute -H 'Content-Type: application/json' -d '{"engine":"nope","operation":"x","arguments":{}}' -w "|%{http_code}"); log "BADE => $(echo "$R"|tr '\n' ' ')"
R=$(timeout 10 curl -s -m 8 -X POST http://$H:18000/execute -H 'Content-Type: application/json' -d '{"engine":"calculator","operation":"evaluate","arguments":{}}' -w "|%{http_code}"); log "CALCERR => $(echo "$R"|tr '\n' ' ')"
log "### 14998-LLM"
for b in '{"prompt":"hi"}' '{"prompt":"2+2"}' '{"model_path":"/tmp/ul_p2.txt","prompt":"hi"}' '{"messages":[{"role":"user","content":"hi"}]}'; do
  R=$(timeout 30 curl -s -m 25 -X POST http://$H:14998/llm/generate -H 'Content-Type: application/json' -d "$b" -w "|%{http_code}"); log "LLM $b => $(echo "$R"|tr '\n' ' '|cut -c1-260)"
done
log "### 14998-POINT2-3"
for ep in point2 point3; do
  R=$(timeout 20 curl -s -m 15 -X POST http://$H:14998/$ep/analyze -H 'Content-Type: application/json' -d '{"text":"hi"}' -w "|%{http_code}"); log "$ep => $(echo "$R"|tr '\n' ' '|cut -c1-300)"
done
R=$(timeout 20 curl -s -m 15 -X POST http://$H:14998/eventclassify -H 'Content-Type: application/json' -d '{"text":"hi"}' -w "|%{http_code}"); log "EVCLS => $(echo "$R"|tr '\n' ' '|cut -c1-300)"
R=$(timeout 20 curl -s -m 15 -X POST http://$H:14998/api/batch_test -H 'Content-Type: application/json' -d '{"text":"hi"}' -w "|%{http_code}"); log "BATCH => $(echo "$R"|tr '\n' ' '|cut -c1-300)"
log "### WRITE-PROOF"
echo '{"a":1,"ul":"5512"}' > /tmp/m3.json
for fn in "/tmp/ul_p3.json" "ul_rel.json" "../ul_rel2.json"; do
  R=$(timeout 10 curl -s -m 8 -X POST http://$H:14998/upload -F "file=@/tmp/m3.json;filename=$fn" -w "|%{http_code}"); log "WR $fn => $(echo "$R"|tr '\n' ' '|cut -c1-240)"
done
R=$(timeout 8 curl -s -m 6 "http://$H:14998/files?pageSize=8" -w "|%{http_code}"); log "LIST => $(echo "$R"|tr '\n' ' '|cut -c1-700)"
log "### DONE-P3 $(date -u +%FT%TZ)"
