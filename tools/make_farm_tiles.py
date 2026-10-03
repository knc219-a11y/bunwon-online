"""농장 바닥 타일셋 · 작물 성장 단계 임시 생성기.

코드로 그린 임시 그림이다. 최종 아트는 같은 규격의 PNG로 파일만 바꾸면 된다.
규격은 docs/sprites.md "농장 바닥 타일" 참고. 칸 24x24 (타일 24px).
  farm_tiles.png (384 x 96, 16열 x 4행)
    행 0: 풀 변형 0-3, 흙길 변형(연결 없음 규칙과 무관한 속 채움) 4-5
    행 1: 갈아 둔 밭, 열 = 이웃 연결 비트 (위 1, 오른쪽 2, 아래 4, 왼쪽 8)
    행 2: 물 준 밭, 열 = 이웃 연결 비트
    행 3: 흙길 가장자리, 열 = 이웃 연결 비트
  crops.png (96 x 96, 4열 x 4행): 성장 단계 0 씨앗, 1 싹, 2 자람, 3 다 자람.
    행 = 작물 (Config.CROPS 의 row): 0 무, 1 감자, 2 고추, 3 배추 (2026-10-03 농사 다양화)

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
# 무 (첫 작물, 2026-09-27 결정): 흰 뿌리, 윗부분 연두 어깨
RADISH = (244, 240, 228)
RADISH_D = (212, 206, 192)
RADISH_DD = (186, 178, 168)
RADISH_TOP = (178, 212, 134)
RADISH_TOP_D = (140, 186, 112)
RADISH_TOP_L = (200, 226, 160)
SEED = (236, 214, 160)
# 감자: 짙은 잎 덤불 + 흰 꽃, 다 자라면 흙 위로 드러난 갈색 감자
POTATO = (196, 156, 104)
POTATO_D = (160, 120, 80)
POTATO_L = (222, 188, 136)
POTATO_LEAF = (84, 150, 76)
POTATO_FLOWER = (244, 240, 250)
# 고추: 가는 줄기, 다 자라면 빨간 고추가 주렁주렁
PEPPER = (214, 58, 48)
PEPPER_D = (170, 40, 40)
PEPPER_L = (240, 110, 90)
PEPPER_G = (110, 170, 70)
# 배추: 겹겹이 둥근 연두 잎, 속은 노르스름
CABBAGE = (170, 214, 120)
CABBAGE_D = (120, 176, 92)
CABBAGE_L = (214, 236, 168)
CABBAGE_IN = (236, 238, 190)


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


def ellipse(t, cx, cy, rx, ry, c):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1:
                t.px(x, y, c)


def radish_leaf(t, x0, y0, dx, n):
    """톱니 있는 긴 무청 한 장. 줄기 밑동에서 비스듬히(dx) 위로 n칸 뻗는다."""
    for i in range(n):
        x, y = x0 + dx * i, y0 - i
        t.px(x, y, LEAF_D if i == 0 else LEAF)
        t.px(x + dx, y, LEAF)
        if i % 2 == 1:
            t.px(x - dx, y - 1, LEAF_L)


def crop(stage):
    """첫 작물 무 (2026-09-27 결정). 0 씨앗, 1 떡잎, 2 무청과 흰 머리, 3 다 자란 무."""
    t = Tile()
    cx, ground = 12, 18
    if stage == 0:
        # 씨앗 자리: 작게 봉긋한 흙과 씨앗 두 알
        for x in range(cx - 3, cx + 3):
            t.px(x, ground, SOIL_L)
        t.px(cx - 1, ground - 1, SEED)
        t.px(cx + 1, ground - 1, SEED)
    elif stage == 1:
        # 둥근 떡잎 두 장
        for y in range(ground - 3, ground + 1):
            t.px(cx, y, LEAF_D)
        ellipse(t, cx - 2.5, ground - 4.5, 1.5, 1, LEAF)
        ellipse(t, cx + 2.5, ground - 5, 1.5, 1, LEAF_L)
    elif stage == 2:
        # 무청이 뻗고 흙 위로 하얀 머리가 살짝
        t.rect(cx - 1, ground - 1, cx + 1, ground, RADISH)
        t.px(cx + 1, ground, RADISH_D)
        radish_leaf(t, cx - 1, ground - 2, -1, 6)
        radish_leaf(t, cx + 1, ground - 2, 1, 6)
        radish_leaf(t, cx, ground - 2, 0, 8)
    else:
        # 다 자람: 흙 위로 올라온 굵은 흰 뿌리(윗부분 연두)와 무성한 무청
        for y in range(ground - 5, ground + 2):
            half = 3 if y < ground else 2
            top = y < ground - 2
            for x in range(cx - half, cx + half + 1):
                t.px(x, y, RADISH_TOP if top else RADISH)
            t.px(cx + half, y, RADISH_TOP_D if top else RADISH_D)
            t.px(cx - half, y, RADISH_TOP_L if top else RADISH)
        t.px(cx + 1, ground - 1, RADISH_DD)
        t.px(cx - 1, ground + 1, RADISH_DD)
        radish_leaf(t, cx - 2, ground - 6, -1, 7)
        radish_leaf(t, cx + 2, ground - 6, 1, 7)
        radish_leaf(t, cx - 1, ground - 6, 0, 10)
        radish_leaf(t, cx + 1, ground - 6, 0, 9)
    return t


def sprout(t, cx, ground):
    """작물 공통 1단계: 둥근 떡잎 두 장"""
    for y in range(ground - 3, ground + 1):
        t.px(cx, y, LEAF_D)
    ellipse(t, cx - 2.5, ground - 4.5, 1.5, 1, LEAF)
    ellipse(t, cx + 2.5, ground - 5, 1.5, 1, LEAF_L)


def seed_mound(t, cx, ground, c=SEED):
    for x in range(cx - 3, cx + 3):
        t.px(x, ground, SOIL_L)
    t.px(cx - 1, ground - 1, c)
    t.px(cx + 1, ground - 1, c)


def potato(stage):
    """감자. 2 잎 덤불, 3 꽃 핀 덤불 + 흙 위로 드러난 감자 세 알."""
    t = Tile()
    cx, ground = 12, 18
    if stage == 0:
        seed_mound(t, cx, ground, POTATO_L)
    elif stage == 1:
        sprout(t, cx, ground)
    else:
        big = stage == 3
        ellipse(t, cx, ground - (5 if big else 3), 5 if big else 4, 4 if big else 3, POTATO_LEAF)
        ellipse(t, cx - 2, ground - (7 if big else 4), 2, 2, LEAF)
        ellipse(t, cx + 2, ground - (6 if big else 4), 2, 1.5, LEAF_L)
        if big:
            for fx, fy in ((cx - 3, ground - 9), (cx + 2, ground - 10), (cx + 4, ground - 7)):
                t.px(fx, fy, POTATO_FLOWER)
                t.px(fx, fy - 1, (250, 220, 120))
            for px_, py_ in ((cx - 5, ground), (cx + 1, ground + 1), (cx + 5, ground)):
                ellipse(t, px_, py_, 2, 1.5, POTATO)
                t.px(px_ + 1, py_ + 1, POTATO_D)
                t.px(px_ - 1, py_ - 1, POTATO_L)
    return t


def pepper(stage):
    """고추. 2 가는 줄기와 잎 + 흰 꽃, 3 빨간 고추가 주렁주렁 (따도 다시 열린다)."""
    t = Tile()
    cx, ground = 12, 19
    if stage == 0:
        seed_mound(t, cx, ground - 1, (240, 220, 150))
    elif stage == 1:
        sprout(t, cx, ground - 1)
    else:
        h = 13 if stage == 3 else 10
        for y in range(ground - h, ground + 1):
            t.px(cx, y, LEAF_D)
        for i, (dx, dy) in enumerate(((-3, 3), (3, 5), (-3, 7), (3, 9), (-2, 11), (2, 12))):
            if dy > h:
                continue
            ellipse(t, cx + dx, ground - dy, 1.5, 1, LEAF if i % 2 else LEAF_L)
        if stage == 2:
            t.px(cx - 2, ground - 9, (250, 250, 240))
            t.px(cx + 2, ground - 6, (250, 250, 240))
        else:
            # 잎 사이로 늘어진 빨간 고추 (잎보다 나중에 그려 가리지 않게)
            for dx, dy in ((-5, 6), (5, 8), (-5, 10), (4, 12), (1, 5)):
                x, y = cx + dx, ground - dy
                t.px(x, y - 1, PEPPER_G)
                t.px(x, y, PEPPER_L)
                t.px(x, y + 1, PEPPER)
                t.px(x + (1 if dx < 0 else -1), y + 1, PEPPER)
                t.px(x, y + 2, PEPPER_D)
    return t


def cabbage(stage):
    """배추. 2 벌어진 잎, 3 겹겹이 오므린 큰 배추."""
    t = Tile()
    cx, ground = 12, 18
    if stage == 0:
        seed_mound(t, cx, ground, (180, 140, 100))
    elif stage == 1:
        sprout(t, cx, ground)
    elif stage == 2:
        ellipse(t, cx - 3, ground - 3, 3, 2, CABBAGE_D)
        ellipse(t, cx + 3, ground - 3, 3, 2, CABBAGE)
        ellipse(t, cx, ground - 5, 2.5, 3, CABBAGE_L)
    else:
        ellipse(t, cx, ground - 4, 7, 5, CABBAGE_D)
        ellipse(t, cx, ground - 6, 5, 5, CABBAGE)
        ellipse(t, cx - 1, ground - 8, 3, 3, CABBAGE_L)
        ellipse(t, cx, ground - 10, 2, 1.5, CABBAGE_IN)
        for y in range(ground - 8, ground):
            t.px(cx + 3, y, CABBAGE_D)
        t.px(cx - 4, ground - 3, CABBAGE_L)
        t.px(cx + 5, ground - 2, CABBAGE_L)
        # 잎맥
        for y in range(ground - 6, ground - 1):
            t.px(cx - 3, y, CABBAGE_L)
            t.px(cx + 1, y + 1, CABBAGE_IN)
    return t


CROP_ROWS = [crop, potato, pepper, cabbage]


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
    img = Image.new("RGBA", (T * 4, T * len(CROP_ROWS)), (0, 0, 0, 0))
    for row, draw in enumerate(CROP_ROWS):
        for s in range(4):
            img.paste(draw(s).img, (s * T, row * T))
    outline(img, T)
    grade_p1(img)
    return img


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, img in (("farm_tiles", tileset()), ("crops", crops())):
        path = os.path.join(OUT_DIR, f"{name}.png")
        img.save(path)
        print(path)
