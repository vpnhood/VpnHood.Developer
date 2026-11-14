"""Export the approved forge master as responsive WebP hero images.

The original and its prompts are kept outside this repository.
Usage: python tools/export-forge-hero.py PATH_TO_MASTER.png
Requires Pillow. Only format conversion and resizing are applied.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageOps

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("master", type=Path)
args = parser.parse_args()
image = ImageOps.exif_transpose(Image.open(args.master)).convert("RGB")
output = Path(__file__).resolve().parents[1] / "images"
for name, width in (("hero-forge.webp", 2160), ("hero-forge-small.webp", 1440)):
    export = image.copy()
    export.thumbnail((width, width), Image.Resampling.LANCZOS)
    target = output / name
    export.save(target, "WEBP", quality=80, method=6)
    print(f"{target.name}: {export.width}x{export.height}, {target.stat().st_size:,} bytes")