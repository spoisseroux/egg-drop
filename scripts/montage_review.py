"""Join the per-view tiles from render_wearable_review.py into one sheet: python scripts/montage_review.py <out.png>"""
import glob
import os
import sys

from PIL import Image

ORDER = ["front", "q", "side", "back", "bq", "face", "arm", "phone"]
for out in sys.argv[1:]:
    tiles = sorted(glob.glob(out[:-4] + "-*.png"), key=lambda p: ORDER.index(p[len(out) - 3:-4]) if p[len(out) - 3:-4] in ORDER else 99)
    tiles = [p for p in tiles if p[len(out) - 3:-4] in ORDER]
    if not tiles:
        continue
    ims = [Image.open(p).convert("RGB") for p in tiles]
    sheet = Image.new("RGB", (sum(i.width for i in ims), max(i.height for i in ims)), (40, 44, 52))
    x = 0
    for im in ims:
        sheet.paste(im, (x, 0))
        x += im.width
    sheet.save(out)
    for p in tiles:
        os.remove(p)
    print("sheet", out, sheet.size)
