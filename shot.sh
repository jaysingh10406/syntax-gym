#!/usr/bin/env bash
# Screenshot the app headlessly. No Playwright needed — Chrome does this natively.
#   ./shot.sh                      landing screen
#   ./shot.sh choose django 0      a specific track/drill at the Choose stage
#   ./shot.sh write python 3       ... at the Write stage
set -euo pipefail
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
HERE="$(cd "$(dirname "$0")" && pwd)"
STAGE="${1:-}"; TRACK="${2:-django}"; IDX="${3:-0}"
OUT="$HERE/shot.png"; SRC="file://$HERE/index.html"
if [ -n "$STAGE" ]; then
  TMP="$(mktemp -t sg).html"
  python3 - "$HERE/index.html" "$TMP" "$STAGE" "$TRACK" "$IDX" <<'PY'
import sys,json
src,out,stage,track,idx=sys.argv[1:6]
s=open(src,encoding="utf-8").read()
state={"i":int(idx),"stage":stage,"seenBrief":{"1":True,"2":True,"3":True,"4":True},
 "results":{},"mcResults":{},"attempts":{},"firstTry":{},"hinted":{},"revealed":{},
 "streak":0,"best":0,"redo":[],"phase":"main","ai":True}
seed=('<script>try{localStorage.setItem("syntax-gym/last-track",%s);'
      'localStorage.setItem("syntax-gym/v3/"+%s,%s);}catch(e){}</script>'
      % (json.dumps(track),json.dumps(track),json.dumps(json.dumps(state))))
open(out,"w",encoding="utf-8").write(s.replace("<body>","<body>\n"+seed,1))
PY
  SRC="file://$TMP"
fi
"$CHROME" --headless=new --disable-gpu --hide-scrollbars \
  --window-size="${W:-1480}","${H:-1400}" --virtual-time-budget=8000 \
  --screenshot="$OUT" "$SRC" 2>/dev/null
echo "wrote $OUT"
