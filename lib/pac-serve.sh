#!/bin/bash
exec 2>/dev/null  # stderr de sokete gider; PAC bozulmasın
# launchd her bağlantıda bunu çalıştırır (stdin/stdout = soket).
# Tarayıcıya PAC dosyası verir: yalnızca listedeki siteler yerel SpoofDPI'a
# gider, diğer her şey DIRECT (hiç dokunulmaz).
. /usr/local/macdpi/lib/common.sh

# İstek başlıklarını boş satıra kadar oku (okumadan kapatmak bağlantıyı koparabilir).
while IFS= read -r -t 3 line; do
  line=$(printf '%s' "$line" | tr -d '\r')
  [ -z "$line" ] && break
done

if [ -f "$OFF_FLAG" ]; then
  body='function FindProxyForURL(url, host) { return "DIRECT"; }'
else
  list=$(clean_domains | sed 's/.*/"&"/' | paste -sd, -)
  body="function FindProxyForURL(url, host) {
  host = host.toLowerCase();
  var d = [$list];
  for (var i = 0; i < d.length; i++) {
    if (host == d[i] || dnsDomainIs(host, \".\" + d[i]))
      return \"PROXY 127.0.0.1:$PROXY_PORT; DIRECT\";
  }
  return \"DIRECT\";
}"
fi

len=$(printf '%s' "$body" | wc -c | tr -d ' ')
printf 'HTTP/1.0 200 OK\r\nContent-Type: application/x-ns-proxy-autoconfig\r\nContent-Length: %s\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n%s' "$len" "$body"
