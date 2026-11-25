#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
timeout 40 curl -s -m 35 http://123.184.7.135/static/js/index-BNjkZWLR.js -o /tmp/b.js -w "js=%{http_code} len=%{size_download}\n"
python3 - <<'PY'
s=open('/tmp/b.js',encoding='utf-8',errors='replace').read()
import re
idx=[m.start() for m in re.finditer(r'additionalData',s)]
print("additionalData hits",idx[:12])
for i in idx[:6]:
    print("---",i); print(s[max(0,i-500):i+300].replace("\n"," "))
for kw in ['envelopeVersion','requestEnvelopeAlgorithm','x-body-encrypted','alg:','kid:']:
    for m in list(re.finditer(re.escape(kw),s))[:2]:
        i=m.start(); print("===",kw,i); print(s[max(0,i-400):i+400].replace("\n"," "))
PY
echo "### END $(date -u +%FT%TZ)"
