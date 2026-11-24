#!/bin/bash
T=162.212.179.67
echo "=== 8070 overview"
curl -s -m 20 -i "http://$T:8070/api/overview" | head -40
echo "=== 8070 sites noauth"
curl -s -m 20 -i "http://$T:8070/api/sites" | head -20
echo "=== 8088 login"
curl -s -m 20 -i "http://$T:8088/login.php" | head -60
echo "=== 8088 root"
curl -s -m 20 -i "http://$T:8088/" | head -30
echo "=== 8088 signup"
curl -s -m 20 -i "http://$T:8088/signup.php" | head -80
echo "=== 8080 greenmail api"
curl -s -m 20 -i "http://$T:8080/api/user" | head -30
echo "=== 7860 comfy"
curl -s -m 20 -i "http://$T:7860/system_stats" | head -20
echo "=== 3080"
curl -s -m 20 -i "http://$T:3080/api/user" | head -20
