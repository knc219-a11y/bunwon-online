"""번천(3막 첫 구역) 임시 스프라이트 시트 생성기 (2026-09-29 사용자 선택 A: 도깨비불 + 유령 막차 → 아기 도깨비불).

번천: 산과 도로만 있는 삼거리. 다른 데보다 춥고 어둡고, 밤엔 버스만 다니고 사람이 안 다닌다 (사용자).
"여기는 유령타입의 몬스터를 넣자" (사용자).
코드로 그린 임시 그림이다. 규격 (32x32 칸, 방향 없음, 발바닥 y=31, 몸 중심 x=16):
  몬스터 (256 x 32): 0-1 대기, 2-5 이동, 6 예고 (공격 직전), 7 공격 뒤 지침 (때릴 틈)
  크리처 (320 x 32): 0-1 대기, 2-5 이동, 6-9 일
  wild_will_o.png (256 x 32): 도깨비불 (6 부풂 = 불똥 예고, 7 쪼그라듦 = 칠 틈)
  baby_will_o_fire.png (320 x 32): 아기 도깨비불 크리처 시트
  ghost_bus.png (96 x 48, 한 장): 유령 막차 (앞이 오른쪽, 왼쪽으로 갈 땐 게임이 좌우 반전)
  ../props/street_lamp.png (16 x 48): 가로등
후보 B · C (달걀귀신 · 저승사자 · 물귀신 · 서리 할멈) 그림은 프로젝트 파일 design/bunjeon/ 에만 남김.

실행: python3 tools/make_bunjeon_sheets.py [--preview 파일]  (Pillow 필요)
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_character_sheet import grade_p1, outline
from make_slime_sheet import CELL, Layer

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "creatures")
PROPS = os.path.join(os.path.dirname(__file__), "..", "assets", "props")
INK = (36, 30, 44)
GLINT = (250, 250, 255)
CHEEK = (244, 160, 150)
BLUE, BLUE_D, BLUE_L = (120, 180, 250), (70, 110, 210), (210, 236, 255)
FIRE, FIRE_D, FIRE_L = (250, 150, 60), (210, 80, 40), (255, 230, 130)


def ell(l, cx, cy, rx, ry, c, dark=None, split=0.35):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                l.px(x, y, dark if dark and y > cy + ry * split else c)


def flame(l, cx, base, r, col, dark, light, lift=0, lick=0):
    """불꽃 공 (도깨비불 · 아기 도깨비불): 둥근 몸 위로 혀처럼 날름거리는 꼬리."""
    cy = base - r - lift
    ell(l, cx, cy, r, r * 0.95, col, dark, 0.45)
    for i, (dx, h) in enumerate(((-r * 0.5, r * 1.1), (0, r * 1.6), (r * 0.5, r * 1.0))):
        hh = h + (1 if (i + lick) % 2 else -1)
        for k in range(int(hh)):
            w = max(0.5, (r * 0.45) * (1 - k / hh))
            l.rect(cx + dx - w + (lick % 2) * (k > hh / 2), cy - r * 0.6 - k, cx + dx + w, cy - r * 0.6 - k, col)
    ell(l, cx - r * 0.3, cy - r * 0.3, r * 0.4, r * 0.35, light)
    return cy


def will_o(l, lift=0, lick=0, big=0, dim=0):
    cx, base = 15.5, 26 - lift
    r = 5 + big * 2 - dim
    col, dark, light = (BLUE_D, INK, BLUE) if dim else (BLUE, BLUE_D, BLUE_L)
    cy = flame(l, cx, base, r, col, dark, light, 0, lick)
    for k in (-1, 1):
        ex = cx + k * 2
        l.rect(ex - 0.5, cy - 1, ex + 0.5, cy + (0 if dim else 1), INK)
    if big:
        l.rect(cx - 1.5, cy + 2, cx + 1.5, cy + 3, INK)
        for dx, dy in ((-9, -2), (9, -3), (-7, 5), (8, 6)):
            l.px(cx + dx, cy + dy, BLUE_L)


def baby_fire(l, lift=0, lick=0, work=0):
    cx, base = 15.5, 31 - lift
    cy = flame(l, cx, base, 5, FIRE, FIRE_D, FIRE_L, 0, lick)
    for k in (-1, 1):
        ex = cx + k * 2
        l.rect(ex - 0.5, cy - 1, ex, cy, INK)
        l.px(ex - 0.5, cy - 1, GLINT)
    l.px(cx - 3.5, cy + 1.5, CHEEK)
    l.px(cx + 3.5, cy + 1.5, CHEEK)
    l.rect(cx - 0.5, cy + 2, cx + 0.5, cy + 2, INK)
    if work:
        for i in range(work + 1):
            l.px(cx + 7 + i, base - 10 - i * 3, FIRE_L)
            l.px(cx - 7 - i, base - 8 - i * 3, FIRE)


def ghost_bus():
    """유령 막차: 반쯤 비치는 옛 시골 버스 (96x48), 앞이 오른쪽. 전조등 · 행선판 '막차'."""
    W, H = 96, 48
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    p = img.load()

    def r(x0, y0, x1, y1, c):
        for y in range(y0, y1):
            for x in range(x0, x1):
                p[x, y] = c

    body = (96, 150, 130, 215)
    r(6, 10, 90, 40, body)
    r(6, 28, 90, 31, (230, 222, 190, 220))
    r(6, 10, 90, 13, (70, 120, 104, 220))
    for x in range(12, 76, 12):
        r(x, 15, x + 9, 25, (40, 50, 70, 230))
        r(x + 1, 16, x + 3, 18, (160, 200, 230, 180))
    r(78, 14, 88, 26, (40, 50, 70, 230))
    r(84, 30, 90, 34, (255, 244, 190, 255))
    r(80, 3, 92, 9, (30, 30, 34, 230))
    for x in (14, 70):
        r(x, 38, x + 10, 46, (26, 26, 30, 240))
        r(x + 3, 41, x + 7, 43, (120, 120, 130, 240))
    r(0, 40, 96, 42, (0, 0, 0, 60))
    img2 = img.copy()
    outline(img2, 96)
    return img2


def street_lamp():
    """번천 가로등 (16x48, 밑동 가운데 x=8, y=44). 불빛은 게임이 PointLight2D 로 그린다."""
    img = Image.new("RGBA", (16, 48), (0, 0, 0, 0))
    p = img.load()
    POLE, POLE_D, LAMP = (104, 108, 118, 255), (70, 72, 82, 255), (255, 244, 190, 255)
    for y in range(8, 45):
        p[7, y] = POLE
        p[8, y] = POLE_D
    for x in range(8, 14):
        p[x, 6] = POLE
        p[x, 7] = POLE_D
    for x in range(11, 15):
        p[x, 8] = LAMP
        p[x, 9] = LAMP
    for x in range(5, 11):
        p[x, 44] = POLE_D
        p[x, 45] = POLE_D
    outline(img, 16)
    return img


def sheet(draws):
    img = Image.new("RGBA", (CELL * len(draws), CELL), (0, 0, 0, 0))
    for i, d in enumerate(draws):
        l = Layer()
        d(l)
        img.alpha_composite(l.img, (i * CELL, 0))
    outline(img, CELL)
    grade_p1(img)
    return img


def make():
    out = {
        "wild_will_o": sheet([
            lambda l: will_o(l), lambda l: will_o(l, lick=1, lift=1),
            lambda l: will_o(l, lift=2), lambda l: will_o(l, lift=3, lick=1), lambda l: will_o(l, lift=2), lambda l: will_o(l, lick=1),
            lambda l: will_o(l, big=1, lick=1), lambda l: will_o(l, dim=1)]),
        "baby_will_o_fire": sheet([
            lambda l: baby_fire(l), lambda l: baby_fire(l, lick=1),
            lambda l: baby_fire(l, lift=2), lambda l: baby_fire(l, lift=3, lick=1), lambda l: baby_fire(l, lift=2), lambda l: baby_fire(l, lick=1),
            lambda l: baby_fire(l, work=1), lambda l: baby_fire(l, work=2, lick=1), lambda l: baby_fire(l, work=1), lambda l: baby_fire(l)]),
        "ghost_bus": ghost_bus(),
    }
    os.makedirs(OUT, exist_ok=True)
    street_lamp().save(os.path.join(PROPS, "street_lamp.png"))
    for k, img in out.items():
        img.save(os.path.join(OUT, k + ".png"))
        print(k)
    return out


if __name__ == "__main__":
    if "--out" in sys.argv:
        OUT = sys.argv[sys.argv.index("--out") + 1]
    out = make()
    if "--preview" in sys.argv:
        ims = [i.resize((i.width * 4, i.height * 4), Image.NEAREST) for i in out.values()]
        pv = Image.new("RGBA", (max(i.width for i in ims), sum(i.height + 8 for i in ims)), (40, 44, 60, 255))
        y = 0
        for i in ims:
            pv.alpha_composite(i, (0, y))
            y += i.height + 8
        pv.save(sys.argv[sys.argv.index("--preview") + 1])
