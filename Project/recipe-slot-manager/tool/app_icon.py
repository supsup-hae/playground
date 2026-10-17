#!/usr/bin/env python3
"""앱 아이콘과 브랜드 마크를 만든다. 형태의 기준은 이 파일 하나다.

    python3 tool/app_icon.py            # SVG 마스터 + macOS/Android PNG 를 모두 다시 만든다
    python3 tool/app_icon.py --svg-only # SVG 마스터와 Android 벡터(XML)만

표준 라이브러리만 쓴다 (PNG 는 SDF 로 직접 그린다). 마크는 256 격자:
반지름 104 다이얼을 y=112 에서 실버 상판 / 블랙 바디로 나누고, 그 경계에
왼쪽으로 열린 슬롯(높이 20)을 낸다. 슬롯 안의 점 7개가 C1–C7 이고,
가장 바깥(슬롯 입구) 점만 빨강, 나머지 여섯은 상판과 같은 실버다.
32px 이하에서는 점 하나짜리 작은 판을 쓴다.
"""
import math, os, struct, sys, zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SILVER = "#CFCBC4"
BODY = "#17191C"
RED = "#D7282F"   # 브랜드 빨강 (아이콘·인쇄). 앱 화면의 강조색은 tokens.dart 의 accent
TILE = "#FFFFFF"
LIGHT = "#ECE9E4"

R, CX, CY, SEAM = 104.0, 128.0, 128.0, 112.0

# 큰 판(64px 이상)과 작은 판(32px 이하)
FULL = dict(half=10.0, end=138.0, dots=[(40.0 + 16 * i, 4.5, i == 0) for i in range(7)], scale=0.74)
SMALL = dict(half=18.0, end=132.0, dots=[(50.0, 12.0, True)], scale=0.84)


def _f(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def _xat(y):
    return math.sqrt(R * R - (y - CY) ** 2)


# ---------- SVG 경로 (마스크 없이 구멍까지 계산한 닫힌 경로) ----------
def plate_path(s):
    top, e, h = SEAM - s["half"], s["end"], s["half"]
    return (f"M{_f(CX - _xat(top))} {_f(top)}A{_f(R)} {_f(R)} 0 0 1 {_f(CX + _xat(SEAM))} {_f(SEAM)}"
            f"L{_f(e + h)} {_f(SEAM)}A{_f(h)} {_f(h)} 0 0 0 {_f(e)} {_f(top)}Z")


def body_path(s):
    bot, e, h = SEAM + s["half"], s["end"], s["half"]
    return (f"M{_f(CX + _xat(SEAM))} {_f(SEAM)}L{_f(e + h)} {_f(SEAM)}A{_f(h)} {_f(h)} 0 0 1 {_f(e)} {_f(bot)}"
            f"L{_f(CX - _xat(bot))} {_f(bot)}A{_f(R)} {_f(R)} 0 1 0 {_f(CX + _xat(SEAM))} {_f(SEAM)}Z")


def dot_path(x, r):
    return f"M{_f(x - r)} {_f(SEAM)}A{_f(r)} {_f(r)} 0 1 0 {_f(x + r)} {_f(SEAM)}A{_f(r)} {_f(r)} 0 1 0 {_f(x - r)} {_f(SEAM)}Z"


def mark_svg(s, plate=SILVER, body=BODY, dot=SILVER, red=RED):
    # dot: 빨강이 아닌 슬롯 점의 색. 기본은 상판과 같은 실버
    out = f'<path fill="{plate}" d="{plate_path(s)}"/><path fill="{body}" d="{body_path(s)}"/>'
    for x, r, is_red in s["dots"]:
        out += f'<path fill="{red if is_red else dot}" d="{dot_path(x, r)}"/>'
    return out


def svg_doc(title, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256" role="img">'
            f"<title>{title}</title>{body}</svg>\n")


def icon_svg(s):
    g = f'<g transform="translate(128 124) scale({s["scale"]}) translate(-128 -128)">{mark_svg(s)}</g>'
    return f'<rect width="256" height="256" rx="57" fill="{TILE}"/>{g}'


def write_svgs():
    d = os.path.join(ROOT, "assets", "brand")
    os.makedirs(d, exist_ok=True)
    files = {
        "app-icon.svg": svg_doc("Recipe Slot Manager app icon", icon_svg(FULL)),
        "app-icon-small.svg": svg_doc("Recipe Slot Manager app icon, 32px and below", icon_svg(SMALL)),
        "mark.svg": svg_doc("Recipe Slot Manager mark", mark_svg(FULL)),
        "mark-on-dark.svg": svg_doc("Recipe Slot Manager mark on dark", mark_svg(FULL, plate=LIGHT, body="#34373C", dot=LIGHT, red="#EA4A35")),
        "mark-greyscale.svg": svg_doc("Recipe Slot Manager mark, greyscale", mark_svg(FULL, plate="#9A9690", body="#000000", dot="#9A9690", red="#000000")),
    }
    for name, text in files.items():
        with open(os.path.join(d, name), "w") as fh:
            fh.write(text)
    return [os.path.join("assets", "brand", n) for n in files]


# ---------- Android 적응형 아이콘 (API 26+, 벡터) ----------
def _vector(paths):
    # 108dp 캔버스 가운데 66dp 안전 영역 안에 마크(지름 208)가 들어가도록 줄인다
    body = "".join(f'\n        <path android:fillColor="{c}" android:pathData="{d}"/>' for c, d in paths)
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            '<!-- tool/app_icon.py 가 만든다. 직접 고치지 말 것 -->\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="108dp" android:height="108dp"\n'
            '    android:viewportWidth="256" android:viewportHeight="256">\n'
            '    <group android:pivotX="128" android:pivotY="128" android:scaleX="0.62" android:scaleY="0.62" android:translateY="-3">'
            f'{body}\n    </group>\n</vector>\n')


def write_android_xml():
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    fg = [(SILVER, plate_path(FULL)), (BODY, body_path(FULL))]
    fg += [(RED if r else SILVER, dot_path(x, rad)) for x, rad, r in FULL["dots"]]
    mono = [("#FFFFFF", plate_path(FULL)), ("#FFFFFF", body_path(FULL))]
    mono += [("#FFFFFF", dot_path(x, rad)) for x, rad, r in FULL["dots"]]
    files = {
        "drawable/ic_launcher_foreground.xml": _vector(fg),
        "drawable/ic_launcher_monochrome.xml": _vector(mono),
        "values/ic_launcher_background.xml": ('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                                              f'    <color name="ic_launcher_background">{TILE}</color>\n</resources>\n'),
        "mipmap-anydpi-v26/ic_launcher.xml": ('<?xml version="1.0" encoding="utf-8"?>\n'
                                              '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                                              '    <background android:drawable="@color/ic_launcher_background"/>\n'
                                              '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
                                              '    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n'
                                              '</adaptive-icon>\n'),
    }
    out = []
    for rel, text in files.items():
        full = os.path.join(res, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as fh:
            fh.write(text)
        out.append(os.path.relpath(full, ROOT))
    return out


# ---------- PNG (부호 거리 함수 + 픽셀 단위 안티앨리어싱) ----------
def _rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def _slot_sd(x, y, s):
    h, e = s["half"], s["end"]
    if x <= e:
        return abs(y - SEAM) - h
    return math.hypot(x - e, y - SEAM) - h


def _rrect_sd(x, y, cx, cy, hw, hh, r):
    qx, qy = abs(x - cx) - hw + r, abs(y - cy) - hh + r
    return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r


def render_png(path, size, s, layout):
    """layout: 'mac' (1024 기준 824 타일 + 그림자) 또는 'square' (가장자리까지 타일)."""
    if layout == "mac":
        tile_half, tile_r, tile_cy = size * 412 / 1024, size * 185 / 1024, size * 0.5
    else:
        tile_half, tile_r, tile_cy = size * 0.46, size * 0.46 * 0.445, size * 0.5
    unit = tile_half * 2 / 256                       # 타일 기준 256 격자 한 칸의 픽셀
    k = unit * s["scale"]                            # 마크 한 칸의 픽셀
    mx0, my0 = size / 2 - 128 * k, tile_cy - tile_half + 124 * unit - 128 * k
    px = 1.0 / k                                     # 한 픽셀 = 마크 단위
    tile, silver, body, red = _rgb(TILE), _rgb(SILVER), _rgb(BODY), _rgb(RED)
    rows = []
    for j in range(size):
        row = bytearray()
        for i in range(size):
            x, y = i + 0.5, j + 0.5
            col, a = (0, 0, 0), 0.0
            if layout == "mac":                      # 아주 옅은 그림자
                sd = _rrect_sd(x, y - size * 10 / 1024, size / 2, tile_cy, tile_half, tile_half, tile_r)
                a = 0.22 * max(0.0, min(1.0, 0.5 - sd / (size * 22 / 1024)))
            td = _rrect_sd(x, y, size / 2, tile_cy, tile_half, tile_half, tile_r)
            tc = max(0.0, min(1.0, 0.5 - td))
            if tc > 0:
                col = tuple(c * tc for c in tile)
                a = tc + a * (1 - tc)
                col = tuple(col[n] / a for n in range(3)) if a else col
                u, v = (x - mx0) / k, (y - my0) / k
                if -8 < u < 264 and -8 < v < 264:
                    dd = math.hypot(u - CX, v - CY) - R
                    sl = _slot_sd(u, v, s)
                    layers = [(max(dd, -sl), silver), (max(dd, SEAM - v, -sl), body)]
                    for dx, dr, is_red in s["dots"]:
                        layers.append((math.hypot(u - dx, v - SEAM) - dr, red if is_red else silver))
                    for d, c in layers:
                        cov = max(0.0, min(1.0, 0.5 - d / px))
                        if cov:
                            col = tuple(col[n] * (1 - cov) + c[n] * cov for n in range(3))
            row += bytes((int(col[0] + .5), int(col[1] + .5), int(col[2] + .5), int(min(1, a) * 255 + .5)))
        rows.append(b"\x00" + bytes(row))
    raw = zlib.compress(b"".join(rows), 9)
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
                 + chunk(b"IDAT", raw) + chunk(b"IEND", b""))


def write_pngs():
    written = []
    mac = os.path.join(ROOT, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(mac, exist_ok=True)
    for n in (16, 32, 64, 128, 256, 512, 1024):
        p = os.path.join(mac, f"app_icon_{n}.png")
        render_png(p, n, SMALL if n <= 32 else FULL, "mac")
        written.append(p)
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    for folder, n in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        p = os.path.join(res, f"mipmap-{folder}", "ic_launcher.png")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        render_png(p, n, SMALL if n < 96 else FULL, "square")
        written.append(p)
    return written


if __name__ == "__main__":
    for p in write_svgs() + write_android_xml():
        print("wrote", p)
    if "--svg-only" not in sys.argv:
        for p in write_pngs():
            print("wrote", os.path.relpath(p, ROOT))
