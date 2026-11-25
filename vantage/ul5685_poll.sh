#!/bin/bash
set +e
B=http://192.168.0.24:18086
for s in HIJ-20261125-90a6dc03fa0f HIJ-20261125-e87d549785dd HIJ-20261125-a663ff607284; do
 echo "### $s"
 timeout 10 curl -s -m 8 "$B/api/submissions/$s" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(json.dumps({"status":d["status"],"error":d["error"],"result":d["result"],"files":d["files"]},ensure_ascii=False)[:1500])' 2>/dev/null
done
echo "=== all subs summary"
timeout 15 curl -s -m 12 "$B/api/submissions" | python3 -c '
import sys,json
d=json.load(sys.stdin)
L=d if isinstance(d,list) else d.get("submissions",d.get("items",[]))
print("count",len(L))
for s in L[:12]:
  print(s.get("id"),s.get("status"),s.get("model"),s.get("created_at"),[(k,v.get("filename"),v.get("status")) for k,v in (s.get("files") or {}).items()])
' 2>/dev/null
echo "=== benchmark"
timeout 8 curl -s -m 6 "$B/api/benchmark" | head -c 2000; echo
echo DONE
