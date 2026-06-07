#!/usr/bin/env python3
"""Generate true motion clips for every card with AnimateDiff-Lightning
(free, open source) running locally on Apple Silicon. Each clip is 16 frames,
exported as a 4x4 sprite sheet webp into assets/motion/<slug>.webp, which the
game plays back as a looping video on the card.

Usage:
  ~/.venvs/citadels-art/bin/python tools/generate_motion.py            # all
  ~/.venvs/citadels-art/bin/python tools/generate_motion.py --only     # missing
  ~/.venvs/citadels-art/bin/python tools/generate_motion.py Docks King # subset
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from generate_art import slug  # noqa: E402

import torch  # noqa: E402
from diffusers import AnimateDiffPipeline, EulerDiscreteScheduler, MotionAdapter  # noqa: E402
from huggingface_hub import hf_hub_download  # noqa: E402
from safetensors.torch import load_file  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "motion")

# 256x320 keeps AnimateDiff inside 16GB unified memory; cards display art at
# ~180-300px wide, so this is plenty. fp32 throughout — fp16 VAE decode
# produces black frames (NaNs) on the MPS backend.
W, H = 256, 320
FRAMES = 16
COLS = 4

STYLE = ("epic fantasy film still, medieval, cinematic lighting, rich detail, "
         "steady camera, high quality")

# Literal on-screen motion per subject.
MOTION = {
    # Characters
    "Assassin": "a hooded assassin slowly raises a curved dagger, cloak swaying, smoke drifting around him",
    "Thief": "a hooded thief lifts and tilts a sack, gold coins spilling and falling through his fingers",
    "Magician": "a robed magician casts a spell, glowing magic rays bursting from his outstretched hands",
    "King": "a king raises a golden crown with both hands and places it onto his own head, royal throne room",
    "Bishop": "a bishop raises his crozier in blessing, holy light rays growing brighter from above",
    "Merchant": "a merchant counts gold coins dropping from his hand onto a table, coins glinting",
    "Architect": "an architect unrolls a large blueprint scroll across a table and studies it",
    "Warlord": "an armored warlord draws his greatsword and raises it, war banners flapping in the wind",

    # Districts
    "Manor": "a stately manor garden, trees and hedges swaying in a gentle breeze, drifting clouds",
    "Castle": "a medieval castle, banners flapping in the wind, clouds drifting past the towers",
    "Palace": "a royal palace, fountains spraying water, flags waving, sunlight shimmering on golden domes",
    "Temple": "an ancient temple, sacred flame flickering on the altar, incense smoke rising",
    "Church": "a stone church, candle light flickering through windows, birds flying past the steeple",
    "Monastery": "a monastery courtyard, a bell swinging in the tower, leaves drifting in the breeze",
    "Cathedral": "a gothic cathedral, light shifting through the rose window, birds circling the spires",
    "Tavern": "a cozy tavern at night, fire light flickering in the windows, the hanging sign swinging",
    "Market": "a busy medieval market, canopies rippling in the wind, people moving between stalls",
    "Trading Post": "a forest trading post, smoke rising from a chimney, trees swaying",
    "Docks": "wooden docks on water, gentle waves rolling, moored rowboats bobbing up and down",
    "Harbor": "a harbor at sunset, waves moving, tall sailing ships rocking gently, sails rippling",
    "Town Hall": "a town square, the clock tower hands moving, pigeons taking flight, flags waving",
    "Watchtower": "a stone watchtower at dusk, signal fire blazing and flickering, sparks rising",
    "Prison": "a grim prison, torch flames flickering, chains swinging slightly, mist creeping",
    "Battlefield": "a battlefield at dawn, smoke drifting low, torn banners flapping in the wind",
    "Fortress": "a massive fortress, war banners waving on the towers, storm clouds moving overhead",
    "Haunted City": "a ruined ghostly city, green spirits floating upward, fog rolling between towers",
    "Keep": "a stone keep under a stormy sky, clouds churning, a banner whipping in strong wind",
    "Laboratory": "an alchemist laboratory, green potions bubbling in flasks, vapor rising",
    "Smithy": "a blacksmith forge, hammer striking glowing metal on an anvil, sparks flying",
    "Graveyard": "a misty graveyard at night, fog drifting between tombstones, a lantern flickering",
    "Observatory": "an observatory at night, the dome slit rotating, stars twinkling, a shooting star",
    "Library": "a candlelit library, candle flames flickering, dust motes drifting in light beams",
    "School of Magic": "a wizard academy tower, glowing runes pulsing, magical lights orbiting the spire",
    "Dragon Gate": "a monumental dragon gate, the portal between pillars swirling with fire energy",
    "University": "a university square, scholars in robes walking, flags waving, birds flying",
    "Great Wall": "a long stone wall at dusk, watch fires flickering along the towers, clouds moving",
}


def build_pipe():
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    dtype = torch.float32
    print(f"loading AnimateDiff-Lightning on {device}…")
    adapter = MotionAdapter()
    adapter.load_state_dict(load_file(hf_hub_download(
        "ByteDance/AnimateDiff-Lightning",
        "animatediff_lightning_4step_diffusers.safetensors"), device="cpu"))
    adapter = adapter.to(device, dtype)
    pipe = AnimateDiffPipeline.from_pretrained(
        "emilianJR/epiCRealism", motion_adapter=adapter, torch_dtype=dtype)
    pipe.scheduler = EulerDiscreteScheduler.from_config(
        pipe.scheduler.config, timestep_spacing="trailing", beta_schedule="linear")
    pipe = pipe.to(device)
    pipe.enable_vae_slicing()
    pipe.enable_attention_slicing()
    pipe.set_progress_bar_config(disable=True)
    return pipe, device


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only_missing = "--only" in sys.argv

    names = args if args else list(MOTION.keys())
    todo = []
    for n in names:
        path = os.path.join(OUT, slug(n) + ".webp")
        if only_missing and os.path.exists(path):
            continue
        todo.append(n)
    if not todo:
        print("nothing to do")
        return

    pipe, device = build_pipe()
    print(f"generating {len(todo)} clips ({FRAMES} frames each)…")
    for i, name in enumerate(todo):
        prompt = f"{MOTION[name]}, {STYLE}"
        gen = torch.Generator(device).manual_seed(11 + i)
        out = pipe(
            prompt=prompt,
            negative_prompt="text, watermark, low quality, deformed",
            guidance_scale=1.0,
            num_inference_steps=4,
            num_frames=FRAMES,
            width=W,
            height=H,
            generator=gen,
        )
        frames = out.frames[0]
        sheet = Image.new("RGB", (W * COLS, H * COLS))
        for j, fr in enumerate(frames[:FRAMES]):
            sheet.paste(fr.convert("RGB"), ((j % COLS) * W, (j // COLS) * H))
        path = os.path.join(OUT, slug(name) + ".webp")
        sheet.save(path, "WEBP", quality=80, method=4)
        print(f"[{i + 1}/{len(todo)}] {name} → {path} ({os.path.getsize(path) // 1024} KB)", flush=True)
        del out, frames, sheet
        if device == "mps":
            torch.mps.empty_cache()
    print("DONE")


if __name__ == "__main__":
    main()
