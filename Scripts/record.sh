#!/bin/zsh
# Records the example app on a booted simulator and converts it to mp4 and gif.
# Usage: Scripts/record.sh <simulator UDID> <dark|light> <output file stem> [seconds] [-- launch arguments...]
# Default launch arguments keep the input bar glowing. The last line is RECORDED <files> or FAILED <step>.
set -u
D=$1; MODE=$2; STEM=${3:a}; SECS=6
shift 3
if [ $# -gt 0 ] && [ "$1" != "--" ]; then SECS=$1; shift; fi
[ "${1:-}" = "--" ] && shift
ARGS=("$@"); [ $#ARGS -eq 0 ] && ARGS=(-generating YES)
command -v ffmpeg >/dev/null || { echo "FAILED ffmpeg not installed"; exit 1; }
xcrun simctl ui $D appearance $MODE || { echo "FAILED appearance"; exit 1; }
xcrun simctl launch --terminate-running-process $D com.example.MarqueeGlowExample $ARGS >/dev/null || { echo "FAILED launch"; exit 1; }
sleep 2
RAW=$STEM.raw.mp4; rm -f $RAW
xcrun simctl io $D recordVideo --codec=h264 --force $RAW 2>/dev/null &
P=$!
sleep $SECS
kill -INT $P; wait $P
[ -s $RAW ] || { echo "FAILED recording"; exit 1; }
ffmpeg -loglevel error -y -i $RAW -vf "scale=-2:1280" -c:v libx264 -pix_fmt yuv420p -crf 23 -movflags +faststart $STEM.mp4 \
  || { echo "FAILED mp4"; exit 1; }
ffmpeg -loglevel error -y -i $RAW -vf "fps=20,scale=320:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" $STEM.gif \
  || { echo "FAILED gif"; exit 1; }
rm -f $RAW
echo "RECORDED $STEM.mp4 $STEM.gif"
