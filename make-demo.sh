#!/usr/bin/env bash
# Build the demo video from the app itself — deterministic frame capture,
# not a screen recording, so there are no dropped frames.
# Needs: Chrome (headless screenshots) + ffmpeg.  ./make-demo.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
FF="${FF:-$(command -v ffmpeg)}"
W=1400; H=900
F="$HERE/.demo-frames"; rm -rf "$F"; mkdir -p "$F"

seed_and_shoot() { # $1=index $2=duration $3=python-state-json $4=after-load-js
  local tmp; tmp="$(mktemp -t sgdemo).html"
  python3 - "$HERE/index.html" "$tmp" "$3" "$4" <<'PY'
import sys
src,out,state,js = sys.argv[1:5]
s=open(src,encoding="utf-8").read()
head=""
if state:
    head=('<script>try{localStorage.setItem("syntax-gym/seen-landing","1");'
          'localStorage.setItem("syntax-gym/last-track","django");'
          'localStorage.setItem("syntax-gym/v3/django",%s);}catch(e){}</script>' % state)
tail=('<script>addEventListener("load",()=>{setTimeout(()=>{try{%s}catch(e){}},260)})</script>' % js) if js else ""
open(out,"w",encoding="utf-8").write(s.replace("<body>","<body>\n"+head,1).replace("</body>",tail+"</body>"))
PY
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size="$W","$H" \
    --virtual-time-budget=9000 --screenshot="$F/$(printf '%03d' "$1").png" \
    "file://$tmp" 2>/dev/null
  rm -f "$tmp"
  printf "file '%s'\nduration %s\n" "$F/$(printf '%03d' "$1").png" "$2" >> "$F/list.txt"
}

ST='{"i":0,"stage":"%s","seenBrief":{"1":true},"taught":{"p1-version":true},"results":{},"mcResults":%s,"attempts":{},"firstTry":{},"hinted":{},"revealed":{},"streak":0,"best":0,"redo":[],"phase":"main","ai":%s}'
j(){ python3 -c "import json,sys;print(json.dumps(sys.argv[1]))" "$1"; }
ANS="python -m django --version"
i=0

echo "frame: landing";  seed_and_shoot $((i++)) 2.6 "" ""
echo "frame: learn";    seed_and_shoot $((i++)) 2.6 "$(j "$(printf "$ST" teach '{}' true)")" ""
echo "frame: choose";   seed_and_shoot $((i++)) 2.2 "$(j "$(printf "$ST" choose '{}' true)")" ""
echo "frame: locked";   seed_and_shoot $((i++)) 2.8 "$(j "$(printf "$ST" choose '{}' true)")" \
  'var o=document.querySelectorAll(".opt");o[0].click();document.getElementById("lockBtn").click();'
echo "frame: write";    seed_and_shoot $((i++)) 1.3 "$(j "$(printf "$ST" write '{"p1-version":true}' true)")" ""
for n in 6 12 18 26; do
  echo "frame: typing $n"
  seed_and_shoot $((i++)) 0.42 "$(j "$(printf "$ST" write '{"p1-version":true}' true)")" \
    "var t=document.getElementById('entry');t.value='$ANS'.slice(0,$n);t.dispatchEvent(new Event('input'));"
done
echo "frame: verdict"; seed_and_shoot $((i++)) 3.2 "$(j "$(printf "$ST" write '{"p1-version":true}' false)")" \
  "var t=document.getElementById('entry');t.value='$ANS';t.dispatchEvent(new Event('input'));document.getElementById('checkBtn').click();"

echo "encoding…"
"$FF" -y -loglevel error -f concat -safe 0 -i "$F/list.txt" \
  -vf "fps=30,scale=1400:-2:flags=lanczos,format=yuv420p" \
  -c:v libx264 -preset slow -crf 20 -movflags +faststart "$HERE/docs/demo.mp4"
"$FF" -y -loglevel error -f concat -safe 0 -i "$F/list.txt" \
  -vf "fps=12,scale=900:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer" \
  "$HERE/docs/demo.gif"
rm -rf "$F"
ls -lh "$HERE/docs/demo.mp4" "$HERE/docs/demo.gif" | awk '{print $9, $5}'
