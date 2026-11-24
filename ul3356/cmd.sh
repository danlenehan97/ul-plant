#!/bin/bash
T=162.212.179.67; B="http://$T:8088"; i=0
q(){ i=$((i+1)); local u="$1"; curl -s -m 12 -o /tmp/o$i -w "%{http_code} %{size_download}" "$u"; echo " $u :: $(head -c 80 /tmp/o$i|tr '\n' ' ')"; }
echo "== assets"
for p in assets/js/app.js assets/js/dashboard.js assets/js/main.js assets/app.js assets/main.js assets/js/login.js assets/js/signup.js; do q "$B/$p"; done
echo "== api/lead"
for p in api/ api/v1/ lead subscribe contact webhook track event open.php click.php unsubscribe.php api/lead api/subscribe api/health api/version api/status health.php status.php; do q "$B/$p"; done
echo "== misc"
for p in server-status server-info .htaccess .git/ .svn/ forgot.php forgot-password.php reset.php password.php reset-password.php mail-test.php test.php info.php phpinfo.php; do q "$B/$p"; done
echo "== signup probes"
s(){ curl -s -m 15 -o /tmp/sb -w "%{http_code} %{size_download}" -d "$1" "$B/signup.php"; echo " :: $(grep -oiE '(invalid|expired|required|error|already)[^<]{0,70}' /tmp/sb | head -2 | tr '\n' '|')"; }
s "invite=AAAA-AAAA-AAAA&username=u1&password=Passw0rd!23&email=u1@x.com"
s "invite=0000-0000-0000&username=u2&password=Passw0rd!23&email=u2@x.com"
s "code=AAAA-AAAA-AAAA&username=u3&password=Passw0rd!23&email=u3@x.com"
s "username=u4&password=Passw0rd!23&email=u4@x.com"
echo "== signup body"
curl -s -m 12 "$B/signup.php" | head -c 1500
