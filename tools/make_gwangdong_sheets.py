"""광동리(3구역) 임시 스프라이트 시트 생성기 (참새 · 허수아비 장수 · 아기 참새).

코드로 그린 임시 그림이었다. 2026-09-30 부터 게임 시트는 사용자 AI 그림 (요괴 까마귀 · 허수아비 장수 · 아기 까마귀, tools/import_ai_monster.py) 이라 이 스크립트를 다시 돌리면 덮어쓴다.
광동리: 병자호란 때 군량미를 가장 많이 낸 넓은 벌판 마을 동지벌촌 (광주시 유래). 2026-09-29 사용자 선택 B. 동지벌 군량 벌판.
규격 (32x32 칸, 방향 없음. 발바닥 y=31, 몸 중심 x=16):
  wild_sparrow.png (256 x 32): 0-1 앉아 쪼기, 2-5 날갯짓 (게임이 공중 높이만큼 띄움), 6-7 낟알 쪼기
  wild_scarecrow.png (256 x 32): 0-1 흔들, 2-5 깡충 (팔 치켜듦), 6-7 짚단 던지기
  baby_sparrow_flying.png (320 x 32): 크리처 시트 (0-1 대기, 2-5 이동, 6-9 일)

실행: python3 tools/make_gwangdong_sheets.py  (Pillow 필요)
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_character_sheet import grade_p1, outline
from make_slime_sheet import CELL, Layer

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "creatures")
EYE, GLINT = (44, 34, 56), (250, 250, 255)
RED, RED_D = (226, 78, 64), (170, 48, 48)
BROWN, BROWN_D, BROWN_L = (150, 104, 70), (108, 72, 52), (190, 150, 104)
CREAM = (240, 226, 196)
STRAW, STRAW_D = (226, 194, 112), (184, 148, 80)
ARMOR, ARMOR_D = (90, 96, 120), (60, 64, 84)
BLUE = (80, 110, 170)


def ell(l, cx, cy, rx, ry, c, dark=None, split=0.35):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                l.px(x, y, dark if dark and y > cy + ry * split else c)

# 참새: 곡식 도둑. 공중 높이는 게임이 띄우므로 날갯짓 칸도 발을 바닥 근처에 둔다
def sparrow(l, lift=0, wing=0, peck=0, big=1.0, scale=1.0):
    cx, base = 15.5, 31 - lift
    s = scale
    by = base - 6 * s
    ell(l, cx, by, 7 * s, 5.5 * s, BROWN, BROWN_D, 0.1)
    ell(l, cx + 1, by + 2 * s, 4 * s, 3 * s, CREAM)
    hx, hy = cx - 5 * s, by - 5 * s + peck * 3
    ell(l, hx, hy, 4 * s, 3.6 * s, BROWN_D)
    ell(l, hx + 0.5, hy - 1, 3 * s, 2 * s, (132, 80, 56))
    l.px(hx - 1, hy + 1, CREAM)
    l.px(hx + 1, hy + 1, (40, 30, 30))
    l.rect(hx - 1.5, hy, hx - 1, hy, EYE)
    l.px(hx - 1.5, hy, GLINT)
    l.rect(hx - 5 * s, hy + 1, hx - 3.5 * s, hy + 1.5, (240, 190, 80))
    # 날개
    if wing:
        for i in range(int(7 * s)):
            l.rect(cx + i * 0.6, by - 2 - i * wing * 0.9, cx + 2 + i * 0.6, by - 1 - i * wing * 0.9, BROWN_D if i % 2 else BROWN_L)
    else:
        ell(l, cx + 2, by - 1, 4 * s, 3 * s, BROWN_L)
        l.rect(cx, by, cx + 4 * s, by, BROWN_D)
    # 꼬리 · 다리
    l.rect(cx + 6 * s, by - 3 * s, cx + 9 * s, by - 2 * s, BROWN_D)
    if lift == 0:
        l.rect(cx - 1, base - 1, cx - 1, base, (200, 140, 80))
        l.rect(cx + 2, base - 1, cx + 2, base, (200, 140, 80))


# 허수아비 장수: 군량 곳간을 지키던 허수아비 (투구 · 갑옷 조끼 · 등에 군량 깃발)
def scarecrow(l, sway=0, arm=0, lift=0):
    cx, base = 15.5 + sway, 31 - lift
    # 장대
    l.rect(cx, base - 12, cx, base, BROWN_D)
    # 몸통 짚 + 갑옷 조끼
    l.rect(cx - 5, base - 20, cx + 5, base - 11, STRAW)
    l.rect(cx - 5, base - 13, cx + 5, base - 11, STRAW_D)
    l.rect(cx - 4, base - 20, cx + 4, base - 14, ARMOR)
    l.rect(cx - 4, base - 17, cx + 4, base - 17, ARMOR_D)
    l.px(cx, base - 19, (250, 214, 90))
    # 팔 (가로 막대, arm = 치켜듦)
    l.rect(cx - 12, base - 19 - arm, cx - 5, base - 18 - arm, BROWN)
    l.rect(cx + 5, base - 19 + arm, cx + 12, base - 18 + arm, BROWN)
    for x in (cx - 13, cx + 12):
        l.rect(x, base - 20, x + 1, base - 16, STRAW_D)
    # 머리 (자루) + 투구
    ell(l, cx, base - 24, 4.5, 4, CREAM, (210, 196, 166), 0.3)
    l.rect(cx - 2, base - 25, cx - 2, base - 24, EYE)
    l.rect(cx + 1, base - 25, cx + 1, base - 24, EYE)
    l.rect(cx - 1.5, base - 22, cx + 1, base - 22, RED_D)
    l.rect(cx - 5, base - 29, cx + 5, base - 27, ARMOR)
    l.rect(cx - 1, base - 31, cx, base - 29, RED)
    # 깃발 (등에 꽂은 군량 깃발)
    l.rect(cx + 7, base - 31, cx + 7, base - 20, BROWN_D)
    l.rect(cx + 8, base - 31, cx + 12, base - 27, BLUE)
    l.px(cx + 10, base - 29, (250, 250, 240))


# ---- C 돌거북 ----


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
        "wild_sparrow": sheet([
            lambda l: sparrow(l), lambda l: sparrow(l, peck=1),
            lambda l: sparrow(l, lift=2, wing=1), lambda l: sparrow(l, lift=3, wing=-1), lambda l: sparrow(l, lift=3, wing=1), lambda l: sparrow(l, lift=2, wing=-1),
            lambda l: sparrow(l, peck=1), lambda l: sparrow(l)]),
        "wild_scarecrow": sheet([
            lambda l: scarecrow(l), lambda l: scarecrow(l, sway=1),
            lambda l: scarecrow(l, lift=2, arm=2), lambda l: scarecrow(l, lift=4, arm=3), lambda l: scarecrow(l, lift=2, arm=2), lambda l: scarecrow(l),
            lambda l: scarecrow(l, arm=3), lambda l: scarecrow(l)]),
        "baby_sparrow_flying": sheet([
            lambda l: sparrow(l, scale=0.75), lambda l: sparrow(l, scale=0.75, peck=1),
            lambda l: sparrow(l, lift=6, wing=1, scale=0.75), lambda l: sparrow(l, lift=9, wing=-1, scale=0.75), lambda l: sparrow(l, lift=9, wing=1, scale=0.75), lambda l: sparrow(l, lift=6, wing=-1, scale=0.75),
            lambda l: sparrow(l, peck=1, scale=0.75), lambda l: sparrow(l, scale=0.75), lambda l: sparrow(l, peck=1, scale=0.75), lambda l: sparrow(l, scale=0.75)]),
    }
    for k, img in out.items():
        path = os.path.join(OUT, k + ".png")
        img.save(path)
        print(path)


if __name__ == "__main__":
    make()
