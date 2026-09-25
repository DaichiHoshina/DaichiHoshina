#!/usr/bin/env bash
# README の画像 (assets/*-washi.png) を SVG から再生成する。macOS 専用 (sips と Chrome を使う)。
#
# 1. SVG を土台と立体文字 (class="liquid") の層に分ける
# 2. 土台は sips、立体文字は Chrome で描く (sips は文字のグラデーションや光源を描けない)
# 3. 土台に和紙の質感を重ねてから立体文字を重ねる (文字の艶に和紙の模様を重ねない)

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
assets_dir="$script_dir/../assets"
chrome=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

image_size() {
  ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$1"
}

# $1 SVG, $2 出力名 (拡張子なし)。$work_dir/$2-base.png と、立体文字があれば $2-layer.png を作る
render_svg() {
  local svg=$1 name=$2 width height
  python3 "$script_dir/split-liquid.py" "$svg" "$work_dir/$name-base.svg" "$work_dir/$name-layer.svg"
  sips -s format png "$work_dir/$name-base.svg" --out "$work_dir/$name-base.png" >/dev/null
  if [[ -f "$work_dir/$name-layer.svg" ]]; then
    IFS=, read -r width height < <(image_size "$work_dir/$name-base.png")
    "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
      --default-background-color=00000000 --window-size="$width,$height" \
      --screenshot="$work_dir/$name-layer.png" "file://$work_dir/$name-layer.svg" 2>/dev/null
  fi
}

# $1 土台 PNG, $2 名前, $3 出力 PNG
finish() {
  local base=$1 name=$2 output=$3 width height
  bash "$script_dir/render-washi.sh" "$base" "$work_dir/$name-washi.png"
  if [[ -f "$work_dir/$name-layer.png" ]]; then
    IFS=, read -r width height < <(image_size "$work_dir/$name-washi.png")
    ffmpeg -hide_banner -loglevel error -y -i "$work_dir/$name-washi.png" -i "$work_dir/$name-layer.png" \
      -filter_complex "[1:v]scale=${width}:${height}:flags=lanczos[layer];[0:v][layer]overlay=format=auto" \
      "$output"
  else
    cp "$work_dir/$name-washi.png" "$output"
  fi
}

# hero は写真の上に文字の SVG を重ね、角丸のマスクで外側を透明にする
render_svg "$assets_dir/profile.svg" hero
sips -s format png "$assets_dir/hero-mask.svg" --out "$work_dir/hero-mask.png" >/dev/null
ffmpeg -hide_banner -loglevel error -y \
  -i "$assets_dir/hero.png" -i "$work_dir/hero-base.png" -i "$work_dir/hero-mask.png" \
  -filter_complex "[0:v]scale=1200:400:flags=bicubic,format=rgba[photo];[photo][1:v]overlay=format=auto[card];[2:v]format=rgba,alphaextract[mask];[card][mask]alphamerge" \
  "$work_dir/hero-photo.png"
finish "$work_dir/hero-photo.png" hero "$assets_dir/hero-profile-washi.png"

for name in project-claude-code-config project-dev-tools project-golang-practice link-projects link-zenn; do
  render_svg "$assets_dir/$name.svg" "$name"
  finish "$work_dir/$name-base.png" "$name" "$assets_dir/$name-washi.png"
done
