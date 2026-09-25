"""SVG を土台と立体文字の層に分ける。

sips (CoreSVG) は文字へのグラデーションや光源フィルタを描けないため、
class="liquid" の要素だけを Chrome で描けるよう別の SVG に切り出す。

usage: split-liquid.py <src.svg> <base-out.svg> <layer-out.svg>
layer に liquid 要素が無ければ layer-out は作らない。
"""

import re
import sys

src_path, base_path, layer_path = sys.argv[1:4]
source = open(src_path, encoding="utf-8").read()

liquid = re.compile(r'\s*<(text|g)\b[^>]*class="liquid"[^>]*>.*?</\1>', re.S)
items = [m.group(0) for m in liquid.finditer(source)]

with open(base_path, "w", encoding="utf-8") as f:
    f.write(liquid.sub("", source))

if items:
    svg_open = source[: source.index(">", source.index("<svg")) + 1]
    defs = re.search(r"<defs>.*?</defs>", source, re.S)
    with open(layer_path, "w", encoding="utf-8") as f:
        f.write(svg_open + "\n" + (defs.group(0) if defs else "") + "".join(items) + "\n</svg>\n")
