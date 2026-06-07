#!/usr/bin/env python3
"""Generate a depth map for every painted card still with Depth-Anything-V2
(free, open source, Apache-2.0) running locally on Apple Silicon. The game
uses them for MTG-Arena-style 2.5D parallax: the painting gains real depth,
drifts on an orbital camera and tilts toward the mouse on hover.

Output: assets/depth/<slug>.png — 8-bit grayscale, white = near, black = far.

Usage:
  ~/.venvs/citadels-art/bin/python tools/generate_depth.py          # all stills
  ~/.venvs/citadels-art/bin/python tools/generate_depth.py --only   # missing only
  ~/.venvs/citadels-art/bin/python tools/generate_depth.py king docks
"""
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
ART = os.path.join(ROOT, "assets", "art")
OUT = os.path.join(ROOT, "assets", "depth")

MODEL = "depth-anything/Depth-Anything-V2-Small-hf"
# half the art resolution is plenty for UV-offset sampling and keeps files tiny
SCALE = 0.5


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    only_missing = "--only" in sys.argv
    wanted = [a.lower() for a in sys.argv[1:] if not a.startswith("-")]

    stills = sorted(glob.glob(os.path.join(ART, "*.png")))
    jobs = []
    for path in stills:
        slug = os.path.splitext(os.path.basename(path))[0]
        if wanted and slug not in wanted:
            continue
        dst = os.path.join(OUT, slug + ".png")
        if only_missing and os.path.exists(dst):
            continue
        jobs.append((slug, path, dst))
    if not jobs:
        print("nothing to do")
        return

    from transformers import pipeline  # late import: heavy

    print(f"loading {MODEL} …")
    pipe = pipeline("depth-estimation", model=MODEL, device="mps")

    for i, (slug, path, dst) in enumerate(jobs, 1):
        img = Image.open(path).convert("RGB")
        depth = pipe(img)["predicted_depth"]
        arr = depth.squeeze().float().cpu().numpy()
        # normalize to 0..255, white = near (Depth-Anything outputs higher = nearer)
        arr = (arr - arr.min()) / max(arr.max() - arr.min(), 1e-6)
        gray = Image.fromarray((arr * 255).astype(np.uint8), mode="L")
        gray = gray.resize(img.size, Image.BILINEAR)
        # soften edges a touch so parallax doesn't tear at silhouettes
        gray = gray.filter(ImageFilter.GaussianBlur(1.2))
        w, h = img.size
        gray = gray.resize((int(w * SCALE), int(h * SCALE)), Image.LANCZOS)
        gray.save(dst, optimize=True)
        print(f"[{i}/{len(jobs)}] {slug} -> {os.path.relpath(dst, ROOT)} ({os.path.getsize(dst)//1024}K)")

    print("done.")


if __name__ == "__main__":
    main()
