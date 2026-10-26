#!/usr/bin/env python3
"""Gera o ícone do ExcaliburForms (1024px) e o conjunto de PNGs do .iconset.

Estilo Freeform/macOS 27: squircle claro de vidro na grade da Apple (824px
centrado), um cartão em degradê azul→turquesa levemente inclinado, uma faixa
de marca-texto amarela e um rabisco branco com laços por cima.

Uso:
  python3 scripts/make-icon.py [iconset_dir] [master_png]

Depois rode:
  iconutil -c icns <iconset_dir> -o Resources/AppIcon.icns
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


def squircle_mask(size, box, n=5.0):
    """Superelipse (|x|^n + |y|^n <= 1) no retângulo `box`, como os ícones do macOS."""
    x0, y0, x1, y1 = box
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
    v = np.abs((xx - cx) / rx) ** n + np.abs((yy - cy) / ry) ** n
    return Image.fromarray((np.clip((1.0 - v) * 40, 0, 1) * 255).astype(np.uint8), "L")


def linear_gradient(size, c1, c2, angle_deg):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / (size - 1)
    a = math.radians(angle_deg)
    t = np.clip((xx * math.cos(a) + yy * math.sin(a) - min(0, math.cos(a)) - min(0, math.sin(a)))
                / (abs(math.cos(a)) + abs(math.sin(a))), 0, 1)
    c1, c2 = np.array(c1, np.float32), np.array(c2, np.float32)
    rgb = c1 * (1 - t[..., None]) + c2 * t[..., None]
    return Image.fromarray(np.dstack([rgb, np.full((size, size), 255)]).astype(np.uint8), "RGBA")


canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))

# --- corpo: squircle claro (vidro) com sombra de chão ----------------------
body_box = (px(100), px(100), px(924), px(924))
body_mask = squircle_mask(W, body_box)

shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
shadow.putalpha(body_mask.point(lambda a: int(a * 0.32)))
shadow = shadow.transform(shadow.size, Image.AFFINE, (1, 0, 0, 0, 1, -px(14)))
shadow = shadow.filter(ImageFilter.GaussianBlur(px(22)))
canvas = Image.alpha_composite(canvas, shadow)

body = linear_gradient(W, (255, 255, 255), (226, 233, 242), 90)
glow = Image.new("L", (W, W), 0)
ImageDraw.Draw(glow).ellipse([px(80), px(20), px(760), px(560)], fill=110)
glow = glow.filter(ImageFilter.GaussianBlur(px(90)))
white = Image.new("RGBA", (W, W), (255, 255, 255, 255))
body = Image.composite(white, body, glow)
body.putalpha(body_mask)
canvas = Image.alpha_composite(canvas, body)

# --- cartão inclinado: degradê azul → turquesa -----------------------------
card_size = px(560)
card = linear_gradient(card_size, (44, 120, 255), (24, 214, 206), 45)
card_mask = Image.new("L", (card_size, card_size), 0)
ImageDraw.Draw(card_mask).rounded_rectangle(
    [0, 0, card_size - 1, card_size - 1], radius=px(118), fill=255
)
card.putalpha(card_mask)

# brilho de vidro no topo do cartão
sheen = Image.new("RGBA", (card_size, card_size), (255, 255, 255, 0))
sheen_mask = Image.new("L", (card_size, card_size), 0)
ImageDraw.Draw(sheen_mask).ellipse([-px(120), -px(360), px(680), px(240)], fill=70)
sheen_mask = ImageChops.multiply(sheen_mask.filter(ImageFilter.GaussianBlur(px(30))), card_mask)
sheen.putalpha(sheen_mask)
card = Image.alpha_composite(card, sheen)

# faixa de marca-texto amarela atravessando o cartão
hl = Image.new("RGBA", (card_size, card_size), (0, 0, 0, 0))
ImageDraw.Draw(hl).rounded_rectangle(
    [px(80), px(370), px(400), px(440)], radius=px(22), fill=(255, 226, 50, 235)
)
hl.putalpha(ImageChops.multiply(hl.getchannel("A"), card_mask))
card = Image.alpha_composite(card, hl)


def scribble_points(n=1400):
    """Cicloide alongada: um traço contínuo com laços, subindo de leve."""
    pts = []
    loops = 2.5
    k = 2.3
    for i in range(n + 1):
        t = i / n
        u = t * loops * 2 * math.pi
        x = (u - k * math.sin(u)) / (loops * 2 * math.pi)
        y = -k * math.cos(u) * 0.075 - t * 0.10
        pts.append((px(95) + x * px(370), px(250) + y * px(400)))
    return pts


stroke = Image.new("L", (card_size, card_size), 0)
sd = ImageDraw.Draw(stroke)
radius = px(17)
for x, y in scribble_points():
    sd.ellipse([x - radius, y - radius, x + radius, y + radius], fill=255)

stroke_shadow = Image.new("RGBA", (card_size, card_size), (8, 40, 120, 0))
stroke_shadow.putalpha(stroke.point(lambda a: int(a * 0.45)))
stroke_shadow = stroke_shadow.transform(
    stroke_shadow.size, Image.AFFINE, (1, 0, 0, 0, 1, -px(10))
).filter(ImageFilter.GaussianBlur(px(12)))
card = Image.alpha_composite(card, stroke_shadow)
stroke_layer = Image.new("RGBA", (card_size, card_size), (255, 255, 255, 0))
stroke_layer.putalpha(stroke)
card = Image.alpha_composite(card, stroke_layer)

card = card.rotate(-9, resample=Image.BICUBIC, expand=True)
cx = (W - card.width) // 2
cy = (W - card.height) // 2 + px(6)

# sombra num quadro do tamanho do ícone, para o desfoque não ser cortado
card_shadow = Image.new("RGBA", (W, W), (20, 60, 140, 0))
shadow_alpha = Image.new("L", (W, W), 0)
shadow_alpha.paste(card.getchannel("A").point(lambda a: int(a * 0.38)), (cx, cy + px(22)))
card_shadow.putalpha(shadow_alpha.filter(ImageFilter.GaussianBlur(px(26))))
canvas = Image.alpha_composite(canvas, card_shadow)
canvas.alpha_composite(card, (cx, cy))

# borda fina de vidro no corpo
rim = Image.new("RGBA", (W, W), (255, 255, 255, 0))
inner = squircle_mask(W, (body_box[0] + px(3), body_box[1] + px(3), body_box[2] - px(3), body_box[3] - px(3)))
rim.putalpha(ImageChops.subtract(body_mask, inner).point(lambda a: int(a * 0.7)))
canvas = Image.alpha_composite(canvas, rim)

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
