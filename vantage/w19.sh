#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
timeout 40 curl -s -m 35 http://123.184.7.135/static/js/index-BNjkZWLR.js -o /tmp/b.js -w "js=%{http_code} len=%{size_download}\n"
python3 - <<'PY'
s=open('/tmp/b.js',encoding='utf-8',errors='replace').read()
for i in (1344360,1344648,1345000,1345400):
    print("===",i)
    print(s[max(0,i-900):i+900].replace("\n"," "))
PY
echo "### END $(date -u +%FT%TZ)"
