#!/bin/zsh
# Measures the example app's frame rate on an iOS simulator, one scenario at a time.
# Usage: Scripts/measure.sh <simulator UDID> <output dir> [scenario ...]
# Scenarios default to: scrollonly legacy-scroll glow-scroll input-scroll
# Writes <output dir>/perf_<scenario>.json and summary.tsv; the last line is MEASURED <n> or FAILED <reason>.
set -u
D=$1; OUT=${2:a}; shift 2
SCENARIOS=("$@"); [ $#SCENARIOS -eq 0 ] && SCENARIOS=(scrollonly legacy-scroll glow-scroll input-scroll)
ROOT=${0:a:h:h}; BID=com.example.MarqueeGlowExample; SECS=10
DD=$ROOT/.build/example-dd
mkdir -p $OUT
xcodebuild -project $ROOT/Examples/MarqueeGlowExample/MarqueeGlowExample.xcodeproj -scheme MarqueeGlowExample \
  -configuration Release -sdk iphonesimulator -destination "id=$D" -derivedDataPath $DD \
  CODE_SIGNING_ALLOWED=NO build >| $OUT/build.log 2>&1 || { grep error: $OUT/build.log | head; echo "FAILED build"; exit 1; }
xcrun simctl install $D $DD/Build/Products/Release-iphonesimulator/MarqueeGlowExample.app || { echo "FAILED install"; exit 1; }
DATA=$(xcrun simctl get_app_container $D $BID data)
for s in $SCENARIOS; do
  rm -f $DATA/Documents/perf_$s.json
  xcrun simctl launch --terminate-running-process $D $BID -scenario $s -measure $SECS >/dev/null
  for i in $(seq 1 30); do [ -f $DATA/Documents/perf_$s.json ] && break; sleep 1; done
  cp $DATA/Documents/perf_$s.json $OUT/ 2>/dev/null || echo "$s: no result"
done
xcrun simctl terminate $D $BID 2>/dev/null
python3 -I - $OUT $SCENARIOS <<'PY'
import json, os, sys
out, names = sys.argv[1], sys.argv[2:]
keys = ["scenario", "fps", "screenMaxFPS", "hitches", "hitchMsPerSec", "p50ms", "p95ms", "p99ms", "maxms"]
rows = [json.load(open(f"{out}/perf_{n}.json")) for n in names if os.path.exists(f"{out}/perf_{n}.json")]
lines = ["\t".join(keys)] + ["\t".join(str(r.get(k)) for k in keys) for r in rows]
open(f"{out}/summary.tsv", "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
print(f"MEASURED {len(rows)}" if len(rows) == len(names) else f"FAILED {len(names) - len(rows)} scenarios missing")
PY
