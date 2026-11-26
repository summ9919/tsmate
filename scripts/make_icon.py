import math, os, sys
from PIL import Image, ImageDraw

S = 1024
BLUE = (27, 110, 243, 255)
WHITE = (255, 255, 255, 255)
TEAL = (0, 194, 168, 255)

img = Image.new('RGBA', (S, S), BLUE)
d = ImageDraw.Draw(img)

pad = 96
d.rounded_rectangle([pad, pad, S - pad, S - pad], radius=180, fill=(21, 88, 196, 255))

cx, cy = S / 2.0, S / 2.0 - 20
R = 250
pts = []
for i in range(3):
    a = math.radians(-90 + i * 120)
    pts.append((cx + R * math.cos(a), cy + R * math.sin(a)))

for i in range(3):
    d.line([pts[i], pts[(i + 1) % 3]], fill=WHITE, width=34, joint='curve')

for i, p in enumerate(pts):
    r = 92
    if i == 0:
        d.rounded_rectangle([p[0] - r, p[1] - r, p[0] + r, p[1] + r], radius=44, fill=TEAL)
    else:
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=WHITE)

d.ellipse([cx - 46, cy - 46, cx + 46, cy + 46], fill=WHITE)

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out_dir = os.path.join(root, 'TSMate', 'Assets.xcassets', 'AppIcon.appiconset')
os.makedirs(out_dir, exist_ok=True)
out = os.path.join(out_dir, 'AppIcon.png')
img.save(out)
print('icon saved:', out, img.size)