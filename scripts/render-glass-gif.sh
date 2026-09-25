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

ffmpeg -hide_banner -loglevel error -y \
  -loop 1 -i "$input_path" \
  -loop 1 -i "$texture_path" \
  -filter_complex "[0:v]scale=${output_width}:${output_height}:flags=lanczos,format=rgba,split[base][alpha-source];[alpha-source]alphaextract[alpha];[1:v]scale=${output_width}:${output_height}:force_original_aspect_ratio=increase:flags=lanczos,crop=${output_width}:${output_height},eq=contrast=1.35:brightness=-0.03:saturation=0.7,format=rgba[texture];[base][texture]blend=all_mode=softlight:all_opacity=0.45[paper];[paper][alpha]alphamerge,eq=brightness='0.012*sin(2*PI*t/4)':contrast='1+0.016*sin(2*PI*t/4)':saturation='1+0.022*sin(2*PI*t/4)':eval=frame,trim=duration=4,fps=8,split[a][b];[a]palettegen=stats_mode=full:max_colors=128:reserve_transparent=1:transparency_color=FFFFFF[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:alpha_threshold=128" \
  -loop 0 "$output_path"
