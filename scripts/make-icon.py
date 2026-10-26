#!/usr/bin/env python3
"""Gera o ícone do ExcaliburForms (1024px) e o conjunto de PNGs do .iconset.

Uso:
  python3 scripts/make-icon.py [iconset_dir] [master_png]

Depois rode:
  iconutil -c icns <iconset_dir> -o Resources/AppIcon.icns
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 1024
ICONSET = sys.argv[1] if len(sys.argv) > 1 else "/tmp/AppIcon.iconset"
MASTER = sys.argv[2] if len(sys.argv) > 2 else "Resources/AppIcon.png"

# --- fundo: gradiente diagonal + brilho suave -------------------------------
c1 = np.array([109, 90, 230], dtype=np.float32)   # #6D5AE6
c2 = np.array([159, 84, 240], dtype=np.float32)   # #9F54F0
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
t = np.clip((xx + yy) / (2 * (S - 1)), 0, 1)
grad = c1[None, None, :] * (1 - t[..., None]) + c2[None, None, :] * t[..., None]
dist = np.sqrt((xx - S * 0.30) ** 2 + (yy - S * 0.25) ** 2)
highlight = (np.clip(1.0 - dist / (S * 0.85), 0, 1) ** 1.5) * 34.0
grad = np.clip(grad + highlight[..., None], 0, 255).astype(np.uint8)

img = Image.fromarray(np.dstack([grad, np.full((S, S), 255, np.uint8)]), "RGBA")

# --- "página" branca com sombra suave --------------------------------------
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle(
    [238, 246, 786, 794], radius=60, fill=(15, 23, 42, 96)
)
shadow = shadow.filter(ImageFilter.GaussianBlur(28))
img = Image.alpha_composite(img, shadow)

d = ImageDraw.Draw(img)
d.rounded_rectangle(
    [224, 224, 800, 800], radius=60, fill=(255, 255, 255, 255),
    outline=(226, 232, 240, 255), width=6,
)


def bar(cx, cy, w, h, color, radius):
    x0, y0 = cx - w // 2, cy - h // 2
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=radius, fill=color)


# linhas de "texto": uma destacada com marca-texto (recurso-símbolo do app)
bar(512, 372, 440, 26, (211, 219, 232, 255), 13)   # linha sem destaque
bar(512, 512, 424, 88, (255, 224, 102, 255), 20)   # faixa de marca-texto
bar(512, 512, 336, 26, (45, 42, 62, 255), 13)       # texto destacado
bar(512, 648, 356, 26, (211, 219, 232, 255), 13)   # linha sem destaque

# --- salva o master e o iconset --------------------------------------------
os.makedirs(ICONSET, exist_ok=True)
os.makedirs(os.path.dirname(MASTER) or ".", exist_ok=True)
img.save(MASTER)

sizes = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}
for name, size in sizes.items():
    img.resize((size, size), Image.LANCZOS).save(os.path.join(ICONSET, name))

print(f"master: {MASTER}")
print(f"iconset: {ICONSET}")
