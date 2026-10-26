#!/usr/bin/env python3
"""Gera o ícone do ExcaliburForms (1024px) e o conjunto de PNGs do .iconset.

Estilo macOS 27 (inspirado em quadros brancos como o Freeform, com elementos
próprios): squircle claro na grade da Apple (824px centrado), um círculo
amarelo→laranja (o marca-texto), um cartão de vidro azul translúcido por cima
e um rabisco cursivo de tinta escura, com volume, atravessando os dois.

Uso:
  python3 scripts/make-icon.py [iconset_dir] [master_png]

Depois rode:
  iconutil -c icns <iconset_dir> -o Resources/AppIcon.icns

Precisa de numpy e Pillow (num venv: python3 -m venv v && v/bin/pip install numpy pillow).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 1024
SS = 3                      # supersampling para bordas suaves
W = S * SS
ICONSET = sys.argv[1] if len(sys.argv) > 1 else "/tmp/AppIcon.iconset"
MASTER = sys.argv[2] if len(sys.argv) > 2 else "Resources/AppIcon.png"


def px(v):
    return int(round(v * SS))


def squircle_mask(box, n=5.0):
    """Superelipse (|x|^n + |y|^n <= 1) no retângulo `box`, como os ícones do macOS."""
    x0, y0, x1, y1 = box
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
    v = np.abs((xx - cx) / rx) ** n + np.abs((yy - cy) / ry) ** n
    return Image.fromarray((np.clip((1.0 - v) * 40, 0, 1) * 255).astype(np.uint8), "L")


def gradient(c1, c2, p1, p2):
    """Degradê linear de c1 (em p1) a c2 (em p2), coordenadas em px de 1024."""
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
    x1, y1, x2, y2 = px(p1[0]), px(p1[1]), px(p2[0]), px(p2[1])
    dx, dy = x2 - x1, y2 - y1
    t = np.clip(((xx - x1) * dx + (yy - y1) * dy) / (dx * dx + dy * dy), 0, 1)
    c1, c2 = np.array(c1, np.float32), np.array(c2, np.float32)
    rgb = c1 * (1 - t[..., None]) + c2 * t[..., None]
    return Image.fromarray(np.dstack([rgb, np.full((W, W), 255)]).astype(np.uint8), "RGBA")


def layer(color_img, mask, alpha=1.0):
    out = color_img.copy()
    out.putalpha(mask.point(lambda a: int(a * alpha)))
    return out


def soft_shadow(mask, offset_y, blur, opacity, color=(0, 0, 0)):
    shadow = Image.new("RGBA", (W, W), color + (0,))
    shifted = Image.new("L", (W, W), 0)
    shifted.paste(mask, (0, px(offset_y)))
    shadow.putalpha(shifted.filter(ImageFilter.GaussianBlur(px(blur))).point(lambda a: int(a * opacity)))
    return shadow


canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))

# --- corpo claro ------------------------------------------------------------
body_box = (px(100), px(100), px(924), px(924))
body_mask = squircle_mask(body_box)
canvas = Image.alpha_composite(canvas, soft_shadow(body_mask, 12, 20, 0.30))
body = gradient((255, 255, 255), (228, 231, 236), (512, 100), (512, 924))
canvas = Image.alpha_composite(canvas, layer(body, body_mask))

# --- círculo quente (marca-texto): amarelo → laranja -------------------------
circle_mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(circle_mask).ellipse([px(212), px(408), px(612), px(808)], fill=255)
canvas = Image.alpha_composite(canvas, soft_shadow(circle_mask, 14, 22, 0.22, (120, 60, 0)))
circle = gradient((255, 214, 64), (255, 112, 67), (412, 410), (412, 806))
canvas = Image.alpha_composite(canvas, layer(circle, circle_mask))
# brilho suave no alto do círculo
gloss = Image.new("L", (W, W), 0)
ImageDraw.Draw(gloss).ellipse([px(262), px(430), px(520), px(600)], fill=120)
gloss = ImageChops.multiply(gloss.filter(ImageFilter.GaussianBlur(px(40))), circle_mask)
canvas = Image.alpha_composite(canvas, layer(Image.new("RGBA", (W, W), (255, 255, 255, 255)), gloss))

# --- cartão de vidro azul, translúcido, por cima do círculo ------------------
card_box = [px(420), px(222), px(812), px(614)]
card_mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(card_mask).rounded_rectangle(card_box, radius=px(92), fill=255)
canvas = Image.alpha_composite(canvas, soft_shadow(card_mask, 16, 26, 0.20, (0, 60, 140)))
# o que fica atrás do cartão aparece desfocado (vidro)
behind = canvas.filter(ImageFilter.GaussianBlur(px(6)))
canvas = Image.composite(behind, canvas, card_mask)
card = gradient((92, 220, 255), (36, 140, 255), (440, 230), (800, 610))
canvas = Image.alpha_composite(canvas, layer(card, card_mask, 0.66))
# reflexo no topo e aro claro
sheen = Image.new("L", (W, W), 0)
ImageDraw.Draw(sheen).ellipse([px(380), px(120), px(880), px(420)], fill=90)
sheen = ImageChops.multiply(sheen.filter(ImageFilter.GaussianBlur(px(36))), card_mask)
canvas = Image.alpha_composite(canvas, layer(Image.new("RGBA", (W, W), (255, 255, 255, 255)), sheen))
inner = Image.new("L", (W, W), 0)
ImageDraw.Draw(inner).rounded_rectangle(
    [card_box[0] + px(4), card_box[1] + px(4), card_box[2] - px(4), card_box[3] - px(4)],
    radius=px(88), fill=255,
)
rim = ImageChops.subtract(card_mask, inner)
canvas = Image.alpha_composite(canvas, layer(Image.new("RGBA", (W, W), (255, 255, 255, 255)), rim, 0.55))


# --- rabisco de tinta com volume ----------------------------------------------
def scribble():
    """Traço cursivo com laços (cicloide alongada), pontas afinando."""
    pts = []
    n, loops, k = 1600, 2.3, 2.1
    for i in range(n + 1):
        t = i / n
        u = t * loops * 2 * math.pi
        x = (u - k * math.sin(u)) / (loops * 2 * math.pi)
        y = -k * math.cos(u) * 0.085 - t * 0.12
        # grossura: fina nas pontas, cheia no meio
        width = 0.35 + 0.65 * math.sin(math.pi * min(1, t * 1.15)) ** 0.6
        pts.append((px(232) + x * px(560), px(560) + y * px(520), width))
    return pts


def stroke_mask(points, radius, dx=0, dy=0):
    mask = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(mask)
    for x, y, w in points:
        r = radius * w
        d.ellipse([x - r + px(dx), y - r + px(dy), x + r + px(dx), y + r + px(dy)], fill=255)
    return mask


pts = scribble()
ink = stroke_mask(pts, px(30))
canvas = Image.alpha_composite(canvas, soft_shadow(ink, 14, 14, 0.35))
canvas = Image.alpha_composite(canvas, layer(Image.new("RGBA", (W, W), (28, 28, 36, 255)), ink))
# luz: um traço mais fino e claro deslocado para cima, recortado pela tinta
highlight = ImageChops.multiply(stroke_mask(pts, px(12), dx=-5, dy=-9), ink)
highlight = highlight.filter(ImageFilter.GaussianBlur(px(5)))
canvas = Image.alpha_composite(canvas, layer(Image.new("RGBA", (W, W), (150, 150, 170, 255)), highlight, 0.75))

# borda fina de vidro no corpo
inner_body = squircle_mask((body_box[0] + px(3), body_box[1] + px(3), body_box[2] - px(3), body_box[3] - px(3)))
canvas = Image.alpha_composite(
    canvas,
    layer(Image.new("RGBA", (W, W), (255, 255, 255, 255)), ImageChops.subtract(body_mask, inner_body), 0.8),
)

img = canvas.resize((S, S), Image.LANCZOS)

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
