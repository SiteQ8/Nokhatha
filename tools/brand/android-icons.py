#!/usr/bin/env python3
"""Turns docs/app/icons.js into android/.../ui/IconPaths.kt, so Android draws the web's own icons.
Circles, ellipses, rectangles, lines and polylines become path data."""
import re, os
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
src = open(f'{root}/docs/app/icons.js', encoding='utf-8').read()
body = src[src.index('const P = {'):src.index('};', src.index('const P = {'))]
entries = re.findall(r"\n  (\w+): '((?:[^'\\]|\\.)*)',", body)
def f(v): return ('%.3f' % float(v)).rstrip('0').rstrip('.')
def attrs(el): return dict(re.findall(r'([\w-]+)="([^"]*)"', el))
out = []
for name, svg in entries:
    parts = []
    for tag, raw in re.findall(r'<(path|circle|rect|line|polyline|ellipse)\b([^>]*)/?>', svg):
        a = attrs(raw); fill = 'fill' in a.get('class', '')
        if tag == 'path': d = a['d']
        elif tag in ('circle', 'ellipse'):
            cx, cy = float(a['cx']), float(a['cy']); rx = float(a.get('r', a.get('rx', 0))); ry = float(a.get('r', a.get('ry', 0)))
            d = f"M{f(cx-rx)} {f(cy)}a{f(rx)} {f(ry)} 0 1 0 {f(2*rx)} 0a{f(rx)} {f(ry)} 0 1 0 {f(-2*rx)} 0Z"
        elif tag == 'rect':
            x, y, w, h = float(a.get('x', 0)), float(a.get('y', 0)), float(a['width']), float(a['height']); rx = float(a.get('rx', 0))
            d = (f"M{f(x+rx)} {f(y)}h{f(w-2*rx)}a{f(rx)} {f(rx)} 0 0 1 {f(rx)} {f(rx)}v{f(h-2*rx)}a{f(rx)} {f(rx)} 0 0 1 {f(-rx)} {f(rx)}h{f(-(w-2*rx))}a{f(rx)} {f(rx)} 0 0 1 {f(-rx)} {f(-rx)}v{f(-(h-2*rx))}a{f(rx)} {f(rx)} 0 0 1 {f(rx)} {f(-rx)}Z"
                 if rx else f"M{f(x)} {f(y)}h{f(w)}v{f(h)}h{f(-w)}Z")
        elif tag == 'line': d = f"M{a['x1']} {a['y1']}L{a['x2']} {a['y2']}"
        else:
            pts = a['points'].replace(',', ' ').split(); d = 'M' + ' '.join(pts[:2]) + 'L' + ' '.join(pts[2:])
        parts.append((d, fill))
    out.append((name, parts))
kt = ['// Generated from docs/app/icons.js by tools/brand/android-icons.py, so Android draws the same line icons as the web.',
      '// 24 unit grid, stroke 1.75. Do not edit by hand.', 'package com.eworldq8.nokhatha.ui', '',
      'internal class IconPart(val d: String, val fill: Boolean)', '', 'internal val ICON_PATHS: Map<String, List<IconPart>> = mapOf(']
for name, parts in out:
    kt.append(f'    "{name}" to listOf(' + ', '.join('IconPart("%s", %s)' % (d.replace('"', '\\"'), 'true' if fl else 'false') for d, fl in parts) + '),')
kt.append(')')
dest = f'{root}/android/app/src/main/java/com/eworldq8/nokhatha/ui/IconPaths.kt'
open(dest, 'w', encoding='utf-8').write('\n'.join(kt) + '\n')
print('icons:', len(out))
