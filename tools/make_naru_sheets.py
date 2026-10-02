"""나루터 · 팔당호 물가 임시 그림 생성기 (2026-10-02 시설 4 사용자 선택 A 나루터 + B 통발).

코드로 그린 임시 그림이다.
  ../assets/props/lake.png (216 x 192): 마을 오른쪽 아래 팔당호 물가 (칸 31~39 · 16~23줄). 물 칸은 Config.LAKE_ROWS 와 같다
  ../assets/props/lake_ruin.png · lake_naru.png (216 x 192): 같은 자리 위에 덮는 무너진 잔교 / 고친 잔교 + 나룻배
  ../assets/props/naru_ruin.png · naru.png (72 x 64): 나루 터 / 나룻집 (3칸 x 2칸 자리, 분원나루 표지 · 그물 걸이)
  ../assets/props/trap.png (16 x 12): 물에 놓은 통발 (게임이 놓은 수만큼)
  ../assets/props/fish.png (16 x 16): 물고기 아이콘
  ../assets/characters/ferryman.png (288 x 144): 뱃사공 (대장장이 시트에 남색 저고리 · 삿갓을 씌운 임시 그림)

실행: python3 tools/make_naru_sheets.py  (Pillow 필요)
"""
import colorsys
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from make_character_sheet import outline

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
T = 24
INK = (40, 30, 34)
WATER = (92, 150, 176); WATER_D = (70, 122, 152); WATER_L = (150, 196, 210); FOAM = (226, 240, 236)
SAND = (214, 192, 140); SAND_D = (184, 160, 110)
WOOD = (150, 104, 70); WOOD_D = (108, 74, 52); WOOD_L = (186, 140, 98)
STRAW = (222, 190, 116); STRAW_D = (176, 140, 80)
PAPER = (246, 238, 214)
## 칸 31~39 · 16~23 안에서 줄마다 물이 시작하는 칸 (Config.LAKE_ROWS 와 같게)
LAKE_ORIGIN = (31, 16)
LAKE_ROWS = {16: 39, 17: 38, 18: 37, 19: 36, 20: 35, 21: 34, 22: 33, 23: 33}
W, H = 9 * T, 8 * T


def R(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=c)


def shore_x(y):
    """물가 선: 줄마다 물이 시작하는 칸의 왼쪽 끝을 이은 선 (조금 구불구불)"""
    row = 16 + min(7, y // T)
    base = (LAKE_ROWS[row] - LAKE_ORIGIN[0]) * T
    nxt = (LAKE_ROWS[min(23, row + 1)] - LAKE_ORIGIN[0]) * T
    f = (y % T) / T
    return int(base + (nxt - base) * f * 0.5 + 2 * ((y // 5) % 2))


def lake():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    rnd = random.Random(7)
    for y in range(H):
        sx = shore_x(y)
        for x in range(W):
            if x >= sx:
                deep = x - sx > 22
                px[x, y] = (*(WATER_D if deep else WATER), 255)
            elif x >= sx - 7:
                px[x, y] = (*(SAND if (x + y) % 9 else SAND_D), 255)
    d = ImageDraw.Draw(img)
    for y in range(H):
        sx = shore_x(y)
        if sx < W:
            R(d, sx, y, min(W, sx + 2), y + 1, FOAM)
    for i in range(70):
        x = rnd.randint(0, W - 6); y = rnd.randint(0, H - 2)
        if px[x, y][:3] in (WATER, WATER_D) and px[min(W - 1, x + 6), y][:3] in (WATER, WATER_D):
            R(d, x, y, x + rnd.choice((3, 5, 6)), y + 1, WATER_L)
    # 물가 갈대
    for x, y in ((180, 6), (160, 30), (140, 56), (118, 80), (96, 104), (72, 128), (50, 152), (40, 176)):
        for k in range(3):
            d.line([(x + k * 3, y + 12), (x + k * 3 + (k - 1), y)], fill=(96, 140, 80))
            R(d, x + k * 3 + (k - 1), y - 2, x + k * 3 + (k - 1) + 2, y + 2, (150, 110, 70))
    return img


def jetty(img, ruin):
    """잔교: 나룻집 (칸 32~34 · 17~18) 오른쪽 아래에서 물로 비스듬히"""
    d = ImageDraw.Draw(img)
    x0, y0 = 4 * T - 6, 3 * T - 2
    n = 4 if ruin else 7
    for i in range(n):
        x = x0 + i * 12; y = y0 + i * 6
        if ruin and i % 2:
            continue
        d.polygon([(x, y), (x + 14, y + 7), (x + 14, y + 13), (x, y + 6)], fill=WOOD_L if i % 2 else WOOD)
        d.line([(x, y + 6), (x + 14, y + 13)], fill=WOOD_D)
    for i in range(0, 7, 3):
        x = x0 + i * 12; y = y0 + i * 6
        R(d, x, y + 6, x + 3, y + (14 if ruin else 22), WOOD_D)
        R(d, x + 12, y + 12, x + 15, y + (18 if ruin else 26), WOOD_D)
    if ruin:
        # 가라앉은 배 · 떠다니는 널빤지
        d.polygon([(150, 120), (184, 116), (180, 126), (154, 128)], fill=WOOD_D)
        R(d, 120, 104, 134, 107, WOOD)
        return img
    bx, by = 160, 116
    d.polygon([(bx - 26, by), (bx + 26, by), (bx + 19, by + 11), (bx - 19, by + 11)], fill=WOOD)
    d.polygon([(bx - 26, by), (bx + 26, by), (bx + 22, by + 4), (bx - 22, by + 4)], fill=WOOD_L)
    R(d, bx - 15, by + 3, bx + 15, by + 5, WOOD_D)
    d.line([(bx + 4, by - 2), (bx + 28, by - 22)], fill=WOOD_D, width=2)
    d.line([(bx - 22, by + 11), (bx + 22, by + 11)], fill=WATER_L)
    d.line([(x0 + 6 * 12 + 14, y0 + 6 * 6 + 10), (bx - 20, by + 2)], fill=(220, 210, 180))  # 배 묶은 줄
    return img


def naru(ruin):
    img = Image.new("RGBA", (72, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if ruin:
        d.polygon([(6, 60), (24, 36), (44, 44), (40, 60)], fill=(150, 130, 96))
        d.polygon([(10, 44), (30, 26), (50, 34), (28, 50)], fill=STRAW_D)
        for x, y in ((8, 58), (44, 56), (54, 60)):
            R(d, x, y, x + 10, y + 3, WOOD_D)
        R(d, 56, 38, 59, 62, WOOD_D)
        d.polygon([(48, 34), (68, 38), (66, 46), (50, 42)], fill=PAPER)
        d.line([(50, 36), (64, 44)], fill=INK)
    else:
        # 나룻집 (초가 원두막) + 분원나루 표지 + 그물 걸이
        R(d, 6, 30, 40, 62, (196, 168, 120))
        R(d, 6, 30, 8, 62, WOOD_D); R(d, 38, 30, 40, 62, WOOD_D)
        R(d, 16, 42, 30, 62, WOOD_D); R(d, 17, 43, 29, 61, (120, 86, 60))
        d.polygon([(0, 34), (46, 34), (38, 14), (8, 14)], fill=STRAW)
        for x in range(4, 44, 4):
            d.line([(x, 34), (x + (23 - x) // 4, 16)], fill=STRAW_D)
        R(d, 8, 12, 38, 15, STRAW_D)
        R(d, 56, 22, 59, 62, WOOD_D)
        R(d, 46, 14, 70, 26, PAPER); d.rectangle([46, 14, 69, 25], outline=INK)
        for i, x in enumerate((49, 55, 61)):  # 표지 글자 대신 먹 점 (작아서)
            R(d, x, 18, x + 4, 22, INK)
        R(d, 44, 36, 46, 62, WOOD_D); R(d, 66, 36, 68, 62, WOOD_D); R(d, 44, 36, 68, 38, WOOD_D)
        for x in range(47, 66, 3):
            d.line([(x, 39), (x + 2, 56)], fill=(206, 206, 192))
        for y in range(41, 57, 4):
            d.line([(46, y), (66, y)], fill=(206, 206, 192))
    outline(img, 72)
    return img


def trap():
    img = Image.new("RGBA", (16, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 4, 15, 11], fill=STRAW_D); d.ellipse([2, 5, 13, 10], fill=STRAW)
    R(d, 7, 0, 9, 6, WOOD_D); R(d, 5, 0, 11, 3, (220, 70, 60))
    return img


def fish():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([3, 5, 14, 11], fill=(176, 192, 206)); d.polygon([(4, 8), (0, 4), (0, 12)], fill=(150, 168, 186))
    R(d, 11, 7, 12, 8, INK); d.line([(6, 10), (12, 10)], fill=(130, 150, 170))
    outline(img, 16)
    return img


def ferryman():
    """대장장이 시트 (AI 그림) 를 남색 저고리로 바꾸고 머리 위에 삿갓"""
    sheet = Image.open(os.path.join(ROOT, "characters", "smith.png")).convert("RGBA")
    px = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            h *= 360
            ly = y % 48
            # 앞치마 · 옷 (갈색 · 회색 계열, 얼굴 아래) → 남색
            if ly > 24 and not (v > 0.8 and s < 0.35) and (15 <= h <= 45 and s > 0.25 or s < 0.12 and 0.35 < v < 0.75):
                nr, ng, nb = colorsys.hsv_to_rgb(220 / 360, 0.38, min(1, 0.18 + v * 0.62))
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    d = ImageDraw.Draw(sheet)
    for row in range(3):
        for col in range(6):
            ox, oy = col * 48, row * 48
            top = next((y for y in range(48) for x in range(48) if px[ox + x, oy + y][3] > 0), 6)
            xs = [x for x in range(48) if px[ox + x, oy + top + 2][3] > 0]
            cx = (min(xs) + max(xs)) // 2 if xs else 24
            hy = oy + top + 6
            d.polygon([(ox + cx - 14, hy), (ox + cx + 14, hy), (ox + cx, hy - 11)], fill=STRAW)
            d.line([(ox + cx - 14, hy), (ox + cx + 14, hy)], fill=STRAW_D, width=2)
            d.line([(ox + cx, hy - 10), (ox + cx - 7, hy - 1)], fill=STRAW_D)
            d.line([(ox + cx, hy - 10), (ox + cx + 7, hy - 1)], fill=STRAW_D)
    return sheet


def main():
    base = lake()
    out = {
        "props/lake.png": base,
        "props/lake_ruin.png": jetty(Image.new("RGBA", (W, H), (0, 0, 0, 0)), True),
        "props/lake_naru.png": jetty(Image.new("RGBA", (W, H), (0, 0, 0, 0)), False),
        "props/naru_ruin.png": naru(True),
        "props/naru.png": naru(False),
        "props/trap.png": trap(),
        "props/fish.png": fish(),
        "characters/ferryman.png": ferryman(),
    }
    for path, img in out.items():
        img.save(os.path.join(ROOT, path))
        print(path, img.size)


if __name__ == "__main__":
    main()
