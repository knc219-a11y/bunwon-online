"""금사리 야생 몬스터 임시 스프라이트 시트 생성기 (모래게 · 금두꺼비).

코드로 그린 임시 그림이다. 최종 아트는 같은 규격의 PNG로 파일만 바꾸면 된다.
금사리: 마을 앞 하천 모래에서 사금이 많이 나와 붙은 이름 (2026-09-28 사용자). 몬스터는 사용자 선택 "모래게 + 금두꺼비".
규격 (슬라임 시트와 같은 칸 32x32, 방향 없음. 발바닥은 칸의 맨 아래 줄 y=31, 몸 중심 x=16):
  wild_sand_crab.png (256 x 32): 0-1 대기, 2-5 옆걸음, 6-7 모래에 숨음 (눈만 빼꼼)
  wild_gold_toad.png (192 x 32): 0-1 대기 (목 부풀기), 2-5 깡충
금사리 입구 구조물 (사용자: "입구에 커다란 도자기 모양의 구조물에 검정색 글씨로 금사리(구터)라고 쓰여있는게 특징"):
  ../props/geumsa_jar.png (48 x 64): 큰 회색 항아리 모양 표지 (사용자: 구조물은 회색, 글씨는 검정). 글씨는 게임에서 그 위에 쓴다 (몸통 가운데 y=30~46).

실행: python3 tools/make_wild_sheets.py  (Pillow 필요)
2026-09-30: 모래게 · 금두꺼비 · 아기 금두꺼비 시트는 사용자 AI 그림 (tools/import_ai_monster.py) 으로 바뀌었다. 이 스크립트를 돌리면 코드 그림으로 덮어쓰니 주의.
"""
import os

from PIL import Image

from make_character_sheet import grade_p1, outline
from make_slime_sheet import CELL, Layer

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "creatures")

EYE, GLINT = (44, 34, 56), (250, 250, 255)
SAND, SAND_D, SAND_L = (226, 196, 140), (190, 156, 104), (244, 222, 176)
GOLD = (250, 214, 90)

# 모래게: 모래빛 등딱지에 사금 반짝이
CRAB, CRAB_D, CRAB_L = (214, 132, 96), (168, 92, 70), (240, 176, 136)
# 금두꺼비: 금빛 몸, 배는 연한 크림, 등에 사마귀 점
TOAD, TOAD_D, TOAD_L = (222, 176, 70), (170, 124, 50), (246, 214, 120)
BELLY = (246, 230, 180)
MOUTH = (120, 60, 60)
CHEEK = (244, 160, 150)


def ellipse(l, cx, cy, rx, ry, c, dark=None, split=0.35):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                l.px(x, y, dark if dark and y > cy + ry * split else c)


def crab_body(l, lift=0, claw=0, step=0):
    cx, base = 15.5, 31 - lift
    # 다리 (양쪽 세 개씩, 걸음마다 번갈아 들림)
    for i, dx in enumerate((5, 8, 11)):
        up = 1 if (i + step) % 2 == 0 and step else 0
        for s in (-1, 1):
            x = cx + s * dx
            l.rect(x, base - 3 - up, x, base - up, CRAB_D)
    # 등딱지
    ellipse(l, cx, base - 7, 10, 5.5, CRAB, CRAB_D, 0.2)
    l.rect(cx - 5, base - 11, cx - 3, base - 11, CRAB_L)
    l.px(cx - 6, base - 10, CRAB_L)
    # 사금 반짝이
    for x, y in ((cx + 3, base - 9), (cx - 1, base - 7), (cx + 6, base - 6)):
        l.px(x, y, GOLD)
    # 집게 (claw: 0 내림, 1 올림)
    for s in (-1, 1):
        x = cx + s * 12
        y = base - 11 - claw * 3
        l.rect(x - 1, y, x + 1, y + 3, CRAB)
        l.rect(x - 2, y - 2, x - 2 + 1, y - 1, CRAB_L if s < 0 else CRAB)
        l.rect(x + 1, y - 2, x + 2, y - 1, CRAB)
        l.px(x, y - 1, CRAB_D)
        l.rect(x, y + 3, x, base - 8, CRAB_D)
    # 눈자루
    for s in (-1, 1):
        x = cx + s * 3
        l.rect(x, base - 15, x, base - 12, CRAB_D)
        l.rect(x - 1, base - 17, x, base - 16, EYE)
        l.px(x - 1, base - 17, GLINT)


def crab_buried(l, peek):
    cx = 15.5
    # 모래 더미
    ellipse(l, cx, 30, 12, 4 + peek, SAND, SAND_D, 0.3)
    l.rect(cx - 6, 27 - peek, cx - 3, 27 - peek, SAND_L)
    l.px(cx + 5, 28, GOLD)
    l.px(cx - 8, 30, GOLD)
    # 빼꼼 나온 눈
    for s in (-1, 1):
        x = cx + s * 3
        l.rect(x, 25 - peek * 2, x, 26 - peek, CRAB_D)
        l.rect(x - 1, 23 - peek * 2, x, 24 - peek * 2, EYE)
        l.px(x - 1, 23 - peek * 2, GLINT)


def toad_body(l, w, h, lift=0, puff=0, legs=0):
    cx, base = 15.5, 31 - lift
    # 뒷다리
    for s in (-1, 1):
        x = cx + s * (w / 2 - 1)
        if legs:
            l.rect(x - 1, base - 2, x + 1, base + 1, TOAD_D)
        else:
            ellipse(l, x, base - 2, 3, 2.2, TOAD_D)
    # 몸
    ellipse(l, cx, base - h / 2, w / 2, h / 2, TOAD, TOAD_D, 0.45)
    # 배 (목 부풀기)
    ellipse(l, cx, base - h * 0.3, w * 0.26 + puff, h * 0.22 + puff * 0.6, BELLY)
    # 등 사마귀 점과 하이라이트
    for fx, fy in ((-0.28, 0.25), (0.22, 0.2), (0.05, 0.12)):
        l.px(cx + w * fx, base - h + h * fy + 1, TOAD_L)
    l.rect(cx - w * 0.3, base - h + 2, cx - w * 0.3 + 2, base - h + 2, TOAD_L)
    # 머리 위로 튀어나온 눈
    for s in (-1, 1):
        x = cx + s * w * 0.24
        ellipse(l, x, base - h + 1, 2.6, 2.4, TOAD)
        l.rect(x - 0.5, base - h, x + 0.5, base - h + 1, EYE)
        l.px(x - 0.5, base - h, GLINT)
    # 입과 볼
    my = base - h * 0.55
    l.rect(cx - 3, my, cx + 2, my, MOUTH)
    l.px(cx - w * 0.36, my - 1, CHEEK)
    l.px(cx + w * 0.36 - 1, my - 1, CHEEK)
    # 입에 문 엽전 (금두꺼비는 재물 복을 부른다)
    l.rect(cx - 1, my + 1, cx, my + 2, GOLD)


# 사용자: "금사리 구조물의 색은 회색이고 글씨는 검정색이야"
JAR, JAR_D, JAR_L = (176, 176, 172), (140, 140, 138), (206, 206, 202)
JAR_BLUE = (122, 122, 120)
STONE, STONE_D = (150, 146, 138), (112, 108, 102)


def jar():
    """큰 회색 항아리 모양 표지 (48x64). 밑은 돌 받침."""
    w, h = 48, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    p = img.load()

    def px(x, y, c):
        if 0 <= x < w and 0 <= y < h:
            p[x, y] = (*c, 255)

    cx = 23.5
    # 돌 받침
    for y in range(58, 64):
        for x in range(6, 42):
            px(x, y, STONE_D if y >= 62 else STONE)
    # 몸통: 위는 좁은 목, 어깨에서 넓어졌다 아래로 좁아짐
    import math
    for y in range(4, 58):
        if y < 9:
            half = 8  # 입
        elif y < 12:
            half = 7  # 목
        else:
            t = (y - 12) / 46
            half = 8 + 13 * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.7
            if t > 0.87:
                half = max(half, 11)
        for x in range(int(cx - half), int(cx + half) + 1):
            c = JAR
            if x > cx + half * 0.55 or y > 54:
                c = JAR_D
            px(x, y, c)
    # 입 테두리 · 하이라이트 · 어깨의 푸른 띠
    for x in range(int(cx - 8), int(cx + 9)):
        px(x, 4, JAR_D)
    for y in range(16, 30):
        px(int(cx - 12), y, JAR_L)
        px(int(cx - 11), y + 2, JAR_L)
    for x in range(int(cx - 14), int(cx + 15)):
        px(x, 14, JAR_BLUE)
    for x in range(int(cx - 12), int(cx + 13)):
        px(x, 52, JAR_BLUE)
    return img


def frames(draws):
    img = Image.new("RGBA", (CELL * len(draws), CELL), (0, 0, 0, 0))
    for i, d in enumerate(draws):
        l = Layer()
        d(l)
        img.alpha_composite(l.img, (i * CELL, 0))
    outline(img, CELL)
    grade_p1(img)
    return img


def make():
    crab = frames([
        lambda l: crab_body(l, claw=0),
        lambda l: crab_body(l, claw=1),
        lambda l: crab_body(l, lift=1, claw=1, step=1),
        lambda l: crab_body(l, lift=2, claw=0, step=2),
        lambda l: crab_body(l, lift=1, claw=1, step=1),
        lambda l: crab_body(l, lift=0, claw=0, step=2),
        lambda l: crab_buried(l, 0),
        lambda l: crab_buried(l, 1),
    ])
    toad = frames([
        lambda l: toad_body(l, 24, 15, puff=0),
        lambda l: toad_body(l, 24, 15, puff=1.5),
        lambda l: toad_body(l, 26, 12),
        lambda l: toad_body(l, 20, 17, lift=5, legs=1),
        lambda l: toad_body(l, 22, 16, lift=9, legs=1),
        lambda l: toad_body(l, 26, 12),
    ])
    paths = []
    for name, img in (("wild_sand_crab", crab), ("wild_gold_toad", toad)):
        path = os.path.join(OUT_DIR, f"{name}.png")
        img.save(path)
        paths.append(path)
    sign = jar()
    outline(sign, 64)
    path = os.path.join(OUT_DIR, "..", "props", "geumsa_jar.png")
    sign.save(path)
    paths.append(path)
    return paths


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for p in make():
        print(p)
