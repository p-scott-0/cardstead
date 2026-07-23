#!/usr/bin/env python3
"""Generate the app icons (icon_ios_1024.png + icon.png) with the Python
stdlib only — no Pillow. Draws two stacked cards with a tree icon and a coin
on a green felt background using per-pixel signed-distance shapes.

Run from the repo root:  python tools/make_icons.py
"""
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SIZE = 1024


def write_png(path: Path, size: int, rgb_rows):
    raw = bytearray()
    for row in rgb_rows:
        raw.append(0)  # filter: none
        raw.extend(row)

    def chunk(tag: bytes, payload: bytes) -> bytes:
        out = struct.pack(">I", len(payload)) + tag + payload
        out += struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
        return out

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)  # 8-bit RGB
    data = (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))
    path.write_bytes(data)
    print(f"wrote {path} ({len(data)} bytes)")


def rrect_cov(px, py, cx, cy, hw, hh, r):
    dx = abs(px - cx) - (hw - r)
    dy = abs(py - cy) - (hh - r)
    ox = dx if dx > 0 else 0.0
    oy = dy if dy > 0 else 0.0
    d = math.hypot(ox, oy) - r
    if d <= -0.5:
        return 1.0
    if d >= 0.5:
        return 0.0
    return 0.5 - d


def circle_cov(px, py, cx, cy, r):
    d = math.hypot(px - cx, py - cy) - r
    if d <= -0.5:
        return 1.0
    if d >= 0.5:
        return 0.0
    return 0.5 - d


def blend(base, color, cov):
    if cov <= 0.0:
        return base
    a = color[3] * cov
    return (base[0] + (color[0] - base[0]) * a,
            base[1] + (color[1] - base[1]) * a,
            base[2] + (color[2] - base[2]) * a)


def main():
    s = SIZE
    cx, cy = s / 2, s / 2
    card_hw, card_hh, card_r = 235, 325, 46
    back_cx, back_cy = cx - 70, cy - 55
    front_cx, front_cy = cx + 62, cy + 48
    header_h = 110

    shadow = (0.0, 0.0, 0.0, 0.28)
    back_body = (0.91, 0.86, 0.75, 1.0)
    back_head = (0.30, 0.60, 0.30, 1.0)
    front_body = (0.957, 0.937, 0.886, 1.0)
    front_head = (0.247, 0.47, 0.784, 1.0)
    tree_green = (0.18, 0.475, 0.235, 1.0)
    trunk = (0.42, 0.30, 0.18, 1.0)
    coin_gold = (0.955, 0.80, 0.30, 1.0)
    coin_ring = (0.72, 0.55, 0.14, 1.0)

    tree_cx, tree_cy, tree_r = front_cx, front_cy - 10, 128
    trunk_hw, trunk_hh = 24, 66
    trunk_cx, trunk_cy = front_cx, front_cy + 140
    coin_cx = front_cx + card_hw - 30
    coin_cy = front_cy + card_hh - 30
    coin_r = 84

    rows = []
    for y in range(s):
        row = bytearray()
        fy = y + 0.5
        grad = y / s
        bg = (0.118 + 0.075 * grad, 0.240 + 0.125 * grad, 0.172 + 0.088 * grad)
        for x in range(s):
            fx = x + 0.5
            c = bg
            # back card
            c = blend(c, shadow, rrect_cov(fx, fy, back_cx + 6, back_cy + 16, card_hw, card_hh, card_r))
            c = blend(c, back_body, rrect_cov(fx, fy, back_cx, back_cy, card_hw, card_hh, card_r))
            if fy < back_cy - card_hh + header_h:
                c = blend(c, back_head, rrect_cov(fx, fy, back_cx, back_cy, card_hw, card_hh, card_r))
            # front card
            c = blend(c, shadow, rrect_cov(fx, fy, front_cx + 6, front_cy + 18, card_hw, card_hh, card_r))
            c = blend(c, front_body, rrect_cov(fx, fy, front_cx, front_cy, card_hw, card_hh, card_r))
            if fy < front_cy - card_hh + header_h:
                c = blend(c, front_head, rrect_cov(fx, fy, front_cx, front_cy, card_hw, card_hh, card_r))
            # tree icon on front card
            c = blend(c, trunk, rrect_cov(fx, fy, trunk_cx, trunk_cy, trunk_hw, trunk_hh, 12))
            c = blend(c, tree_green, circle_cov(fx, fy, tree_cx, tree_cy, tree_r))
            # coin
            c = blend(c, coin_ring, circle_cov(fx, fy, coin_cx, coin_cy, coin_r))
            c = blend(c, coin_gold, circle_cov(fx, fy, coin_cx, coin_cy, coin_r - 12))
            row.extend((min(255, int(c[0] * 255 + 0.5)),
                        min(255, int(c[1] * 255 + 0.5)),
                        min(255, int(c[2] * 255 + 0.5))))
        rows.append(bytes(row))
        if y % 128 == 0:
            print(f"  render {y}/{s}")

    write_png(ROOT / "icon_ios_1024.png", s, rows)

    # 128px project icon: 8x8 box average of the big render
    small = 128
    factor = s // small
    small_rows = []
    for sy in range(small):
        row = bytearray()
        for sx in range(small):
            r_acc = g_acc = b_acc = 0
            for oy in range(factor):
                src = rows[sy * factor + oy]
                base = sx * factor * 3
                for ox in range(factor):
                    i = base + ox * 3
                    r_acc += src[i]
                    g_acc += src[i + 1]
                    b_acc += src[i + 2]
            n = factor * factor
            row.extend((r_acc // n, g_acc // n, b_acc // n))
        small_rows.append(bytes(row))
    write_png(ROOT / "icon.png", small, small_rows)


if __name__ == "__main__":
    main()
