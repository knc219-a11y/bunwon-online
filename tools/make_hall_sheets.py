"""마을회관 · 이장 · 잔치상 임시 그림 생성기 (2026-10-03 시설 5, Claude 추천 A 마을회관 + 잔치상 차리기).

코드로 그린 임시 그림이다.
  ../assets/props/hall_ruin.png · hall.png (96 x 72): 마을회관 터 / 마을회관 (4칸 x 2칸 자리, 슬레이트 지붕 · 확성기 기둥 · 게시판)
  ../assets/props/feast_table.png (72 x 30): 당산나무 앞 잔치상 (3칸 x 1칸 자리, 빈 상 + 멍석)
  ../assets/props/feast_dishes.png (112 x 16): 잔치 음식 일곱 칸 (농부 무 · 나물 / 사냥꾼 꼬치 / 대장장이 가마솥 / 연금술사 약주 /
      목축인 달걀찜 / 뱃사공 매운탕 / 이장 떡 · 막걸리), Config.FEAST_DISHES 순서
  ../assets/props/lantern.png (8 x 12): 잔치 청사초롱
  ../assets/characters/chief.png (288 x 144): 이장 (대장장이 시트에 하늘색 남방 · 초록 새마을 모자를 씌운 임시 그림)

실행: python3 tools/make_hall_sheets.py  (Pillow 필요)
"""
import colorsys
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from make_character_sheet import outline

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
INK = (40, 30, 34)
WOOD = (150, 104, 70); WOOD_D = (108, 74, 52); WOOD_L = (186, 140, 98)
STRAW = (222, 190, 116); STRAW_D = (176, 140, 80)
PAPER = (246, 238, 214)
WALL = (236, 228, 210); WALL_D = (200, 190, 170)
SLATE = (110, 132, 160); SLATE_D = (84, 102, 128); SLATE_L = (150, 170, 196)
RED = (200, 70, 60); BLUE = (70, 110, 190); YEL = (236, 196, 70); GRN = (90, 160, 90); WHITE = (250, 250, 244)
STEEL = (130, 130, 130); STEEL_L = (200, 200, 196)


def R(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=c)


def hall(ruin):
    img = Image.new("RGBA", (96, 72), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if ruin:
        # 무너진 슬레이트 지붕 · 벽돌 · 쓰러진 확성기 기둥
        d.polygon([(8, 70), (24, 44), (62, 50), (60, 70)], fill=(176, 160, 136))
        d.polygon([(12, 52), (34, 30), (70, 40), (44, 60)], fill=SLATE_D)
        for y in range(36, 56, 4):
            d.line([(18 + (y - 36), y + 6), (54 + (y - 36) // 2, y - 2)], fill=SLATE)
        for x, y in ((6, 66), (62, 62), (66, 68)):
            R(d, x, y, x + 12, y + 3, WOOD_D)
        d.line([(70, 70), (92, 50)], fill=STEEL, width=3)
        d.polygon([(88, 46), (96, 44), (96, 52), (90, 52)], fill=STEEL_L)
        R(d, 30, 60, 40, 66, PAPER); d.line([(31, 62), (39, 64)], fill=INK)
    else:
        R(d, 8, 34, 70, 70, WALL); R(d, 8, 64, 70, 70, WALL_D)
        d.polygon([(2, 36), (76, 36), (66, 16), (12, 16)], fill=SLATE)
        for y in range(20, 36, 4):
            d.line([(4 + (36 - y) // 2, y), (74 - (36 - y) // 2, y)], fill=SLATE_D)
        R(d, 12, 14, 66, 17, SLATE_L)
        R(d, 30, 46, 44, 70, WOOD_D); R(d, 31, 47, 43, 69, (120, 86, 60))
        R(d, 14, 44, 26, 54, (150, 190, 210)); R(d, 50, 44, 62, 54, (150, 190, 210))
        d.line([(20, 44), (20, 54)], fill=WHITE); d.line([(56, 44), (56, 54)], fill=WHITE)
        # 간판 "분원리 마을회관" (작아서 먹 점)
        R(d, 22, 37, 56, 43, PAPER); d.rectangle([22, 37, 55, 42], outline=INK)
        for x in range(25, 54, 5):
            R(d, x, 39, x + 3, 41, INK)
        # 확성기 기둥
        R(d, 82, 8, 85, 70, STEEL)
        d.polygon([(78, 8), (90, 4), (90, 14), (78, 12)], fill=STEEL_L)
        d.polygon([(86, 18), (94, 14), (94, 24), (86, 22)], fill=STEEL_L)
        # 게시판 (부탁 종이)
        R(d, 72, 46, 74, 70, WOOD_D); R(d, 92, 46, 94, 70, WOOD_D); R(d, 71, 42, 95, 58, WOOD)
        for x, y, c in ((73, 44, PAPER), (80, 45, YEL), (87, 44, PAPER), (75, 51, (240, 200, 200)), (84, 51, PAPER)):
            R(d, x, y, x + 6, y + 5, c)
    outline(img, 96)
    return img


def feast_table():
    img = Image.new("RGBA", (72, 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 멍석 (깔개) 위 긴 두레상
    d.ellipse([0, 14, 71, 29], fill=STRAW_D); d.ellipse([3, 16, 68, 27], fill=STRAW)
    R(d, 6, 8, 66, 16, WOOD); R(d, 6, 8, 66, 10, WOOD_L)
    R(d, 9, 16, 12, 22, WOOD_D); R(d, 60, 16, 63, 22, WOOD_D)
    outline(img, 72)
    return img


def dishes():
    img = Image.new("RGBA", (16 * 7, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(7):
        ox = i * 16
        if i == 0:  # 무 · 나물 한 상
            d.ellipse([ox + 1, 8, ox + 15, 15], fill=PAPER)
            d.ellipse([ox + 3, 6, ox + 9, 12], fill=WHITE); R(d, ox + 5, 2, ox + 7, 7, GRN)
            d.ellipse([ox + 9, 9, ox + 14, 13], fill=(110, 170, 90))
        elif i == 1:  # 사냥꾼 꼬치
            d.line([(ox + 2, 13), (ox + 14, 3)], fill=WOOD_D, width=1)
            for k in range(3):
                d.ellipse([ox + 4 + k * 3, 9 - k * 3, ox + 8 + k * 3, 13 - k * 3], fill=(170, 90, 60))
        elif i == 2:  # 가마솥
            d.ellipse([ox + 1, 5, ox + 15, 15], fill=(60, 60, 64)); R(d, ox + 1, 5, ox + 15, 8, (90, 90, 96))
            R(d, ox + 6, 2, ox + 10, 5, (60, 60, 64))
        elif i == 3:  # 약주 (호리병 + 잔)
            d.ellipse([ox + 3, 6, ox + 10, 15], fill=(170, 210, 190)); d.ellipse([ox + 4, 1, ox + 9, 7], fill=(170, 210, 190))
            R(d, ox + 5, 0, ox + 8, 2, RED); d.ellipse([ox + 11, 11, ox + 15, 15], fill=PAPER)
        elif i == 4:  # 달걀찜 (뚝배기)
            d.ellipse([ox + 1, 6, ox + 15, 15], fill=(110, 70, 50)); d.ellipse([ox + 3, 6, ox + 13, 11], fill=YEL)
        elif i == 5:  # 매운탕 큰 솥
            d.ellipse([ox + 1, 6, ox + 15, 15], fill=(80, 80, 86)); d.ellipse([ox + 3, 6, ox + 13, 11], fill=(210, 80, 50))
            d.ellipse([ox + 6, 7, ox + 10, 9], fill=(190, 200, 210))
        else:  # 떡 · 막걸리
            for k in range(3):
                R(d, ox + 1 + k * 3, 10 - k * 2, ox + 8 + k * 3, 14 - k * 2, (236, 220, 220) if k % 2 else (230, 160, 180))
            d.ellipse([ox + 9, 5, ox + 15, 15], fill=(230, 226, 210)); R(d, ox + 11, 3, ox + 13, 6, WOOD_D)
        sub = img.crop((ox, 0, ox + 16, 16))
        outline(sub, 16)
        img.paste(sub, (ox, 0))
    return img


def lantern():
    img = Image.new("RGBA", (8, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    R(d, 3, 0, 5, 2, INK)
    R(d, 1, 2, 7, 6, RED); R(d, 1, 6, 7, 10, BLUE); R(d, 3, 10, 5, 12, YEL)
    return img


def chief():
    """대장장이 시트 (AI 그림) 를 하늘색 남방으로 바꾸고 머리에 초록 새마을 모자"""
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
            if ly > 24 and not (v > 0.8 and s < 0.35) and (15 <= h <= 45 and s > 0.25 or s < 0.12 and 0.35 < v < 0.75):
                nr, ng, nb = colorsys.hsv_to_rgb(200 / 360, 0.32, min(1, 0.4 + v * 0.6))
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    d = ImageDraw.Draw(sheet)
    cap, cap_d = (70, 130, 80), (48, 96, 58)
    for row in range(3):
        for col in range(6):
            ox, oy = col * 48, row * 48
            top = next((y for y in range(48) for x in range(48) if px[ox + x, oy + y][3] > 0), 6)
            xs = [x for x in range(48) if px[ox + x, oy + top + 2][3] > 0]
            cx = (min(xs) + max(xs)) // 2 if xs else 24
            hy = oy + top + 5
            d.pieslice([ox + cx - 9, hy - 9, ox + cx + 9, hy + 7], 180, 360, fill=cap)
            # 챙: 아래(앞) 줄은 가운데, 옆 줄은 그쪽으로, 위(뒤) 줄은 안 보임
            if row == 0:
                d.rectangle([ox + cx - 9, hy - 1, ox + cx + 9, hy + 1], fill=cap_d)
                R(d, ox + cx - 1, hy - 6, ox + cx + 2, hy - 3, YEL)
            elif row == 1:
                d.rectangle([ox + cx - 13, hy - 1, ox + cx + 4, hy + 1], fill=cap_d)
            else:
                d.rectangle([ox + cx - 9, hy - 1, ox + cx + 9, hy], fill=cap_d)
    return sheet


def main():
    out = {
        "props/hall_ruin.png": hall(True),
        "props/hall.png": hall(False),
        "props/feast_table.png": feast_table(),
        "props/feast_dishes.png": dishes(),
        "props/lantern.png": lantern(),
        "characters/chief.png": chief(),
    }
    for path, img in out.items():
        img.save(os.path.join(ROOT, path))
        print(path, img.size)


if __name__ == "__main__":
    main()
