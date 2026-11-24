#!/bin/bash
echo "PING $(hostname) $(id -u)"; nvidia-smi -L | head -2
