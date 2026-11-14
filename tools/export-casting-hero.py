"""Export the casting master as responsive WebP images for Build your VPN app.

The original and its prompts are kept outside this repository.
Usage: python tools/export-casting-hero.py PATH_TO_MASTER.png
Requires Pillow. Only format conversion and resizing are applied; no crop is made.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageOps

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("master", type=Path)
args = parser.parse_args()
image = ImageOps.exif_transpose(Image.open(args.master)).convert("RGB")
output = Path(__file__).resolve().parents[1] / "images"
for name, width in (("hero-casting.webp", 2160), ("hero-casting-small.webp", 960)):
    export = image.copy()
    export.thumbnail((width, width), Image.Resampling.LANCZOS)
    target = output / name
    export.save(target, "WEBP", quality=80, method=6)
    print(f"{target.name}: {export.width}x{export.height}, {target.stat().st_size:,} bytes")
