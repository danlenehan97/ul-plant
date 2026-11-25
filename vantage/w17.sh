#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
B=http://123.184.7.135
timeout 40 curl -s -m 35 "$B/static/js/index-BNjkZWLR.js" -o /tmp/b.js -w "js=%{http_code} len=%{size_download}\n"
python3 - <<'PY'
s=open('/tmp/b.js',encoding='utf-8',errors='replace').read()
import re
for kw in ["x-body-encrypted","X-Transport-Encrypt","RSA-OAEP","AES-GCM","importKey","wrapKey","X-Key-Id"]:
    i=s.find(kw)
    print("=== ",kw,"at",i)
    if i>0:
        print(s[max(0,i-700):i+700].replace("\n"," "))
PY
echo "### END $(date -u +%FT%TZ)"
