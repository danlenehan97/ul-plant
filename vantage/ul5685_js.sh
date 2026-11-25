#!/bin/bash
set +e
D=/dev/shm/ul5685/js; mkdir -p $D
B=http://192.168.0.24:18086
echo "=== HTML head refs"
timeout 10 curl -s -m 8 "$B/" -o $D/index.html -w "index %{http_code} %{size_download}\n"
grep -oE '(src|href)="[^"]+"' $D/index.html | sort -u | head -40
echo "=== scripts"
for f in $(grep -oE 'src="[^"]+\.js[^"]*"' $D/index.html | sed 's/src="//;s/"$//' | sort -u); do
  echo "-- $f"
  timeout 10 curl -s -m 8 "$B$f" -o "$D/$(basename ${f%%\?*})" -w "  %{http_code} %{size_download}\n"
done
echo "=== api/benchmark"
timeout 8 curl -s -m 6 "$B/api/benchmark" | head -c 3000; echo
echo "=== health"
timeout 8 curl -s -m 6 "$B/health"; echo
echo "=== endpoints in all assets"
cat $D/*.html $D/*.js 2>/dev/null | grep -oE '/api/[A-Za-z0-9_./<>${}-]*' | sort | uniq -c | sort -rn | head -40
echo "=== upload/fetch snippets"
grep -nE "api/submissions|/upload|FormData|files\[|\.append\(|method: *'POST'|method: *\"POST\"|filename|path" $D/*.js 2>/dev/null | head -80
echo "=== INDEX OF JS =="
ls -la $D
echo DONE
