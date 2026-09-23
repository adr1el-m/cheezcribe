#!/usr/bin/env python3
"""Create a clearly labeled, repeatable OCR fixture. No historical data is used."""
from pathlib import Path
import json
import random

from PIL import Image, ImageDraw, ImageFont, ImageFilter

root = Path(__file__).resolve().parents[1]
out = root / "app" / "assets" / "demo"
out.mkdir(parents=True, exist_ok=True)
random.seed(8)

font_path = "/System/Library/Fonts/Supplemental/AmericanTypewriter.ttc"
font_bold = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
body = ImageFont.truetype(font_path, 28)
small = ImageFont.truetype(font_path, 20)
heading = ImageFont.truetype(font_bold, 38)

image = Image.new("RGB", (1500, 1900), (234, 228, 208))
pixels = image.load()
for y in range(image.height):
    for x in range(image.width):
        noise = random.randint(-13, 13)
        edge = int(10 * abs(x - image.width / 2) / (image.width / 2))
        pixels[x, y] = (max(0, min(255, 234 + noise - edge)),
                        max(0, min(255, 228 + noise - edge)),
                        max(0, min(255, 208 + noise - edge)))

draw = ImageDraw.Draw(image)
ink = (55, 51, 44)
draw.rectangle((80, 90, 1420, 1750), outline=(104, 99, 87), width=3)
draw.text((140, 145), "PERSONNEL DIRECTORY  •  1978", font=heading, fill=ink)
draw.text((140, 208), "Central Office / Archive Copy 04", font=small, fill=(90, 87, 78))
draw.line((140, 275, 1360, 275), fill=(110, 105, 91), width=2)
columns = [(140, "FILE NO."), (340, "FULL NAME"), (835, "LOCATION"), (1190, "YEAR")]
for x, label in columns:
    draw.text((x, 320), label, font=small, fill=ink)
draw.line((140, 365, 1360, 365), fill=(100, 96, 85), width=2)

records = [
    ("0217", "Ramon Dela Cruz", "Manila", "1978"),
    ("0231", "Elena Santos", "Quezon City", "1978"),
    ("0246", "Luis Mercado", "Pasig", "1978"),
    ("0288", "Maria Reyes", "Makati", "1978"),
]
for index, row in enumerate(records):
    y = 410 + index * 176
    for (x, _), value in zip(columns, row):
        draw.text((x, y), value, font=body, fill=(70 + index * 3, 65 + index * 3, 56 + index * 3))
    draw.line((140, y + 66, 1360, y + 66), fill=(171, 163, 144), width=1)

draw.text((140, 1250), "Filed: 17 October 1978", font=small, fill=(96, 91, 79))
draw.text((140, 1310), "Please check file numbers against original cards.", font=small,
          fill=(124, 118, 102))
draw.text((140, 1590), "SYNTHETIC TEST DOCUMENT — NOT A HISTORICAL RECORD",
          font=small, fill=(104, 80, 68))
image = image.filter(ImageFilter.GaussianBlur(radius=0.45))
image.save(out / "synthetic_directory_1978.jpg", quality=84)

truth = {
    "synthetic": True,
    "title": "PERSONNEL DIRECTORY 1978",
    "records": [
        {"file_no": number, "full_name": name, "location": location, "year": year}
        for number, name, location, year in records
    ],
}
(out / "synthetic_directory_1978.truth.json").write_text(
    json.dumps(truth, indent=2) + "\n", encoding="utf-8")
