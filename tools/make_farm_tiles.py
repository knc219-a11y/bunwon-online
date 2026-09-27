"""농장 바닥 타일셋 · 작물 성장 단계 임시 생성기.

코드로 그린 임시 그림이다. 최종 아트는 같은 규격의 PNG로 파일만 바꾸면 된다.
규격은 docs/sprites.md "농장 바닥 타일" 참고. 칸 24x24 (타일 24px).
  farm_tiles.png (384 x 96, 16열 x 4행)
    행 0: 풀 변형 0-3, 흙길 변형(연결 없음 규칙과 무관한 속 채움) 4-5
    행 1: 갈아 둔 밭, 열 = 이웃 연결 비트 (위 1, 오른쪽 2, 아래 4, 왼쪽 8)
    행 2: 물 준 밭, 열 = 이웃 연결 비트
    행 3: 흙길 가장자리, 열 = 이웃 연결 비트
  crops.png (96 x 24, 4열): 작물 성장 단계 0 씨앗, 1 싹, 2 자람, 3 다 자람

밭과 흙길 칸은 가장자리가 투명하다. 게임은 풀을 먼저 깔고 그 위에 그린다.

실행: python3 tools/make_farm_tiles.py  (Pillow 필요)
"""
import os
import random

from PIL import Image

from make_character_sheet import grade_p1, outline

T = 24
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "tiles")

N, E, S, W = 1, 2, 4, 8

GRASS = (118, 170, 96)
GRASS_D = (92, 144, 80)
GRASS_L = (150, 196, 118)
GRASS_ALT = (124, 176, 100)
FLOWERS = [(250, 236, 170), (246, 190, 196), (236, 240, 250)]

SOIL = (150, 108, 76)
SOIL_D = (118, 82, 60)
SOIL_DD = (96, 66, 52)
SOIL_L = (176, 132, 96)
WET = (108, 76, 60)
WET_D = (84, 58, 48)
WET_DD = (70, 48, 42)
WET_L = (128, 92, 72)
WET_SHINE = (150, 132, 138)

PATH = (214, 190, 148)
PATH_D = (188, 162, 124)
PATH_DD = (160, 134, 104)
PATH_L = (230, 212, 176)

LEAF = (96, 176, 84)
LEAF_D = (62, 132, 70)
LEAF_L = (150, 214, 110)
ROOT = (240, 150, 70)
ROOT_D = (206, 110, 56)
ROOT_L = (252, 190, 120)
SEED = (236, 214, 160)


class Tile:
    def __init__(self):
        self.img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
        self.p = self.img.load()

    def px(self, x, y, c, a=255):
        if 0 <= x < T and 0 <= y < T:
            self.p[x, y] = (*c, a)

    def get(self, x, y):
        return self.p[x, y]

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, c)


def grass(variant):
    t = Tile()
    t.rect(0, 0, T - 1, T - 1, GRASS)
    rng = random.Random(100 + variant)
    if variant == 3:
        # 조금 밝은 풀 무더기
        for y in range(T):
            for x in range(T):
                if (x - 12) ** 2 / 90 + (y - 12) ** 2 / 60 < 1 and rng.random() < 0.85:
                    t.px(x, y, GRASS_ALT)
    tufts = [3, 6, 5, 4][variant]
    for _ in range(tufts):
        x, y = rng.randrange(1, T - 2), rng.randrange(2, T - 1)
        # 풀 한 포기: 아래 어두운 점, 위로 밝은 잎 끝
        t.px(x, y, GRASS_D)
        t.px(x + 1, y, GRASS_D)
        t.px(x, y - 1, GRASS_L)
        t.px(x + 2, y - 1, GRASS_L)
    for _ in range(4):
        t.px(rng.randrange(T), rng.randrange(T), GRASS_D)
    if variant == 2:
        for _ in range(3):
            x, y = rng.randrange(2, T - 2), rng.randrange(2, T - 2)
            c = rng.choice(FLOWERS)
            t.px(x, y, c)
            t.px(x, y + 1, GRASS_D)
    return t


def soil(mask, wet):
    base, dark, deep, light = (WET, WET_D, WET_DD, WET_L) if wet else (SOIL, SOIL_D, SOIL_DD, SOIL_L)
    t = Tile()
    # 연결 안 된 쪽은 가장자리를 비워 풀이 보이게 한다
    x0 = 0 if mask & W else 1
    x1 = T - 1 if mask & E else T - 2
    y0 = 0 if mask & N else 2
    y1 = T - 1 if mask & S else T - 2
    t.rect(x0, y0, x1, y1, base)
    rng = random.Random(7 + mask)
    for _ in range(10):
        t.px(rng.randrange(x0, x1 + 1), rng.randrange(y0, y1 + 1), dark)
    # 이랑: 칸 경계와 무관하게 같은 높이라 이웃 칸과 이어진다
    for fy in (5, 11, 17, 23):
        if not (y0 <= fy <= y1):
            continue
        fx0 = x0 + (0 if mask & W else 2)
        fx1 = x1 - (0 if mask & E else 2)
        for x in range(fx0, fx1 + 1):
            t.px(x, fy, dark)
            if fy - 1 >= y0:
                t.px(x, fy - 1, light)
    # 가장자리: 위는 밝은 둔덕, 아래는 두 줄 어두운 옆면, 좌우는 한 줄 어둡게
    if not mask & N:
        for x in range(x0, x1 + 1):
            t.px(x, y0, light)
    if not mask & S:
        for x in range(x0, x1 + 1):
            t.px(x, y1, deep)
            t.px(x, y1 - 1, dark)
        # 밭 아래 풀에 옅은 그림자
        for x in range(x0 + 1, x1):
            t.px(x, y1 + 1, (60, 90, 60), 90)
    if not mask & W:
        for y in range(y0, y1 + 1):
            t.px(x0, y, dark)
    if not mask & E:
        for y in range(y0, y1 + 1):
            t.px(x1, y, deep)
    # 바깥 모서리는 한 픽셀 깎아 둥글게
    for cond, x, y in ((not mask & N and not mask & W, x0, y0), (not mask & N and not mask & E, x1, y0),
                       (not mask & S and not mask & W, x0, y1), (not mask & S and not mask & E, x1, y1)):
        if cond:
            t.px(x, y, (0, 0, 0), 0)
    if wet:
        for _ in range(4):
            x, y = rng.randrange(x0 + 2, x1 - 1), rng.randrange(y0 + 2, y1 - 1)
            t.px(x, y, WET_SHINE)
    return t


def path_fill(variant):
    t = Tile()
    t.rect(0, 0, T - 1, T - 1, PATH)
    rng = random.Random(300 + variant)
    for _ in range(12):
        t.px(rng.randrange(T), rng.randrange(T), PATH_D)
    for _ in range(2 + variant):
        # 작은 돌
        x, y = rng.randrange(1, T - 2), rng.randrange(1, T - 2)
        t.px(x, y, PATH_L)
        t.px(x + 1, y, PATH_L)
        t.px(x, y + 1, PATH_DD)
        t.px(x + 1, y + 1, PATH_D)
    return t


def path_edge(mask):
    """흙길 가장자리. 연결 안 된 쪽은 풀이 흙길로 조금씩 파고든다."""
    t = path_fill(0)
    rng = random.Random(500 + mask)

    def depth(i, side):
        # 칸 양 끝에서는 이웃 칸과 이어지도록 같은 깊이(1)로 맞춘다
        if i < 2 or i > T - 3:
            return 1
        return 1 + (1 if (i * 7 + side * 3) % 5 < 2 else 0) + (1 if rng.random() < 0.15 else 0)

    for side, bit in enumerate((N, E, S, W)):
        if mask & bit:
            continue
        for i in range(T):
            d = depth(i, side)
            for k in range(d + 1):
                x, y = {N: (i, k), S: (i, T - 1 - k), W: (k, i), E: (T - 1 - k, i)}[bit]
                if k < d:
                    t.px(x, y, (0, 0, 0), 0)
                else:
                    t.px(x, y, PATH_DD if bit in (N, W) else PATH_D)
    return t


def crop(stage):
    t = Tile()
    cx, ground = 12, 18
    if stage == 0:
        # 씨앗 자리: 작게 봉긋한 흙과 씨앗 두 알
        for x in range(cx - 3, cx + 3):
            t.px(x, ground, SOIL_L)
        t.px(cx - 1, ground - 1, SEED)
        t.px(cx + 1, ground - 1, SEED)
    elif stage == 1:
        for y in range(ground - 3, ground + 1):
            t.px(cx, y, LEAF_D)
        t.rect(cx - 3, ground - 5, cx - 1, ground - 4, LEAF)
        t.rect(cx + 1, ground - 6, cx + 3, ground - 5, LEAF_L)
    elif stage == 2:
        for y in range(ground - 7, ground + 1):
            t.px(cx, y, LEAF_D)
        for (lx, ly, w) in ((-5, -4, 4), (1, -5, 4), (-4, -9, 3), (1, -10, 3)):
            t.rect(cx + lx, ground + ly, cx + lx + w, ground + ly + 1, LEAF)
            t.px(cx + lx + (0 if lx < 0 else w), ground + ly, LEAF_L)
    else:
        # 다 자람: 흙 위로 드러난 주황 뿌리와 무성한 잎 (작물 종류는 미정, 임시 모양)
        for y in range(ground - 4, ground + 2):
            half = 3 if y < ground else 2
            for x in range(cx - half, cx + half + 1):
                t.px(x, y, ROOT)
            t.px(cx - half, y, ROOT_L)
            t.px(cx + half, y, ROOT_D)
        for y in range(ground - 3, ground + 1, 2):
            t.px(cx + 1, y, ROOT_D)
        for (lx, ly, w, h) in ((-6, -9, 4, 3), (-2, -12, 3, 5), (2, -10, 4, 3), (-1, -7, 2, 2)):
            t.rect(cx + lx, ground + ly, cx + lx + w, ground + ly + h, LEAF)
            t.px(cx + lx + 1, ground + ly, LEAF_L)
            t.px(cx + lx + w, ground + ly + h, LEAF_D)
    return t


def tileset():
    img = Image.new("RGBA", (T * 16, T * 4), (0, 0, 0, 0))
    for v in range(4):
        img.paste(grass(v).img, (v * T, 0))
    for v in range(2):
        img.paste(path_fill(v).img, ((4 + v) * T, 0))
    for m in range(16):
        img.paste(soil(m, False).img, (m * T, T))
        img.paste(soil(m, True).img, (m * T, 2 * T))
        img.paste(path_edge(m).img, (m * T, 3 * T))
    grade_p1(img)
    return img


def crops():
    img = Image.new("RGBA", (T * 4, T), (0, 0, 0, 0))
    for s in range(4):
        img.paste(crop(s).img, (s * T, 0))
    outline(img, T)
    grade_p1(img)
    return img


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, img in (("farm_tiles", tileset()), ("crops", crops())):
        path = os.path.join(OUT_DIR, f"{name}.png")
        img.save(path)
        print(path)
