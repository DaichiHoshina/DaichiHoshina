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

ffmpeg -hide_banner -loglevel error -y \
  -loop 1 -i "$input_path" \
  -filter_complex "[0:v]scale=${output_width}:${output_height}:flags=lanczos,eq=brightness='0.012*sin(2*PI*t/4)':contrast='1+0.016*sin(2*PI*t/4)':saturation='1+0.022*sin(2*PI*t/4)':eval=frame,trim=duration=4,fps=8,split[a][b];[a]palettegen=stats_mode=full:max_colors=96:reserve_transparent=1:transparency_color=FFFFFF[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:alpha_threshold=128" \
  -loop 0 "$output_path"
