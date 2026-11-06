"""Shared layout helpers for the integrated v07 world graybox atlas.

The PDF is a design deliverable, not a claim of shipped functionality or a
physical playtest. Chinese fonts use Type 3 embedding for reliable rendering.
"""
from pathlib import Path
import json
import math
import hashlib
import unicodedata
import importlib.util
import io
import re
import csv

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.font_manager import FontProperties
from matplotlib.patches import Rectangle, FancyBboxPatch, FancyArrowPatch, Polygon

OUT = Path(__file__).resolve().parent
ROOT = OUT.parent
MODEL = OUT / 'world-room-layout-v04.json'
FONT_PATH = OUT / 'assets/foundry_notes.otf'
if not FONT_PATH.exists():
    FONT_PATH = ROOT / 'world-production-v04/assets/foundry_notes.otf'
FONT = FontProperties(fname=str(FONT_PATH))
plt.rcParams.update({'pdf.fonttype': 3, 'svg.fonttype': 'path',
                     'axes.unicode_minus': False, 'figure.max_open_warning': 0})
BG = '#f5f8fa'
INK = '#173749'
MUTED = '#516c7d'
LINE = '#cddbe3'
BLUE = '#256da2'
TEAL = '#167d70'
GOLD = '#9f701d'
PURPLE = '#7559a4'
WHITE = '#ffffff'
FIGSIZE = (16.54, 11.69)
XPT = FIGSIZE[0] * 72 * .92 / 100
YPT = FIGSIZE[1] * 72 * .91 / 100
PAGES = []
PAGE_META = []
LAYOUT_WARNINGS = []
ROUTE_CHECKS = {}


def boss_rows(d):
    plan = d.get('boss_plan', {})
    if isinstance(plan, list):
        return plan
    return plan.get('bosses', d.get('bosses', []))


def clean(value):
    return str(value).replace('—', '-').replace('–', '-').replace('↔', '<->').replace('\u2011', '-')


def wrap(value, max_units):
    rows = []
    for raw in clean(value).split('\n'):
        row = ''
        units = 0
        for token in re.findall(r'[A-Za-z0-9_./:+<>=-]+|.', raw):
            token_width = sum(1 if unicodedata.east_asian_width(ch) in 'WF' else .54 for ch in token)
            chunks = list(token) if token_width > max_units else [token]
            for chunk in chunks:
                width = sum(1 if unicodedata.east_asian_width(ch) in 'WF' else .54 for ch in chunk)
                if row and units + width > max_units:
                    rows.append(row)
                    row = ''
                    units = 0
                row += chunk
                units += width
        rows.append(row)
    return '\n'.join(rows)


def txt(ax, x, y, value, size=11.5, color=INK, **kwargs):
    return ax.text(x, y, clean(value), fontproperties=FONT, fontsize=size,
                   color=color, va='top', linespacing=1.32, **kwargs)


def para(ax, x, y, width, value, size=11.5, color=INK, **kwargs):
    value = wrap(value, width * XPT / size)
    artist = txt(ax, x, y, value, size, color, **kwargs)
    return y + len(value.split('\n')) * size * 1.32 / YPT


def page(title, subtitle='', section='开发总案'):
    fig = plt.figure(figsize=FIGSIZE, facecolor=BG)
    ax = fig.add_axes([.04, .045, .92, .91])
    ax.set(xlim=(0, 100), ylim=(100, 0))
    ax.axis('off')
    ax.add_patch(Rectangle((0, 0), .65, 6.2, color=TEAL, lw=0))
    txt(ax, 2, -.25, title, 24)
    txt(ax, 2, 5.7, subtitle, 10.7, MUTED)
    ax.plot([0, 100], [10, 10], color=LINE, lw=.9)
    txt(ax, 0, 98.3, '失序之钟 · 世界灰盒图册 v07 · 2026-11-06 · 结构交接 / 实机标定在开发中完成', 8.8, MUTED)
    txt(ax, 100, 98.3, f'{section}  /  {len(PAGES)+1:02d}', 8.8, MUTED, ha='right')
    PAGES.append(fig)
    PAGE_META.append({'page': len(PAGES), 'title': title, 'section': section})
    return fig, ax


def table(ax, headers, widths, rows, y=14, min_row=7.5, size=10.8, max_y=94):
    xs = [0]
    for width in widths:
        xs.append(xs[-1] + width)
    ax.add_patch(Rectangle((0, y), 100, 5, facecolor='#dfebf1', edgecolor='none'))
    for i, head in enumerate(headers):
        txt(ax, xs[i] + 1, y + 1, head, size, BLUE)
    y += 5
    for ridx, row in enumerate(rows):
        values = [wrap(v, (widths[i] - 2.2) * XPT / size) for i, v in enumerate(row)]
        height = max(min_row, max(len(v.split('\n')) for v in values) * size * 1.32 / YPT + 2.1)
        if y + height > max_y + .01:
            raise ValueError(f'Table overflow on page {len(PAGES)} row {ridx}: {y+height:.1f}>{max_y}')
        if ridx % 2 == 0:
            ax.add_patch(Rectangle((0, y), 100, height, facecolor=WHITE, edgecolor='none'))
        for i, value in enumerate(values):
            txt(ax, xs[i] + 1, y + 1, value, size)
        ax.plot([0, 100], [y + height, y + height], color=LINE, lw=.6)
        y += height
    return y


def split_table_rows(rows, widths, *, y=14, min_row=7.5, size=10.8, max_y=94, max_rows=None):
    """Paginate full text, never hide a long cell or shrink type to force a fit."""
    chunks = []
    chunk = []
    used = y + 5
    for row in rows:
        values = [wrap(v, (widths[i] - 2.2) * XPT / size) for i, v in enumerate(row)]
        height = max(min_row, max(len(v.split('\n')) for v in values) * size * 1.32 / YPT + 2.1)
        if height > max_y - y - 5:
            raise ValueError('One table row is taller than a page; split its content explicitly')
        if chunk and (used + height > max_y or (max_rows and len(chunk) >= max_rows)):
            chunks.append(chunk)
            chunk = []
            used = y + 5
        chunk.append(row)
        used += height
    if chunk:
        chunks.append(chunk)
    return chunks


def card(ax, x, y, w, h, title, body, color=TEAL, size=11.4):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=.35,rounding_size=.6',
                               facecolor=WHITE, edgecolor=LINE, linewidth=.9))
    txt(ax, x + 1.6, y + 1.6, title, 15, color)
    end = para(ax, x + 1.6, y + 7, w - 3.2, body, size)
    if end > y + h - .8:
        raise ValueError(f'Card overflow on page {len(PAGES)}: {title}: {end:.1f}>{y+h-.8}')


def section_note(ax, title, body, y=84, color=BLUE):
    txt(ax, 0, y, title, 13.2, color)
    para(ax, 0, y + 4, 100, body, 10.8, MUTED)


def clauses(value):
    names = {'eq_lamp': '已装灯', 'eq_filter': '已装滤芯', 'royal_sigil': '王室纹章',
             'clock_T': '根钟', 'clock_R': '遗迹排水', 'clock_A': '外环校相',
             'clock_E': '炉钟', 'bomb': '炸弹', 'smith': '武器匠', 'lamp': '持有灯',
             'filter': '持有滤芯'}
    return ' 或 '.join('+'.join(names.get(t, t) for t in c) or '基础能力' for c in value)


