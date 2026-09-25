#!/usr/bin/env bash

set -euo pipefail

input_path=$1
output_path=$2
target_width=${3:-}

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

shine_width=$((output_height / 2))

ffmpeg -hide_banner -loglevel error -y \
  -loop 1 -i "$input_path" \
  -f lavfi -i "color=c=white@0.0:s=${shine_width}x${output_height}:r=8:d=4,format=rgba,drawbox=x=0:y=0:w=${shine_width}:h=${output_height}:color=white@0.12:t=fill:replace=1" \
  -filter_complex "[0:v]scale=${output_width}:${output_height}:flags=lanczos[base];[1:v]rotate=0.14:c=none[shine];[base][shine]overlay=x='-w+(W+w)*t/4':y=0:shortest=1,trim=duration=4,fps=8,split[a][b];[a]palettegen=stats_mode=full:max_colors=64:reserve_transparent=1:transparency_color=FFFFFF[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:alpha_threshold=128" \
  -loop 0 "$output_path"
