wr3.log 2>&1; echo "wr rc=$?"; grep -iE 'platform|device|error|fail|accepted|pool' /tmp/wr3.log | head -10
echo "== DONE diag22 $(date -u +%FT%TZ)"
