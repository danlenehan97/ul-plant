#!/bin/bash
# exec10: verify/repair g0023 miner state after exec8 interference
echo "=== ID"; hostname; date -u
echo "=== ACTIVE1"; systemctl is-active ul-g0 ul-g1 ul-g2 ul-g3 ul-g4 ul-g5 ul-g6 ul-g7 2>&1 | tr '\n' ' '; echo
echo "=== ACTIVE2"; systemctl is-active ul-prl-g0 ul-prl-g1 ul-prl-g2 ul-prl-g3 ul-prl-g4 ul-prl-g5 ul-prl-g6 ul-prl-g7 2>&1 | tr '\n' ' '; echo
echo "=== PS"; ps -eo pid,args | grep -iE '[w]ildrig|[s]rbminer|[p]eakminer' | head -12
echo "=== GUARD"; systemctl is-active ul-guard.timer ul-guard.service 2>&1 | tr '\n' ' '; echo; systemctl list-timers ul-guard.timer --no-pager 2>/dev/null | head -3
echo "=== REPAIR"
if ! systemctl is-active ul-g0 >/dev/null 2>&1; then echo "starting ul-g*"; systemctl start ul-g0 ul-g1 ul-g2 ul-g3 ul-g4 ul-g5 ul-g6 ul-g7; sleep 8; fi
for i in 0 1 2 3 4 5 6 7; do systemctl disable --now ul-prl-g$i >/dev/null 2>&1; done
echo "=== ACTIVE3"; systemctl is-active ul-g0 ul-g1 ul-g2 ul-g3 ul-g4 ul-g5 ul-g6 ul-g7 2>&1 | tr '\n' ' '; echo
echo "=== PS2"; ps -eo args | grep -c '[w]ildrig'
ps -eo args | grep '[w]ildrig' | head -2 | cut -c1-190
echo "=== LOG"; journalctl -u ul-g0 -n 12 --no-pager 2>/dev/null | tail -12
echo "=== POOLAPI"
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
timeout 20 curl -s -m 15 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o /dev/shm/wk.json; wc -c /dev/shm/wk.json
python3 - <<'PY'
import json
try:
    d=json.load(open('/dev/shm/wk.json'))
except Exception as e:
    print("parse fail",e); raise SystemExit
rows = d if isinstance(d,list) else d.get('data') or d.get('workers') or []
print("keys",list(d)[:6] if isinstance(d,dict) else "list")
for r in (rows if isinstance(rows,list) else [])[:60]:
    n=str(r.get('name') or r.get('worker') or '')
    if '123-184-7-135' in n: print(n, r.get('validShares') or r.get('valid'), r.get('hashrate') or r.get('hashRate'), r.get('lastShare') or r.get('last_share'))
PY
echo "=== DONE"
