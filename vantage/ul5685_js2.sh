#!/bin/bash
set +e
D=/dev/shm/ul5685/js2; mkdir -p $D
B=http://192.168.0.24:18086
timeout 15 curl -s -m 12 "$B/app.js" -o $D/app.js -w "app.js %{http_code} %{size_download}\n"
timeout 15 curl -s -m 12 "$B/" -o $D/index.html -w "index %{http_code} %{size_download}\n"
echo "=== scripts referenced"
grep -oE 'src="[^"]+"' $D/index.html | sort -u
echo "=== grep app.js"
grep -nE "files/|edit_token|commit|X-Filename|h5ad|upload|/api/|status|Download|download" $D/app.js | head -120
echo "=== base64 chunks"
B64=$(base64 -w0 $D/app.js); echo "LEN=${#B64}"
echo "@@@APPJS_B64_BEGIN"
echo "$B64" | cut -c1-60000
echo "@@@PART1_END"
echo "$B64" | cut -c60001-120000
echo "@@@PART2_END"
echo "$B64" | cut -c120001-180000
echo "@@@PART3_END"
echo "$B64" | cut -c180001-240000
echo "@@@PART4_END"
echo DONE
