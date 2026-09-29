"""도마리(4구역) 임시 스프라이트 시트 생성기 (고목 그루터기 · 천하대장군 · 지하여장군 · 아기 나무 정령).

코드로 그린 임시 그림이다. 최종 아트는 같은 규격의 PNG로 파일만 바꾸면 된다.
도마리: 나무꾼 마을 (2026-09-29 사용자: "여긴 나무꾼 하는사람이 있는데 이거랑 연관지은 나무 관련 몬스터",
"몬스터는 고목그루터기 몬스터로 하고 보스는 장승", "장승은 천하대장군 지하여장군 무섭게 그리자", "알은 나무정령알").
규격 (32x32 칸, 방향 없음. 발바닥 y=31, 몸 중심 x=16):
  wild_old_stump.png (256 x 32): 0-1 깨어 있음, 2-5 뿌리 다리로 걷기, 6 그루터기인 척 (숨음), 7 숨은 채 눈 번쩍
  wild_cheonha.png / wild_jiha.png (256 x 32): 0-1 노려봄, 2-5 깡충, 6-7 성남 (눈에 불)
  baby_tree_spirit_earth.png (320 x 32): 크리처 시트 (0-1 대기, 2-5 이동, 6-9 일 = 새싹을 흔들어 물방울)

실행: python3 tools/make_doma_sheets.py  (Pillow 필요)
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_character_sheet import grade_p1, outline
from make_slime_sheet import CELL, Layer

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "creatures")
EYE, GLINT = (36, 26, 40), (250, 250, 255)
BARK, BARK_D, BARK_L = (120, 90, 66), (84, 62, 48), (160, 124, 90)
RING, RING_D = (214, 188, 144), (176, 142, 102)
MOSS, MOSS_D = (120, 156, 88), (84, 120, 70)
LEAF, LEAF_D, LEAF_L = (96, 158, 80), (60, 112, 62), (150, 200, 110)
WOOD, WOOD_D, WOOD_L = (168, 140, 110), (120, 96, 78), (204, 182, 150)
INK = (40, 30, 34)
BLOOD, BLOOD_D = (196, 46, 40), (130, 28, 30)
FIRE = (255, 214, 90)
TOOTH = (244, 238, 222)
CHEEK = (244, 160, 150)


def ell(l, cx, cy, rx, ry, c, dark=None, split=0.35):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                l.px(x, y, dark if dark and y > cy + ry * split else c)


# 고목 그루터기: 나무꾼이 베고 간 오래된 그루터기가 뿌리를 다리 삼아 일어난다. 녹슨 도끼가 박혀 있다.
def stump(l, lift=0, hide=0, step=0, glow=False, axe=1):
    cx, base = 15.5, 31 - lift
    h = 15 - hide * 6
    if not hide:
        for i, dx in enumerate((-7, -3, 2, 6)):
            up = 1 if step and (i + step) % 2 == 0 else 0
            l.rect(cx + dx - 1, base - 3 - up, cx + dx + 1, base - up, BARK_D)
            l.px(cx + dx + (2 if dx > 0 else -2), base - up, BARK_D)
    top = base - 3 - h
    l.rect(cx - 8, top, cx + 8, base - 3, BARK)
    l.rect(cx + 5, top, cx + 8, base - 3, BARK_D)
    for y in range(int(top + 2), int(base - 3), 3):
        l.px(cx - 5, y, BARK_D)
        l.px(cx + 1, y + 1, BARK_D)
        l.px(cx - 2, y + 2, BARK_L)
    # 이끼 · 나이테 윗면
    l.rect(cx - 8, base - 6, cx - 4, base - 4, MOSS)
    ell(l, cx, top, 8, 2.8, RING, RING_D, 0.5)
    ell(l, cx, top, 5, 1.8, RING_D)
    ell(l, cx, top, 2.5, 0.9, RING)
    if hide < 2 or glow:
        ey = top + 5 if hide < 2 else top + 3
        for k in (-1, 1):
            x = cx + k * 3
            l.rect(x - 1, ey, x + 1, ey + 1, FIRE if glow else EYE)
            l.px(x - k * 2, ey - 1, INK)
            l.px(x - k, ey - 1, INK)
        if hide < 2:
            # 쩍 벌어진 나무 입
            l.rect(cx - 3, ey + 4, cx + 3, ey + 6, INK)
            for x in (cx - 2, cx, cx + 2):
                l.px(x, ey + 4, RING)
    if axe and hide < 2:
        ay = top - 4 + (2 if step == 2 else 0)
        l.rect(cx + 9, ay, cx + 9, ay + 9, WOOD_L)
        l.rect(cx + 10, ay - 1, cx + 13, ay + 3, (140, 110, 100))
        l.px(cx + 13, ay + 3, (170, 90, 60))


# 장승: 무섭게. 부릅뜬 붉은 눈, 치켜든 눈썹, 주먹코, 송곳니 드러낸 입, 몸통에 새긴 먹글씨 (작아서 줄로만).
def jangseung(l, lift=0, lean=0, fury=0, female=False):
    cx, base = 15.5 + lean, 31 - lift
    body = WOOD_D if female else WOOD
    l.rect(cx - 5, base - 15, cx + 5, base, body)
    l.rect(cx + 3, base - 15, cx + 5, base, BARK_D)
    # 나무 결
    for y in range(int(base - 13), int(base), 4):
        l.px(cx - 3, y, BARK_D)
    # 몸통 글씨 (천하대장군 / 지하여장군)
    for i in range(3):
        y = base - 8 + i * 3
        l.rect(cx - 1, y, cx + 1, y + 1, INK)
    # 머리 (몸통보다 넓게)
    hy = base - 16
    ell(l, cx, hy - 2, 6.5, 6, WOOD_L if not female else WOOD, None)
    if not female:
        # 천하대장군: 검은 관모 (높은 모자)
        l.rect(cx - 5, hy - 13, cx + 5, hy - 7, INK)
        l.rect(cx - 7, hy - 8, cx + 7, hy - 7, INK)
        l.rect(cx - 2, hy - 15, cx + 2, hy - 13, INK)
    else:
        # 지하여장군: 가운데 가르마 머리 + 붉은 연지
        ell(l, cx, hy - 7, 6.5, 3, INK)
        l.px(cx, hy - 9, WOOD)
        l.px(cx - 4, hy + 1, BLOOD)
        l.px(cx + 4, hy + 1, BLOOD)
    # 눈썹 (치켜듦)
    for k in (-1, 1):
        l.rect(cx + k * 1.5 - (k < 0) * 3, hy - 6 - (1 if fury else 0), cx + k * 1.5 + (k > 0) * 3, hy - 6 - (1 if fury else 0), INK)
        l.px(cx + k * 5, hy - 7 - (1 if fury else 0), INK)
    # 부릅뜬 눈: 흰자 크게, 붉은 테, 가운데 점 (성나면 불)
    for k in (-1, 1):
        ex = cx + k * 3
        ell(l, ex, hy - 3, 2.2, 1.9, TOOTH)
        l.px(ex - 2, hy - 3, BLOOD)
        l.px(ex + 2, hy - 3, BLOOD)
        l.rect(ex - 0.5, hy - 3.5, ex + 0.5, hy - 2.5, FIRE if fury else INK)
    # 주먹코
    ell(l, cx, hy, 1.8, 1.4, BARK_L if not female else WOOD_L)
    l.px(cx - 1, hy + 1, INK)
    l.px(cx + 1, hy + 1, INK)
    # 입: 이를 드러내고 송곳니 둘
    my = hy + 3
    l.rect(cx - 4, my, cx + 4, my + 2 + fury, BLOOD_D)
    l.rect(cx - 3, my, cx + 3, my, TOOTH)
    l.rect(cx - 3, my + 1 + fury, cx - 3, my + 3 + fury, TOOTH)
    l.rect(cx + 3, my + 1 + fury, cx + 3, my + 3 + fury, TOOTH)
    if not female:
        # 수염
        l.rect(cx - 2, my + 3 + fury, cx - 2, my + 6, INK)
        l.rect(cx + 2, my + 3 + fury, cx + 2, my + 6, INK)
        l.rect(cx, my + 4, cx, my + 7, INK)
    if fury:
        for dx, dy in ((-8, -12), (8, -11), (-9, -4), (9, -3)):
            l.px(cx + dx, hy + dy, FIRE)


# 아기 나무 정령: 도토리만 한 나무 몸에 새싹 두 잎
def spirit(l, lift=0, bob=0, water=0):
    cx, base = 15.5, 31 - lift
    l.rect(cx - 4, base - 9, cx + 4, base - 1, BARK_L)
    l.rect(cx + 2, base - 9, cx + 4, base - 1, BARK)
    l.rect(cx - 5, base - 1, cx - 3, base, BARK)
    l.rect(cx + 3, base - 1, cx + 5, base, BARK)
    ell(l, cx, base - 9, 4, 1.6, RING, RING_D, 0.5)
    for k in (-1, 1):
        l.rect(cx + k * 1.5 - 0.5, base - 6, cx + k * 1.5, base - 5, EYE)
        l.px(cx + k * 1.5 - 0.5, base - 6, GLINT)
    l.px(cx - 3, base - 4, CHEEK)
    l.px(cx + 3, base - 4, CHEEK)
    l.rect(cx, base - 14 + bob, cx + 0.5, base - 10, LEAF_D)
    ell(l, cx - 3, base - 15 + bob, 3, 1.6, LEAF, LEAF_D, 0.4)
    ell(l, cx + 3.5, base - 16 + bob, 3, 1.6, LEAF_L, LEAF, 0.4)
    if water:
        for i in range(water + 1):
            l.px(cx + 7 + i, base - 13 + i * 3, (150, 200, 240))
            l.px(cx - 7 - i, base - 12 + i * 3, (150, 200, 240))


def sheet(draws):
    img = Image.new("RGBA", (CELL * len(draws), CELL), (0, 0, 0, 0))
    for i, d in enumerate(draws):
        l = Layer()
        d(l)
        img.alpha_composite(l.img, (i * CELL, 0))
    outline(img, CELL)
    grade_p1(img)
    return img


def boss_sheet(female):
    return sheet([
        lambda l: jangseung(l, female=female), lambda l: jangseung(l, female=female, fury=1),
        lambda l: jangseung(l, lift=2, lean=-1, female=female), lambda l: jangseung(l, lift=4, female=female),
        lambda l: jangseung(l, lift=2, lean=1, female=female), lambda l: jangseung(l, female=female),
        lambda l: jangseung(l, female=female, fury=1), lambda l: jangseung(l, lift=1, female=female, fury=1)])


def make():
    out = {
        "wild_old_stump": sheet([
            lambda l: stump(l), lambda l: stump(l, lift=1),
            lambda l: stump(l, step=1), lambda l: stump(l, step=2, lift=1), lambda l: stump(l, step=1), lambda l: stump(l, step=2),
            lambda l: stump(l, hide=2, axe=0), lambda l: stump(l, hide=2, axe=0, glow=True)]),
        "wild_cheonha": boss_sheet(False),
        "wild_jiha": boss_sheet(True),
        "baby_tree_spirit_earth": sheet([
            lambda l: spirit(l), lambda l: spirit(l, bob=1),
            lambda l: spirit(l, lift=2), lambda l: spirit(l, lift=3, bob=1), lambda l: spirit(l, lift=2), lambda l: spirit(l, bob=1),
            lambda l: spirit(l, water=1), lambda l: spirit(l, water=2, bob=1), lambda l: spirit(l, water=1), lambda l: spirit(l)]),
    }
    os.makedirs(OUT, exist_ok=True)
    for k, img in out.items():
        img.save(os.path.join(OUT, k + ".png"))
        print(k)
    return out


if __name__ == "__main__":
    out = make()
    if "--preview" in sys.argv:
        ims = [i.resize((i.width * 4, i.height * 4), Image.NEAREST) for i in out.values()]
        pv = Image.new("RGBA", (max(i.width for i in ims), sum(i.height + 8 for i in ims)), (60, 50, 44, 255))
        y = 0
        for i in ims:
            pv.alpha_composite(i, (0, y))
            y += i.height + 8
        pv.save(sys.argv[sys.argv.index("--preview") + 1])
