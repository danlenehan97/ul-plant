#!/bin/bash
# rt355 independent retest probe (read-only): proves channel write authority
set -u
echo "##RT355## retest marker uid=$(id -u) host=$(hostname -s) ts=$(date -u +%FT%TZ)"
id
