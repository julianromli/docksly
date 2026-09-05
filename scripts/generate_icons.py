#!/usr/bin/env python3
"""Generate Docksly app icons and a template menu-bar glyph as PNG files."""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPICON = ROOT / "Docksly" / "Assets.xcassets" / "AppIcon.appiconset"
MENUBAR = ROOT / "Docksly" / "Assets.xcassets" / "MenuBarIcon.imageset"


def write_png(path: Path, width: int, height: int, rgba: list[tuple[int, int, int, int]]) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(rgba[y * width + x])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def mix(c0: tuple[int, int, int], c1: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(lerp(c0[0], c1[0], t)),
        int(lerp(c0[1], c1[1], t)),
        int(lerp(c0[2], c1[2], t)),
    )


def rounded_rect_mask(x: float, y: float, w: float, h: float, r: float, px: float, py: float) -> float:
    """Coverage 0..1 for a rounded rectangle."""
    # Translate to local space with origin at center
    cx = x + w / 2
    cy = y + h / 2
    lx = abs(px - cx)
    ly = abs(py - cy)
    hw = w / 2
    hh = h / 2
    if lx <= hw - r and ly <= hh:
        return 1.0
    if ly <= hh - r and lx <= hw:
        return 1.0
    dx = max(lx - (hw - r), 0.0)
    dy = max(ly - (hh - r), 0.0)
    dist = (dx * dx + dy * dy) ** 0.5
    # 1px AA
    if dist <= r - 0.5:
        return 1.0
    if dist >= r + 0.5:
        return 0.0
    return 1.0 - (dist - (r - 0.5))


def circle_mask(cx: float, cy: float, r: float, px: float, py: float) -> float:
    dist = ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5
    if dist <= r - 0.5:
        return 1.0
    if dist >= r + 0.5:
        return 0.0
    return 1.0 - (dist - (r - 0.5))


def blend(dst: tuple[int, int, int, int], src: tuple[int, int, int], alpha: float) -> tuple[int, int, int, int]:
    a = max(0.0, min(1.0, alpha))
    inv = 1.0 - a
    return (
        int(src[0] * a + dst[0] * inv),
        int(src[1] * a + dst[1] * inv),
        int(src[2] * a + dst[2] * inv),
        int(min(255, dst[3] + a * 255)),
    )


def render_app_icon(size: int) -> list[tuple[int, int, int, int]]:
    pixels: list[tuple[int, int, int, int]] = []
    # Superellipse-ish rounded square inset
    inset = size * 0.08
    radius = size * 0.22
    dock_h = size * 0.22
    dock_y = size * 0.62
    dock_x = size * 0.16
    dock_w = size * 0.68
    dock_r = dock_h * 0.42

    dots = [
        (0.28, (56, 132, 255)),
        (0.42, (52, 211, 153)),
        None,  # spacer
        (0.68, (251, 146, 60)),
    ]

    for y in range(size):
        for x in range(size):
            px = x + 0.5
            py = y + 0.5
            # Transparent outside
            plate = rounded_rect_mask(inset, inset, size - 2 * inset, size - 2 * inset, radius, px, py)
            if plate <= 0:
                pixels.append((0, 0, 0, 0))
                continue

            # Vertical gradient plate
            t = (py - inset) / max(1.0, size - 2 * inset)
            base = mix((28, 32, 44), (18, 20, 28), t)
            # Soft highlight near top
            highlight = max(0.0, 1.0 - (py - inset) / (size * 0.35))
            base = mix(base, (70, 78, 98), highlight * 0.22)
            pix = (base[0], base[1], base[2], int(255 * plate))

            # Dock tray
            tray = rounded_rect_mask(dock_x, dock_y, dock_w, dock_h, dock_r, px, py)
            if tray > 0:
                tray_col = mix((48, 54, 70), (36, 40, 54), (py - dock_y) / dock_h)
                pix = blend(pix, tray_col, tray * 0.92)
                # Inner rim
                inner = rounded_rect_mask(
                    dock_x + size * 0.012,
                    dock_y + size * 0.012,
                    dock_w - size * 0.024,
                    dock_h - size * 0.024,
                    dock_r * 0.8,
                    px,
                    py,
                )
                if inner > 0 and tray > 0.4:
                    pix = blend(pix, (255, 255, 255), inner * 0.06)

            # App dots + spacer
            cy = dock_y + dock_h / 2
            r = dock_h * 0.28
            for entry in dots:
                if entry is None:
                    # thin spacer bar
                    sx = dock_x + dock_w * 0.55
                    spacer = rounded_rect_mask(sx - size * 0.008, cy - r * 0.7, size * 0.016, r * 1.4, size * 0.006, px, py)
                    if spacer > 0:
                        pix = blend(pix, (200, 206, 220), spacer * 0.45)
                    continue
                fx, color = entry
                cx = dock_x + dock_w * fx
                cover = circle_mask(cx, cy, r, px, py)
                if cover > 0:
                    pix = blend(pix, color, cover)
                    # gloss
                    gloss = circle_mask(cx - r * 0.25, cy - r * 0.28, r * 0.35, px, py)
                    if gloss > 0:
                        pix = blend(pix, (255, 255, 255), gloss * cover * 0.35)

            pixels.append(pix)
    return pixels


def render_menu_bar(size: int) -> list[tuple[int, int, int, int]]:
    """Black-on-transparent template glyph: a dock shelf with three tiles."""
    pixels: list[tuple[int, int, int, int]] = []
    pad = size * 0.08
    bar_h = size * 0.42
    bar_y = (size - bar_h) / 2
    bar_x = pad
    bar_w = size - 2 * pad
    bar_r = bar_h * 0.38
    tile_r = bar_h * 0.22
    tile_xs = [0.22, 0.50, 0.78]

    for y in range(size):
        for x in range(size):
            px = x + 0.5
            py = y + 0.5
            cover = rounded_rect_mask(bar_x, bar_y, bar_w, bar_h, bar_r, px, py)
            # Hollow the interior so it reads as a dock outline + tiles
            inner = rounded_rect_mask(
                bar_x + size * 0.06,
                bar_y + size * 0.10,
                bar_w - size * 0.12,
                bar_h - size * 0.20,
                bar_r * 0.55,
                px,
                py,
            )
            outline = max(0.0, cover - inner)
            tiles = 0.0
            cy = bar_y + bar_h / 2
            for fx in tile_xs:
                tiles = max(tiles, circle_mask(bar_x + bar_w * fx, cy, tile_r, px, py))
            alpha = max(outline, tiles)
            a = int(round(255 * min(1.0, alpha)))
            pixels.append((0, 0, 0, a))
    return pixels


def nearest_scale(src: list[tuple[int, int, int, int]], src_size: int, dst_size: int) -> list[tuple[int, int, int, int]]:
    if src_size == dst_size:
        return src
    out: list[tuple[int, int, int, int]] = []
    for y in range(dst_size):
        sy = min(src_size - 1, int((y + 0.5) * src_size / dst_size))
        for x in range(dst_size):
            sx = min(src_size - 1, int((x + 0.5) * src_size / dst_size))
            # Box average for downscale
            x0 = int(x * src_size / dst_size)
            x1 = max(x0 + 1, int((x + 1) * src_size / dst_size))
            y0 = int(y * src_size / dst_size)
            y1 = max(y0 + 1, int((y + 1) * src_size / dst_size))
            r = g = b = a = 0
            count = 0
            for yy in range(y0, min(src_size, y1)):
                for xx in range(x0, min(src_size, x1)):
                    p = src[yy * src_size + xx]
                    r += p[0]
                    g += p[1]
                    b += p[2]
                    a += p[3]
                    count += 1
            if count == 0:
                out.append(src[sy * src_size + sx])
            else:
                out.append((r // count, g // count, b // count, a // count))
    return out


def main() -> None:
    APPICON.mkdir(parents=True, exist_ok=True)
    MENUBAR.mkdir(parents=True, exist_ok=True)

    master = render_app_icon(1024)
    write_png(APPICON / "icon_1024.png", 1024, 1024, master)

    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for s in sizes:
        pixels = nearest_scale(master, 1024, s)
        write_png(APPICON / f"icon_{s}.png", s, s, pixels)

    menu_master = render_menu_bar(44)
    write_png(MENUBAR / "menu_22.png", 22, 22, nearest_scale(menu_master, 44, 22))
    write_png(MENUBAR / "menu_44.png", 44, 44, menu_master)
    print("Wrote app and menu bar icons")


if __name__ == "__main__":
    main()
