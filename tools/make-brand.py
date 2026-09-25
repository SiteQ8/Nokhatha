#!/usr/bin/env python3
"""Draws the Nokhatha identity from one geometry and writes every SVG.

The mark reads three ways at once: the letter noon that opens نُوخذة,
the hull of a boom, and the Gulf crescent that lies on its back like a boat.
Its dot is the pearl, or Suhail, the star the nokhatha steered by.
Lettering is shaped with HarfBuzz and drawn as outlines, so no file needs a font.

Usage: pip install uharfbuzz fonttools brotli && python3 tools/make-brand.py
"""
import io
import math
import os

import uharfbuzz as hb
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
FONTS = os.path.join(ROOT, 'docs', 'assets', 'fonts')
OUT = os.path.join(ROOT, 'docs', 'assets', 'brand')

NIGHT, SADU, GOLD, PEARL = '#161C35', '#A4262C', '#C98A1B', '#EEF1F4'
NIGHT_SAIL, NIGHT_GOLD = '#D8474D', '#E7AF4B'
LIGHT = {'hull': NIGHT, 'sail': SADU, 'pearl': GOLD, 'text': NIGHT, 'sub': '#3A4263'}
DARK = {'hull': PEARL, 'sail': NIGHT_SAIL, 'pearl': NIGHT_GOLD, 'text': PEARL, 'sub': '#BAC1D5'}
MONO = {'hull': NIGHT, 'sail': NIGHT, 'pearl': NIGHT, 'text': NIGHT, 'sub': NIGHT}

# ------------------------------------------------------------------ mark

def circle_through(half, tip_y, bottom):
    """Center height and radius of a circle through (128 +- half, tip_y) whose lowest point is bottom."""
    c = (half ** 2 + tip_y ** 2 - bottom ** 2) / (2 * (tip_y - bottom))
    return c, bottom - c


def crescent(half=110, tip=132, outer=214, inner=168):
    _, r1 = circle_through(half, tip, outer)
    _, r2 = circle_through(half, tip, inner)
    return (f'M{128 - half} {tip}A{r1:.2f} {r1:.2f} 0 0 0 {128 + half} {tip}'
            f'A{r2:.2f} {r2:.2f} 0 0 1 {128 - half} {tip}Z')


HULL = crescent()
SAIL = 'M76 18 214 120Q160 146 96 138Q82 80 76 18Z'
PEARL_C = (206, 46, 21)
TILT = -7  # the whole mark leans into the wind


def mark_group(c, tx=0.0, ty=0.0, scale=1.0, pearl_fill=None):
    x, y, r = PEARL_C
    return (f'<g transform="translate({tx:.2f} {ty:.2f}) scale({scale:.5f}) rotate({TILT} 128 128)">'
            f'<path fill="{c["sail"]}" d="{SAIL}"/>'
            f'<path fill="{c["hull"]}" d="{HULL}"/>'
            f'<circle fill="{pearl_fill or c["pearl"]}" cx="{x}" cy="{y}" r="{r}"/></g>')


def rotated_bounds():
    """Bounding box of the tilted mark, sampled densely enough for layout."""
    pts = []
    # hull outline by sampling both arcs
    for half, tip, bottom in ((110, 132, 214), (110, 132, 168)):
        c, r = circle_through(half, tip, bottom)
        a0 = math.atan2(tip - c, -half)
        a1 = math.atan2(tip - c, half)
        for i in range(201):
            a = a0 + (a1 - a0) * i / 200
            pts.append((128 + r * math.cos(a), c + r * math.sin(a)))
    pts += [(76, 18), (214, 120), (96, 138), (160, 146), (82, 80)]
    x, y, r = PEARL_C
    pts += [(x + r * math.cos(t / 20 * math.pi), y + r * math.sin(t / 20 * math.pi)) for t in range(40)]
    rad = math.radians(TILT)
    rot = [(128 + (px - 128) * math.cos(rad) - (py - 128) * math.sin(rad),
            128 + (px - 128) * math.sin(rad) + (py - 128) * math.cos(rad)) for px, py in pts]
    xs, ys = [p[0] for p in rot], [p[1] for p in rot]
    return min(xs), min(ys), max(xs), max(ys)


BX0, BY0, BX1, BY1 = rotated_bounds()
BW, BH = BX1 - BX0, BY1 - BY0


def mark_fit(c, box_x, box_y, box_w, box_h, **kw):
    """The mark scaled to fit a box, centred on its visual bounds."""
    s = min(box_w / BW, box_h / BH)
    tx = box_x + (box_w - BW * s) / 2 - BX0 * s
    ty = box_y + (box_h - BH * s) / 2 - BY0 * s
    return mark_group(c, tx, ty, s, **kw)

# --------------------------------------------------------------- lettering

def instance(path, wght):
    font = TTFont(path)
    if 'fvar' in font:
        font = instancer.instantiateVariableFont(font, {'wght': wght})
    buf = io.BytesIO()
    font.flavor = None
    font.save(buf)
    data = buf.getvalue()
    return TTFont(io.BytesIO(data)), data


def shape(text, path, wght, size, tracking=0.0, rtl=False):
    """Returns an SVG path for the text with its baseline at y=0, and its advance width."""
    tt, data = instance(path, wght)
    face = hb.Face(data)
    font = hb.Font(face)
    upem = face.upem
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font, buf, {'kern': True, 'liga': True})
    gs = tt.getGlyphSet()
    order = tt.getGlyphOrder()
    k = size / upem
    pen = SVGPathPen(gs)
    x = 0.0
    n = len(buf.glyph_infos)
    for idx, (info, pos) in enumerate(zip(buf.glyph_infos, buf.glyph_positions)):
        name = order[info.codepoint]
        tpen = TransformPen(pen, (k, 0, 0, -k, (x + pos.x_offset) * k, -pos.y_offset * k))
        gs[name].draw(tpen)
        x += pos.x_advance
        if tracking and idx < n - 1 and pos.x_advance:
            x += tracking * upem
    return pen.getCommands(), x * k


AR_FONT = os.path.join(FONTS, 'reem-kufi-400-700-arabic.woff2')
LA_FONT = os.path.join(FONTS, 'reem-kufi-400-700-latin.woff2')

# ----------------------------------------------------------------- lockups

def svg(w, h, body, label='Nokhatha', bg=None, rx=0):
    b = f'<rect width="{w}" height="{h}" rx="{rx}" fill="{bg}"/>' if bg else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.0f} {h:.0f}" width="{w:.0f}" height="{h:.0f}" '
            f'role="img" aria-label="{label}">{b}{body}</svg>\n')


def lockup_ar(c):
    d, w = shape('نُوخذة', AR_FONT, 700, 150)
    mark_h = 168
    pad = 12
    gap = 30
    mw = BW * mark_h / BH
    W = pad + w + gap + mw + pad
    H = 200
    base = 150
    # Arabic reads right to left: the mark comes first, on the right
    body = mark_fit(c, W - pad - mw, (H - mark_h) / 2 - 4, mw, mark_h)
    body += f'<path fill="{c["text"]}" transform="translate({pad} {base})" d="{d}"/>'
    return svg(W, H, body, 'نُوخذة')


def lockup_en(c):
    d, w = shape('Nokhatha', LA_FONT, 700, 128, tracking=0.01)
    mark_h = 150
    pad, gap = 12, 28
    mw = BW * mark_h / BH
    W = pad + mw + gap + w + pad
    H = 180
    body = mark_fit(c, pad, (H - mark_h) / 2 - 2, mw, mark_h)
    body += f'<path fill="{c["text"]}" transform="translate({pad + mw + gap:.2f} 128)" d="{d}"/>'
    return svg(W, H, body)


def lockup_stacked(c):
    ar, aw = shape('نُوخذة', AR_FONT, 700, 170)
    en, ew = shape('NOKHATHA', LA_FONT, 600, 52, tracking=0.28)
    W = max(aw, ew, 360) + 80
    mark_h = 250
    mw = BW * mark_h / BH
    H = 40 + mark_h + 30 + 180 + 40 + 60
    body = mark_fit(c, (W - mw) / 2, 40, mw, mark_h)
    body += f'<path fill="{c["text"]}" transform="translate({(W - aw) / 2:.2f} {40 + mark_h + 30 + 150})" d="{ar}"/>'
    body += f'<path fill="{c["sub"]}" transform="translate({(W - ew) / 2:.2f} {H - 44})" d="{en}"/>'
    return svg(W, H, body, 'نُوخذة Nokhatha')


def app_icon(size=1024, inset=0.155, maskable=False):
    """Night sea, a soft glow where the moon rises, the mark in pearl, sail and gold."""
    m = size * (0.22 if maskable else inset)
    drop = size * 0.018  # optical centre sits a little below the geometric one
    defs = ('<defs><radialGradient id="sea" cx="50%" cy="30%" r="80%">'
            '<stop offset="0" stop-color="#28325E"/><stop offset=".55" stop-color="#1A2140"/><stop offset="1" stop-color="#11162C"/></radialGradient>'
            '<radialGradient id="pearl" cx="36%" cy="30%" r="80%"><stop offset="0" stop-color="#FFF6DE"/>'
            '<stop offset=".45" stop-color="#E7AF4B"/><stop offset="1" stop-color="#A86F12"/></radialGradient></defs>')
    body = defs + f'<rect width="{size}" height="{size}" fill="url(#sea)"/>'
    body += mark_fit(DARK, m, m + drop, size - 2 * m, size - 2 * m, pearl_fill='url(#pearl)')
    return svg(size, size, body)


def mark_file(c, label='Nokhatha'):
    return svg(256, 256, mark_fit(c, 8, 8, 240, 240), label)


def mark_auto():
    """One file that follows the light or dark setting of whatever shows it."""
    body = mark_fit({'hull': 'var(--h)', 'sail': 'var(--s)', 'pearl': 'var(--p)'}, 8, 8, 240, 240)
    body = (body.replace('fill="var(--h)"', 'class="h"').replace('fill="var(--s)"', 'class="s"').replace('fill="var(--p)"', 'class="p"'))
    style = ('<style>.h{fill:#161C35}.s{fill:#A4262C}.p{fill:#C98A1B}'
             '@media (prefers-color-scheme:dark){.h{fill:#EEF1F4}.s{fill:#D8474D}.p{fill:#E7AF4B}}</style>')
    return svg(256, 256, style + body)


def main():
    os.makedirs(OUT, exist_ok=True)
    files = {
        'mark.svg': mark_file(LIGHT),
        'mark-dark.svg': mark_file(DARK),
        'mark-mono.svg': mark_file(MONO),
        'lockup-ar.svg': lockup_ar(LIGHT),
        'lockup-ar-dark.svg': lockup_ar(DARK),
        'lockup-en.svg': lockup_en(LIGHT),
        'lockup-en-dark.svg': lockup_en(DARK),
        'lockup-stacked.svg': lockup_stacked(LIGHT),
        'lockup-stacked-dark.svg': lockup_stacked(DARK),
        'app-icon.svg': app_icon(),
        'app-icon-maskable.svg': app_icon(maskable=True),
    }
    for name, content in files.items():
        with open(os.path.join(OUT, name), 'w', encoding='utf-8') as f:
            f.write(content)
    assets = os.path.join(ROOT, 'docs', 'assets')
    with open(os.path.join(assets, 'logo.svg'), 'w', encoding='utf-8') as f:
        f.write(files['mark.svg'])
    with open(os.path.join(assets, 'logo-dark.svg'), 'w', encoding='utf-8') as f:
        f.write(files['mark-dark.svg'])
    auto = mark_auto()
    for name in ('mark.svg', 'favicon.svg'):
        with open(os.path.join(assets, name), 'w', encoding='utf-8') as f:
            f.write(auto)
    # geometry for the app, which draws the mark inline with CSS colours
    with open(os.path.join(OUT, 'mark-body.txt'), 'w', encoding='utf-8') as f:
        f.write(mark_fit({'hull': 'H', 'sail': 'S', 'pearl': 'P'}, 2, 2, 60, 60).replace('fill="H"', 'class="mk-hull"')
                .replace('fill="S"', 'class="mk-sail"').replace('fill="P"', 'class="mk-pearl"'))
    print('brand written:', ', '.join(files))


if __name__ == '__main__':
    main()
