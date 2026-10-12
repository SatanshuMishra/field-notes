#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "usage: make_appcast.sh <version> <build number> <dmg file> <dmg url> <signature> <rfc 2822 date>" >&2
  exit 64
fi

dmg="$3"

if [[ ! -f "$dmg" ]]; then
  echo "::error::No disk image at $dmg." >&2
  exit 1
fi

escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}

version="$(escape "$1")"
build="$(escape "$2")"
url="$(escape "$4")"
signature="$(escape "$5")"
published="$(escape "$6")"
length="$(escape "$(wc -c < "$dmg" | tr -d ' \t\n')")"

cat <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Field Notes</title>
    <item>
      <title>Version $version</title>
      <pubDate>$published</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>12.0</sparkle:minimumSystemVersion>
      <enclosure url="$url" length="$length" type="application/octet-stream" sparkle:edSignature="$signature"/>
    </item>
  </channel>
</rss>
APPCAST
