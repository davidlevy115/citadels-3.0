#!/usr/bin/env python3
"""Generate the card art locally with Stable Diffusion (sd-turbo) on Apple
Silicon — fully free and offline once the model is downloaded.

Usage: ~/.venvs/citadels-art/bin/python tools/generate_art_local.py [--only]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from generate_art import OUT, PROMPTS, STYLE, slug  # noqa: E402

import torch  # noqa: E402
from diffusers import AutoPipelineForText2Image  # noqa: E402


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    only_missing = "--only" in sys.argv

    device = "mps" if torch.backends.mps.is_available() else "cpu"
    print(f"loading sd-turbo on {device}…")
    pipe = AutoPipelineForText2Image.from_pretrained(
        "stabilityai/sd-turbo",
        torch_dtype=torch.float16 if device == "mps" else torch.float32,
        variant="fp16",
    )
    pipe = pipe.to(device)
    pipe.set_progress_bar_config(disable=True)

    todo = [n for n in PROMPTS
            if not (only_missing and os.path.exists(os.path.join(OUT, slug(n) + ".png")))]
    print(f"generating {len(todo)} images…")
    for i, name in enumerate(todo):
        path = os.path.join(OUT, slug(name) + ".png")
        prompt = f"{PROMPTS[name]}, {STYLE}"
        gen = torch.Generator(device).manual_seed(7 + i)
        img = pipe(
            prompt=prompt,
            num_inference_steps=4,
            guidance_scale=0.0,
            height=640,
            width=512,
            generator=gen,
        ).images[0]
        img.save(path)
        print(f"[{i + 1}/{len(todo)}] {name} → {path}")
    print("DONE")


if __name__ == "__main__":
    main()
