#!/bin/bash
set +e
D=/dev/shm/ul5685/ctr; mkdir -p $D
B=http://192.168.0.24:18086
echo "=== submit.py"
timeout 10 curl -s -m 8 "$B/downloads/submit.py" -o $D/submit.py -w "%{http_code} %{size_download}\n"
sed -n 1,160p $D/submit.py
echo "=== grep API in submit.py"
grep -nE "url|api|upload|files|status|requests\.|post\(|put\(|json" $D/submit.py | head -60
echo "=== CREATE submission"
timeout 10 curl -s -m 8 -X POST -H 'Content-Type: application/json' -d '{"nickname":"ul-t2-123-184-7-135","model":"ulprobe5685","description":"probe"}' "$B/api/submissions" -w "\nHTTP %{http_code}\n"
echo "=== CREATE2 alt shape"
timeout 10 curl -s -m 8 -X POST -H 'Content-Type: application/json' -d '{"nickname":"ul-t2-123-184-7-135","model":"ulprobe5685b"}' "$B/api/submission" -w "\nHTTP %{http_code}\n"
echo "=== upload probe"
timeout 10 curl -s -m 8 -X POST -H 'Content-Type: application/json' -d '{"id":"HIJ-20261125-005939abe2b7","context":"H"}' "$B/upload" -w "\nHTTP %{http_code}\n"
echo "=== sub detail existing"
timeout 10 curl -s -m 8 "$B/api/submissions/HIJ-20261125-005939abe2b7" | head -c 2500; echo
echo "=== other app prefixes"
for p in /in300-marson /final-in-300 /out300 /in300-marson/api/benchmark; do
  echo "-- $p"; timeout 6 curl -s -m 5 "$B$p" -o $D/x -w "%{http_code} %{size_download}\n"; head -c 200 $D/x; echo
done
echo DONE
