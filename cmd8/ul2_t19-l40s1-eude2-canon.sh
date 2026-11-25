set +e
echo "== ping $(date -u +%FT%TZ) host=$(hostname -s) uid=$(id -u)"
ps -eo pid,args | grep -E '[p]oll.sh|[p]eakminer|[k]rig' | cut -c1-120
tail -5 /tmp/ul2o.txt 2>/dev/null | cut -c1-160
echo done
