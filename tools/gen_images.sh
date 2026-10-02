#!/usr/bin/env bash
# art/prompts/<id>.txt 프롬프트로 Codex 이미지 생성 → art/out/<id>.png
# 이미 있는 이미지는 건너뛴다. 동시 실행 수는 PARALLEL (기본 4).
#   bash tools/gen_images.sh                 -> 전부
#   bash tools/gen_images.sh Slime GameIcon  -> 지정한 것만
cd "$(dirname "$0")/.." || exit 1
CODEX="${CODEX:-$HOME/.codex/plugins/.plugin-appserver/codex.exe}"
PARALLEL="${PARALLEL:-4}"
OUT="art/out"
mkdir -p "$OUT" "$OUT/logs"

gen_one() {
  id="$1"
  [ -s "$OUT/$id.png" ] && { echo "skip $id"; return 0; }
  size="1024x1024"
  case "$id" in Thumbnail_*|UI_MapParchment) size="1536x1024 (landscape)";; esac
  "$CODEX" exec --skip-git-repo-check -C "$(pwd)/$OUT" -s workspace-write \
    --add-dir "$(pwd)/art/prompts" -o "logs/$id.last.txt" \
    "Read the prompt file $(pwd)/art/prompts/$id.txt. Use your image generation tool to create exactly ONE image from that prompt text verbatim (size $size; if the prompt asks for a transparent background, generate with a transparent background). Then copy the generated PNG into the current directory with the exact file name $id.png. Do not create any other files. Reply with only the saved file path." \
    > "$OUT/logs/$id.log" 2>&1
  if [ -s "$OUT/$id.png" ]; then echo "ok   $id"; else echo "FAIL $id"; fi
}
export -f gen_one
export CODEX OUT

if [ "$#" -gt 0 ]; then ids="$*"; else ids=$(ls art/prompts | sed 's/\.txt$//'); fi
printf '%s\n' $ids | xargs -P "$PARALLEL" -I{} bash -c 'gen_one "$@"' _ {}
echo "done: $(ls "$OUT"/*.png 2>/dev/null | wc -l) images in $OUT"
