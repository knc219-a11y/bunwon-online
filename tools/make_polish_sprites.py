"""그래픽 시범 (마을 + 분원농협) 스프라이트 생성기.

2026-09-30 그래픽 시범 스레드. 코드로 그리던 임시 도형을 스프라이트로 바꾼다.
  assets/props/forage.png   120 x 24 (24x24 5칸): 0 냉이 · 1 쑥 · 2 달래 · 3 도라지 싹 · 4 물 준 풀밭 얼룩
  assets/tiles/ground_deco.png 160 x 16 (16x16 10칸): 마을 풀밭 장식
      0 개망초 · 1 민들레 · 2 제비꽃 · 3 토끼풀 · 4 풀포기 · 5 긴 풀포기 · 6 조약돌 · 7 이끼 돌 · 8 잡초 덤불 · 9 큰 돌
  assets/tiles/yard_deco.png 96 x 16 (16x16 6칸): 분원농협 마당 장식
      0 금 · 1 금 사이 잡초 · 2 기름 얼룩 · 3 물웅덩이 · 4 흩어진 볏짚 · 5 낙엽
  assets/props/plot_sign.png 24 x 24: 잠긴 밭 팻말 (값은 게임이 글씨로 씀)
  assets/hunt/drops.png     80 x 16 (16x16 5칸): 0 알 (흰 바탕, 게임이 종 색으로 물들임) · 1 빨간 물약 · 2 슬라임 젤리 · 3 돈 · 4 잡템
그림 맨 아래 줄이 땅. 발밑 그림자는 게임이 그린다.

실행: python3 tools/make_polish_sprites.py  (Pillow 필요)
"""
import os

from PIL import Image, ImageDraw

from make_character_sheet import grade_p1

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")

LEAF, LEAF_D, LEAF_DD, LEAF_L = (104, 176, 88), (72, 138, 74), (56, 104, 66), (160, 214, 120)
SAGE, SAGE_D, SAGE_L = (150, 178, 142), (112, 142, 112), (196, 218, 186)
BLADE, BLADE_D, BLADE_L = (96, 184, 92), (64, 140, 78), (156, 222, 126)
WHITE, WHITE_D = (250, 248, 238), (214, 208, 200)
YEL, YEL_D = (250, 214, 84), (218, 168, 58)
VIO, VIO_D, VIO_L = (150, 116, 210), (112, 84, 170), (190, 164, 236)
SOIL, SOIL_D, SOIL_DD, SOIL_L = (150, 108, 76), (118, 82, 60), (92, 64, 50), (178, 134, 98)
STONE, STONE_D, STONE_L = (172, 168, 160), (132, 128, 124), (212, 208, 200)
MOSS = (120, 160, 90)
GRASS_D, GRASS_DD = (92, 144, 80), (72, 120, 70)
WOOD, WOOD_D, WOOD_DD, WOOD_L = (176, 128, 86), (140, 98, 68), (110, 76, 56), (206, 160, 112)
PAPER = (246, 238, 214)
CONC_D, CONC_DD = (150, 146, 142), (120, 116, 114)
OIL = (86, 80, 92)
WATER, WATER_L = (132, 168, 200), (196, 222, 240)
STRAW, STRAW_D = (232, 204, 124), (196, 160, 88)
ORANGE, ORANGE_D = (228, 140, 70), (184, 98, 56)
RED, RED_D, RED_L = (214, 64, 70), (160, 42, 56), (250, 140, 140)
GLASS = (230, 236, 240)
CORK = (184, 140, 96)
JELLY, JELLY_D, JELLY_L = (120, 190, 230), (84, 146, 200), (210, 240, 255)
GOLD, GOLD_D, GOLD_L = (238, 194, 76), (196, 146, 52), (255, 236, 150)
CLOTH, CLOTH_D = (178, 150, 120), (138, 112, 90)


class C:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.w, self.h = w, h

    def px(self, x, y, c, a=255):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), (*c, a))

    def rect(self, x0, y0, x1, y1, c):
        self.d.rectangle((x0, y0, x1, y1), fill=c)

    def ell(self, x0, y0, x1, y1, c):
        self.d.ellipse((x0, y0, x1, y1), fill=c)

    def line(self, x0, y0, x1, y1, c, w=1):
        self.d.line((x0, y0, x1, y1), fill=c, width=w)


def soft_outline(img):
    """투명 칸에 닿은 테두리를 이웃보다 어둡고 보랏빛으로 (캐릭터 시트와 같은 식, 칸 구분 없음)."""
    src = img.copy()
    p, q = src.load(), img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if p[x, y][3]:
                continue
            ns = [p[x + dx, y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if 0 <= x + dx < w and 0 <= y + dy < h and p[x + dx, y + dy][3] > 200]
            if not ns:
                continue
            r = sum(n[0] for n in ns) / len(ns)
            g = sum(n[1] for n in ns) / len(ns)
            b = sum(n[2] for n in ns) / len(ns)
            q[x, y] = (int(r * 0.35 + 16), int(g * 0.35 + 10), int(b * 0.35 + 18), 255)


def cell(size=24):
    return C(size, size)


# ---------- 나물 · 도라지 (24x24) ----------
def dirt_mound(c, cx, by, rx=7):
    c.ell(cx - rx, by - 5, cx + rx, by, SOIL)
    c.ell(cx - rx + 2, by - 5, cx + rx - 3, by - 2, SOIL_L)
    c.px(cx - 3, by - 2, SOIL_D)
    c.px(cx + 3, by - 1, SOIL_D)


def naengi():
    c = cell()
    dirt_mound(c, 12, 21)
    # 바닥에 붙은 톱니 잎 방석
    for dx, dy, col in ((-7, 0, LEAF_D), (7, 0, LEAF_D), (-5, -3, LEAF), (5, -3, LEAF), (-2, -4, LEAF), (2, -4, LEAF)):
        c.ell(12 + dx - 3, 16 + dy, 12 + dx + 3, 19 + dy, col)
    for x in (5, 8, 16, 19):
        c.px(x, 16, LEAF_L)
    # 가는 꽃대 + 작은 흰 꽃
    c.line(12, 16, 12, 6, LEAF_D)
    c.line(12, 11, 9, 7, LEAF_D)
    c.line(12, 10, 15, 6, LEAF_D)
    for x, y in ((12, 4), (9, 5), (15, 4), (11, 6), (13, 6)):
        c.rect(x - 1, y - 1, x, y, WHITE)
        c.px(x, y, WHITE_D)
    return c


def ssuk():
    c = cell()
    dirt_mound(c, 12, 21)
    # 회녹색 깃털 잎 다발
    for ang_x, top in ((-6, 9), (-3, 6), (0, 4), (3, 6), (6, 9)):
        x0, x1 = 12, 12 + ang_x
        c.line(x0, 18, x1, top, SAGE_D, 2)
        for t in range(3):
            y = top + 2 + t * 3
            x = x1 + (x0 - x1) * t // 4
            c.px(x - 1, y, SAGE)
            c.px(x + 1, y, SAGE)
            c.px(x, y - 1, SAGE_L)
    c.px(12, 3, SAGE_L)
    return c


def dallae():
    c = cell()
    dirt_mound(c, 12, 21)
    # 흰 알뿌리가 흙 위로 살짝
    c.ell(9, 15, 15, 20, WHITE)
    c.px(10, 16, (255, 255, 255))
    c.line(10, 19, 14, 19, WHITE_D)
    # 가늘고 긴 잎
    for x1, y1 in ((5, 4), (8, 2), (12, 1), (16, 3), (19, 6)):
        c.line(12, 15, x1, y1, BLADE)
        c.px(x1, y1, BLADE_L)
    c.line(11, 15, 7, 6, BLADE_D)
    return c


def doraji():
    c = cell()
    # 갈라진 흙 둔덕 (땅속 뿌리)
    c.ell(4, 13, 20, 21, SOIL_D)
    c.ell(5, 13, 19, 19, SOIL)
    c.ell(7, 13, 15, 16, SOIL_L)
    c.line(8, 18, 11, 15, SOIL_DD)
    c.line(11, 15, 13, 17, SOIL_DD)
    c.line(15, 16, 17, 18, SOIL_DD)
    # 뿌리 머리 (연한 살색) 살짝
    c.ell(10, 15, 14, 18, (236, 220, 190))
    # 줄기 + 풍선 꽃봉오리 (도라지)
    c.line(12, 15, 12, 7, LEAF_D)
    c.ell(8, 10, 11, 12, LEAF)
    c.ell(13, 11, 16, 13, LEAF)
    c.ell(9, 1, 15, 7, VIO)
    c.ell(10, 2, 13, 4, VIO_L)
    c.line(12, 1, 12, 7, VIO_D)
    return c


def wet_patch():
    c = cell()
    c.ell(3, 12, 21, 22, (*SOIL_D, 110))
    c.ell(5, 13, 18, 20, (*SOIL_DD, 120))
    c.ell(7, 14, 11, 16, (*WATER_L, 150))
    c.px(15, 18, WATER_L, 170)
    return c


# ---------- 풀밭 장식 (16x16) ----------
def daisy(c):
    c.line(8, 15, 8, 9, GRASS_D)
    c.line(8, 13, 5, 11, GRASS_D)
    for x, y in ((8, 7), (5, 9)):
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            c.px(x + dx, y + dy, WHITE)
        c.px(x, y, YEL)


def dandelion(c):
    c.ell(3, 12, 13, 15, LEAF_D)
    c.px(4, 12, LEAF)
    c.px(11, 12, LEAF)
    c.line(8, 13, 8, 8, LEAF_D)
    c.ell(6, 5, 10, 9, YEL)
    c.px(7, 6, (255, 244, 170))
    c.px(9, 8, YEL_D)


def violet(c):
    c.line(7, 15, 7, 10, GRASS_D)
    c.line(10, 15, 10, 11, GRASS_D)
    for x, y in ((7, 9), (10, 10)):
        c.px(x - 1, y, VIO)
        c.px(x + 1, y, VIO)
        c.px(x, y - 1, VIO_L)
        c.px(x, y + 1, VIO_D)
        c.px(x, y, (255, 240, 180))


def clover(c):
    for cx, cy in ((5, 12), (10, 11), (8, 14)):
        for dx, dy in ((-1, 0), (1, 0), (0, -1)):
            c.px(cx + dx, cy + dy, LEAF)
        c.px(cx, cy, LEAF_D)
    c.ell(9, 6, 12, 9, WHITE)
    c.px(10, 7, (255, 230, 236))
    c.line(10, 9, 10, 11, GRASS_D)


def tuft(c, tall=False):
    h = 9 if tall else 5
    for x, top in ((5, 15 - h + 2), (7, 15 - h), (9, 15 - h + 1), (11, 15 - h + 3)):
        c.line(x, 15, x + (1 if x > 8 else -1 if x < 7 else 0), top, GRASS_DD if x in (5, 11) else GRASS_D)
        c.px(x + (1 if x > 8 else -1 if x < 7 else 0), top, LEAF_L)


def pebble(c):
    c.ell(4, 11, 10, 15, STONE_D)
    c.ell(4, 10, 10, 14, STONE)
    c.px(6, 11, STONE_L)
    c.ell(10, 13, 13, 15, STONE)
    c.px(11, 13, STONE_L)


def moss_rock(c):
    c.ell(2, 8, 14, 15, STONE_D)
    c.ell(2, 7, 14, 14, STONE)
    c.ell(4, 7, 9, 10, STONE_L)
    c.ell(7, 11, 14, 14, MOSS)
    c.px(9, 12, LEAF_L)


def weeds(c):
    for x, top, col in ((3, 6, GRASS_DD), (5, 3, GRASS_D), (8, 1, LEAF_D), (10, 4, GRASS_D), (12, 7, GRASS_DD)):
        c.line(8, 15, x, top, col)
        c.px(x, top, LEAF_L)
    c.ell(5, 11, 11, 15, GRASS_D)
    c.px(6, 5, (200, 190, 150))


def big_rock(c):
    c.ell(1, 6, 15, 15, STONE_D)
    c.ell(1, 5, 14, 13, STONE)
    c.ell(3, 5, 9, 9, STONE_L)
    c.line(9, 8, 11, 12, STONE_D)


# ---------- 분원농협 마당 장식 (16x16) ----------
def crack(c):
    for a, b in (((1, 9), (5, 8)), ((5, 8), (8, 10)), ((8, 10), (12, 7)), ((12, 7), (15, 8)), ((8, 10), (9, 13))):
        c.line(*a, *b, CONC_DD)
    c.px(6, 9, CONC_D)


def crack_weed(c):
    crack(c)
    for x, top in ((7, 4), (8, 2), (10, 5)):
        c.line(8, 9, x, top, GRASS_D)
        c.px(x, top, LEAF_L)


def oil(c):
    c.ell(2, 7, 14, 13, (*OIL, 90))
    c.ell(4, 8, 10, 11, (*OIL, 70))
    c.px(6, 9, (180, 160, 200), 110)
    c.px(9, 10, (160, 200, 190), 100)


def puddle(c):
    c.ell(1, 8, 15, 14, (*CONC_DD, 160))
    c.ell(2, 8, 14, 13, (*WATER, 220))
    c.line(4, 10, 8, 10, WATER_L)
    c.px(11, 11, WATER_L)


def straw(c):
    for a, b, col in (((2, 12), (8, 10), STRAW), ((5, 13), (12, 12), STRAW_D), ((7, 9), (13, 11), STRAW), ((3, 10), (6, 14), STRAW_D)):
        c.line(*a, *b, col)


def leaf(c):
    c.ell(4, 9, 10, 13, ORANGE)
    c.line(4, 13, 10, 9, ORANGE_D)
    c.ell(9, 11, 13, 14, YEL)
    c.px(11, 12, YEL_D)


# ---------- 팻말 (24x24) ----------
def plot_sign():
    c = cell()
    c.rect(11, 12, 12, 23, WOOD_D)
    c.px(11, 12, WOOD)
    c.rect(2, 3, 21, 13, WOOD_DD)
    c.rect(3, 3, 20, 12, WOOD)
    c.rect(4, 4, 19, 11, PAPER)
    c.line(3, 3, 20, 3, WOOD_L)
    return c


# ---------- 사냥터 줍는 것 (16x16) ----------
def egg_white(c):
    # 게임이 종의 알 색으로 곱해 칠한다 (밝은 회색조로 음영만)
    c.ell(4, 4, 12, 15, (200, 200, 200))
    c.ell(4, 3, 11, 13, (238, 238, 238))
    c.ell(5, 4, 8, 7, (255, 255, 255))


def potion(c):
    c.rect(7, 1, 9, 3, CORK)
    c.rect(6, 4, 10, 5, GLASS)
    c.ell(3, 5, 13, 15, (170, 170, 186))
    c.ell(3, 5, 13, 14, RED)
    c.ell(4, 9, 12, 14, RED_D)
    c.px(5, 7, RED_L)
    c.px(6, 6, (255, 255, 255))


def jelly(c):
    c.ell(2, 7, 14, 15, JELLY_D)
    c.ell(2, 6, 14, 14, JELLY)
    c.ell(4, 7, 8, 10, JELLY_L)
    c.px(10, 12, JELLY_L)


def coins(c):
    for x, y in ((3, 9), (8, 10), (5, 6)):
        c.ell(x, y, x + 6, y + 4, GOLD_D)
        c.ell(x, y - 1, x + 6, y + 3, GOLD)
        c.px(x + 2, y, GOLD_L)
        c.rect(x + 3, y + 1, x + 3, y + 1, GOLD_D)


def junk(c):
    c.ell(3, 7, 13, 15, CLOTH_D)
    c.ell(3, 6, 13, 14, CLOTH)
    c.line(6, 6, 8, 3, CLOTH_D)
    c.line(10, 6, 8, 3, CLOTH_D)
    c.px(8, 2, (200, 60, 60))
    c.px(6, 9, (206, 182, 150))


def strip(fns, size):
    sheet = Image.new("RGBA", (size * len(fns), size), (0, 0, 0, 0))
    for i, fn in enumerate(fns):
        c = C(size, size)
        r = fn(c)
        img = (r or c).img
        soft_outline(img)
        grade_p1(img)
        sheet.alpha_composite(img, (i * size, 0))
    return sheet


def main():
    out = {
        "props/forage.png": strip([lambda c: naengi(), lambda c: ssuk(), lambda c: dallae(), lambda c: doraji()], 24),
        "tiles/ground_deco.png": strip([daisy, dandelion, violet, clover, tuft, lambda c: tuft(c, True), pebble, moss_rock, weeds, big_rock], 16),
        "hunt/drops.png": strip([egg_white, potion, jelly, coins, junk], 16),
    }
    # 물 얼룩 · 마당 얼룩은 반투명이라 외곽선 없이
    forage = out["props/forage.png"]
    wet = wet_patch().img
    grade_p1(wet)
    full = Image.new("RGBA", (120, 24), (0, 0, 0, 0))
    full.alpha_composite(forage, (0, 0))
    full.alpha_composite(wet, (96, 0))
    out["props/forage.png"] = full
    yard = Image.new("RGBA", (96, 16), (0, 0, 0, 0))
    for i, fn in enumerate([crack, crack_weed, oil, puddle, straw, leaf]):
        c = C(16, 16)
        fn(c)
        if fn in (straw, leaf):
            soft_outline(c.img)
        grade_p1(c.img)
        yard.alpha_composite(c.img, (i * 16, 0))
    out["tiles/yard_deco.png"] = yard
    sign = plot_sign().img
    soft_outline(sign)
    grade_p1(sign)
    out["props/plot_sign.png"] = sign
    for name, img in out.items():
        path = os.path.join(ROOT, name)
        img.save(path)
        print("saved", path, img.size)


if __name__ == "__main__":
    main()
