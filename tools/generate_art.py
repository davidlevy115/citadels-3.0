#!/usr/bin/env python3
"""Generate painted card art for every character and district via the free
Pollinations.ai image API (no key needed). Images land in assets/art/.

Usage: python3 tools/generate_art.py [--only missing]
"""
import os
import sys
import time
import urllib.parse
import urllib.request

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art")

STYLE = ("medieval fantasy oil painting, highly detailed, dramatic cinematic "
         "lighting, rich colors, masterpiece, trending on artstation")

# characters share composition guidance keeping heads well inside the frame
CHAR_FRAME = ("medium shot, head and upper body fully visible and centered, "
              "generous space above the head, nothing cropped by the frame")

PROMPTS = {
    # ── Characters: human portraits ─────────────────────────────
    "Assassin": f"a hooded human assassin in dark purple cloak gripping a curved dagger, face half hidden in shadow, piercing eyes, {CHAR_FRAME}",
    "Thief": f"a cunning human thief in a teal hood, smirking, clutching a bulging sack of gold coins, narrow medieval alley behind, {CHAR_FRAME}",
    "Magician": f"a human court magician in violet robes conjuring swirling arcane light between his hands, sparks of magic, {CHAR_FRAME}",
    "King": f"a regal human king with a golden crown and red ermine-trimmed robe holding a scepter, throne room behind, {CHAR_FRAME}",
    "Bishop": f"a solemn human bishop in blue and gold vestments with a tall mitre and ornate crozier, stained glass window behind, {CHAR_FRAME}",
    "Merchant": f"a wealthy smiling human merchant in fine green robes weighing gold coins on brass scales, market stalls behind, {CHAR_FRAME}",
    "Architect": f"a human master architect holding rolled blueprints and a brass compass, half-built cathedral with scaffolding behind, {CHAR_FRAME}",
    "Warlord": f"a battle-scarred human warlord in crimson and steel armor resting hands on a greatsword, war banners behind, {CHAR_FRAME}",

    # ── Districts: real-looking places ──────────────────────────
    "Manor": "stately medieval manor house with ivy walls and gardens at golden hour",
    "Castle": "imposing medieval castle with towers and banners on a hill, dramatic sky",
    "Palace": "opulent royal palace with golden domes and marble columns, sunset light",
    "Temple": "ancient stone temple with columns and a sacred flame altar, morning mist",
    "Church": "medieval stone church with steeple and rose window, warm candlelight in windows",
    "Monastery": "quiet cloistered monastery with bell tower and courtyard garden, monks at dusk",
    "Cathedral": "towering gothic cathedral with twin spires and a glowing rose window, dusk",
    "Tavern": "cozy medieval tavern at night, warm glowing windows, wooden sign and barrels",
    "Market": "bustling medieval market square with colorful canopied stalls and produce",
    "Trading Post": "wooden medieval trading post with crates, sacks and a signpost on a forest road",
    "Docks": "wooden medieval docks with rowboats and crates on a calm river, dawn",
    "Harbor": "medieval harbor with a stone lighthouse and tall sailing ships, golden sunset",
    "Town Hall": "grand medieval town hall with a clock tower over a cobbled square",
    "Watchtower": "lone stone watchtower with a signal fire on a rocky outcrop at dusk",
    "Prison": "grim medieval stone prison with barred windows, heavy iron door and chains",
    "Battlefield": "medieval battlefield at dawn, planted swords, torn banners, smoke",
    "Fortress": "massive medieval fortress with thick curtain walls and corner towers",
    "Haunted City": "ruined ghostly medieval city with crooked towers and glowing green spirits, fog",
    "Keep": "massive round stone keep with crenellations and a heavy gate, stormy sky",
    "Laboratory": "alchemist laboratory with glowing green potions, bubbling flasks and old books",
    "Smithy": "medieval blacksmith forge with glowing embers, anvil and hammer, sparks flying",
    "Graveyard": "misty medieval graveyard with leaning tombstones, dead tree and eerie lantern",
    "Observatory": "medieval stone observatory with a domed roof and brass telescope under starry sky",
    "Library": "grand medieval library with towering candlelit bookshelves and reading desks",
    "School of Magic": "arcane wizard academy tower with floating lights and glowing runes, twilight",
    "Dragon Gate": "monumental red and gold dragon gate with glowing portal, guardian statues",
    "University": "grand medieval university with dome, spires and scholars in robes",
    "Great Wall": "long medieval stone wall with towers winding over green hills at dusk",
}


def slug(name: str) -> str:
    return name.lower().replace(" ", "_")


def fetch(name: str, prompt: str, seed: int = 7) -> bool:
    path = os.path.join(OUT, slug(name) + ".png")
    full = f"{prompt}, {STYLE}"
    url = ("https://image.pollinations.ai/prompt/" + urllib.parse.quote(full)
           + f"?width=512&height=640&nologo=true&seed={seed}&model=flux")
    req = urllib.request.Request(url, headers={"User-Agent": "citadels-3.0-art/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            data = r.read()
        if len(data) < 20000:
            print(f"  !! {name}: suspiciously small ({len(data)}b), skipping")
            return False
        with open(path, "wb") as f:
            f.write(data)
        print(f"  ok {name} ({len(data) // 1024} KB)")
        return True
    except Exception as e:  # noqa: BLE001
        print(f"  !! {name}: {e}")
        return False


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    only_missing = "--only" in sys.argv
    todo = []
    for name in PROMPTS:
        path = os.path.join(OUT, slug(name) + ".png")
        if only_missing and os.path.exists(path):
            continue
        todo.append(name)
    print(f"generating {len(todo)} images…")
    failed = []
    for i, name in enumerate(todo):
        print(f"[{i + 1}/{len(todo)}] {name}")
        if not fetch(name, PROMPTS[name]):
            failed.append(name)
        time.sleep(1.0)
    # one retry round for failures
    for name in list(failed):
        print(f"[retry] {name}")
        if fetch(name, PROMPTS[name], seed=13):
            failed.remove(name)
        time.sleep(2.0)
    print("DONE — failed: %s" % (", ".join(failed) if failed else "none"))


if __name__ == "__main__":
    main()
