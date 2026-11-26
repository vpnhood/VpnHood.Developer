"""Export the ads guide's gate scene as responsive WebP images for its banner.

The master is Leonardo's widest, 21:9, and the banner shows a 3:1 scene, so this crops it to 3:1 first, keeping the
lantern above the poster: --top is how much of the master's height goes above the crop. The original and its prompt are
kept outside this repository.
Usage: python tools/export-ads-hero.py PATH_TO_MASTER.jpg [--top 0.01]
Requires Pillow.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageOps

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("master", type=Path)
parser.add_argument("--top", type=float, default=0.01)
args = parser.parse_args()
image = ImageOps.exif_transpose(Image.open(args.master)).convert("RGB")
height = round(image.width / 3)
top = min(round(image.height * args.top), image.height - height)
image = image.crop((0, top, image.width, top + height))
output = Path(__file__).resolve().parents[1] / "images"
for name, width in (("hero-ads.webp", 2160), ("hero-ads-small.webp", 960)):
    export = image.copy()
    export.thumbnail((width, width), Image.Resampling.LANCZOS)
    target = output / name
    export.save(target, "WEBP", quality=80, method=6)
    print(f"{target.name}: {export.width}x{export.height}, {target.stat().st_size:,} bytes")
