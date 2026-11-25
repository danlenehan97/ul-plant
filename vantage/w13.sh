#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
B=http://123.184.7.135
timeout 40 curl -s -m 35 "$B/static/js/index-BNjkZWLR.js" -o /tmp/b.js -w "code=%{http_code} len=%{size_download}\n"
echo "### TITLE/BRAND"
grep -aoE "<title>[^<]*|logo|平台|终端|文件|执行|命令" /tmp/i80.html 2>/dev/null | head -5
timeout 10 curl -s -m 8 "$B/" | grep -aoE "<title>[^<]*" | head -2
echo "### API-STRINGS"
grep -aoE "[\"'\`]/[a-zA-Z0-9_./{}$:-]{3,60}[\"'\`]" /tmp/b.js | tr -d "\"'\`" | grep -E "api|file|exec|cmd|term|shell|ssh|upload|download|dir|list|login|auth|token|run|code" | sort -u | head -60
echo "### BASE"
grep -aoE "(baseURL|baseUrl|VITE_[A-Z_]+|/prod-api|/api)[\"']?\s*[:=]\s*[\"'][^\"']{0,60}" /tmp/b.js | sort -u | head -20
echo "### PROBE"
for p in /api/file/list /api/file/read /api/file/write /api/files /api/exec /api/run /api/terminal /api/shell /api/dir/list /api/tree /api/system/info /prod-api/file/list /api/v1/file/list /api/login /api/auth/login /api/user/login; do
  R=$(timeout 8 curl -s -m 6 -o /tmp/o -w "%{http_code}" "$B$p"); C=$(head -c 80 /tmp/o | tr '\n' ' '); case "$C" in *DOCTYPE*) C="(spa)";; esac; echo "P $p => $R $C"
done
echo "### END $(date -u +%FT%TZ)"
