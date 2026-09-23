"""Render a fresh geometric app icon from authored shapes (no external assets)."""
from pathlib import Path
import json
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parent.parent / 'app'
source = Image.new('RGB', (1024, 1024), '#C6F590')
draw = ImageDraw.Draw(source)
def star(x, y, r):
    points = [(x,y-r),(x+r*.29,y-r*.29),(x+r,y),(x+r*.29,y+r*.29),
              (x,y+r),(x-r*.29,y+r*.29),(x-r,y),(x-r*.29,y-r*.29)]
    draw.polygon(points, fill='#10171B')
star(455, 558, 218)
star(707, 317, 103)
star(731, 713, 72)
icons = root/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((icons/'Contents.json').read_text())['images']:
    if 'filename' not in item: continue
    n = round(float(item['size'].split('x')[0]) * float(item['scale'].rstrip('x')))
    source.resize((n,n), Image.Resampling.LANCZOS).save(icons/item['filename'])
for density,n in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    source.resize((n,n),Image.Resampling.LANCZOS).save(root/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
for filename in ('Icon-192.png','Icon-maskable-192.png'):
    source.resize((192,192),Image.Resampling.LANCZOS).save(root/'web/icons'/filename)
for filename in ('Icon-512.png','Icon-maskable-512.png'):
    source.resize((512,512),Image.Resampling.LANCZOS).save(root/'web/icons'/filename)
source.resize((32,32),Image.Resampling.LANCZOS).save(root/'web/favicon.png')
print('Authored Matsuri icon rendered for iOS, Android and web.')
