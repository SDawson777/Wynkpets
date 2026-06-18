#!/usr/bin/env python3
"""One-off: regenerate frostbite_rainbow without using the pet name (which trips content policy)."""
import os, statistics, urllib.request
from pathlib import Path
from openai import OpenAI
from PIL import Image

try:
    from rembg import remove as rembg_remove
    HAS_REMBG = True
except ImportError:
    HAS_REMBG = False

API_KEY = os.environ.get("OPENAI_API_KEY")
if not API_KEY:
    env = Path(__file__).parent.parent / ".env.petgen"
    for line in env.read_text().splitlines():
        if line.startswith("OPENAI_API_KEY="):
            API_KEY = line.split("=", 1)[1].strip()
            break

client = OpenAI(api_key=API_KEY)
OUT = Path(__file__).parent.parent / "assets" / "pets" / "frostbite_rainbow.png"

prompt = (
    "SUBJECT: a cute small fantasy ANIMAL CREATURE — NOT a human, NOT a person. "
    "An adorable icy wolf cub or bear cub with holographic rainbow iridescent colour-shifting fur. "
    "Crystal ice spikes on its back, snowflake patterns on its fluffy body. "
    "Sparkling aurora wisps (pink, green, violet) flowing from its tail. "
    "Pokémon GO / Axie Infinity chibi collectible ANIMAL icon art style. "
    "Large jewel-like eyes with bright white sparkle highlight dot. Huge happy smile. "
    "Round chubby chibi body, four short stubby paws. Cel-shaded vivid magical colours. "
    "Pure flat white #FFFFFF background everywhere. No text. Family-friendly all-ages. Square 1:1. "
    "Displayed at 80x80px — irresistibly cute and collectable fantasy pet."
)

print("Generating frostbite_rainbow...")
resp = client.images.generate(model="dall-e-3", prompt=prompt, size="1024x1024", quality="hd", n=1)
url = resp.data[0].url
urllib.request.urlretrieve(url, str(OUT))
print(f"Downloaded: {OUT.name}")

# Post-process
img = Image.open(OUT).convert("RGBA")
fg = rembg_remove(img) if HAS_REMBG else img
bbox = fg.getbbox()
creature = fg.crop(bbox) if bbox else fg
PAD = 0.06
max_dim = int(1024 * (1.0 - 2 * PAD))
cw, ch = creature.size
scale = min(max_dim / cw, max_dim / ch, 1.0)
nw, nh = int(cw * scale), int(ch * scale)
creature = creature.resize((nw, nh), Image.LANCZOS)
canvas = Image.new("RGBA", (1024, 1024), (255, 255, 255, 255))
canvas.paste(creature, ((1024 - nw) // 2, (1024 - nh) // 2), mask=creature.split()[3])
canvas.convert("RGB").save(OUT, "PNG", optimize=True)

small = Image.open(OUT).convert("RGB").resize((32, 32))
pixels = list(small.getdata())
coloured = [(r, g, b) for r, g, b in pixels if not (r > 240 and g > 240 and b > 240)]
sat = statistics.mean(max(r, g, b) - min(r, g, b) for r, g, b in coloured) if coloured else 0
print(f"Post-processed. Saturation: {int(sat)} (target >15)")
print("Done." if sat > 15 else "WARNING: still low saturation!")
