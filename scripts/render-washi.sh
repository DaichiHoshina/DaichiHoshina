#!/usr/bin/env bash

set -euo pipefail

input_path=$1
output_path=$2
target_width=${3:-}
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
texture_path="$script_dir/../assets/washi-texture.png"

IFS=, read -r source_width source_height < <(
  ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$input_path"
)

if [[ -n "$target_width" ]]; then
  output_width=$target_width
  output_height=$((source_height * output_width / source_width))
else
  output_width=$source_width
  output_height=$source_height
fi

# 紙の地色。乗算で明るい部分ほど沈み、濃い文字はほぼ変わらない
paper_tint=#ECE7DE
# テクスチャ元画像はほぼ白で濃淡が薄いため、ぼかしとの差分で繊維だけを取り出して増幅する
fiber_gain=4
fiber_opacity=0.9

ffmpeg -hide_banner -loglevel error -y \
  -i "$input_path" \
  -i "$texture_path" \
  -f lavfi -i "color=c=${paper_tint}:s=${output_width}x${output_height}" \
  -filter_complex "[0:v]scale=${output_width}:${output_height}:flags=lanczos,format=gbrap,split[base][alpha-source];[alpha-source]alphaextract[alpha];[2:v]format=gbrap,scale=${output_width}:${output_height}[tint];[base][tint]blend=all_mode=multiply[toned];[1:v]scale=${output_width}:${output_height}:force_original_aspect_ratio=increase:flags=lanczos,crop=${output_width}:${output_height},format=gray,split[fiber-source][blur-source];[blur-source]gblur=sigma=12[blurred];[fiber-source][blurred]blend=all_mode=grainextract,eq=contrast=${fiber_gain},format=gbrap[fiber];[toned][fiber]blend=all_mode=overlay:all_opacity=${fiber_opacity}[paper];[paper][alpha]alphamerge" \
  -frames:v 1 "$output_path"
