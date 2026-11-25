#!/bin/bash
exec ssh -i /tmp/ibmX.pem -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -W "$1:$2" ubuntu@10.243.0.24
