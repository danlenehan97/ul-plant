#!/bin/bash
T=162.212.179.67
P="login.php signup.php index.php dashboard.php home.php logout.php app.php settings.php integrations.php agents.php agent.php team.php users.php user.php profile.php admin.php api.php inc/api.php api/index.php healthz api/healthz robots.txt .git/config .git/HEAD composer.json .env config.php db.php inc/config.php inc/db.php lib/db.php includes/config.php assets/css/dashboard.css assets/js/app.js uploads/ backup/ www.zip site.zip dashboard.zip .htaccess sitemap.xml favicon.ico mail.php inbox.php crm.php leads.php campaigns.php media.php poster.php"
for p in $P; do
  out=$(curl -s -m 12 -o /tmp/x -w "%{http_code} %{size_download} %{content_type}" "http://$T:8088/$p")
  echo "$out  /$p  :: $(head -c 90 /tmp/x | tr '\n' ' ')"
done
echo "=== css"
curl -s -m 15 "http://$T:8088/assets/css/dashboard.css?v=v3.110.1" | head -c 300
