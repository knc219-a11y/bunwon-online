"""넓은 사냥터 바닥 그림 임시 생성기 (2026-09-28 사용자 선택 C. 화면보다 넓은 맵 + 카메라).

data/hunt_maps/<이름>.txt 의 칸 지도를 읽어 assets/hunt/<이름>_ground.png 를 만든다.
칸 지도가 원본이다 (게임은 막힘·여울 판정을 칸 지도로 한다). 그림은 칸 경계를 몇 px 흔들어 덜 네모나 보이게만 한다.
나무 · 사냥터 입구 · 마을 표지 · 웨이포인트는 게임이 따로 그린다 (앞뒤 가림 때문에).

칸 글자
  .  풀            ,  모래 (금사리는 사금이 반짝)
  ~  깊은 물 (못 들어감)   =  여울 (얕은 물, 걷기 느려짐)   o  징검다리 (물 위 돌, 사냥꾼만 건넘)
  R  바위 (막힘)   B  덤불 (막힘)   T  나무 (막힘, 게임이 감나무를 세움)
  S  사냥꾼이 들어오는 자리   E  아래 입구 (마을로)   N  위쪽 길 (다음 구역)
  W  웨이포인트   J  마을 표지   K  대장 자리   c  몬스터 자리
  S E N W K c 는 모래 위, J 는 풀 위.

실행: python3 tools/make_hunt_maps.py  (Pillow, numpy 필요)
"""
import glob
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
T = 24
tiles = np.array(Image.open(os.path.join(ROOT, "assets/tiles/farm_tiles.png")).convert("RGB")).astype(float)
## 금사리 풀빛 (Config.HUNT_ZONES ground_tint 와 같게)
GRASS_TINT = np.array([0.9, 0.86, 0.72])

PATH_D = np.array((188, 162, 124)); PATH_DD = np.array((160, 134, 104))
WET = np.array((176, 150, 116))
W_DEEP = np.array((92, 140, 176)); W_MID = np.array((120, 172, 200)); W_SHAL = np.array((150, 196, 206)); W_LIGHT = np.array((214, 236, 240))
GOLD = np.array((252, 222, 110)); GOLD_L = np.array((255, 246, 200))
ROCK = np.array((150, 144, 146)); ROCK_L = np.array((186, 180, 178)); ROCK_D = np.array((108, 100, 108))
BUSH = np.array((96, 150, 84)); BUSH_L = np.array((130, 180, 100)); BUSH_D = np.array((62, 108, 70))
REED = np.array((196, 176, 110)); REED_D = np.array((140, 150, 84))
SHADOW = np.array((70, 45, 85))

GRASS, SAND, DEEP, FORD = 0, 1, 2, 3
BASE = {".": GRASS, "T": GRASS, "J": GRASS, ",": SAND, "S": SAND, "E": SAND, "N": SAND, "W": SAND, "K": SAND, "c": SAND,
        "~": DEEP, "o": DEEP, "=": FORD}


def noise(w, h, cell, seed):
    rng = np.random.default_rng(seed)
    g = rng.random((h // cell + 2, w // cell + 2))
    ys, xs = np.arange(h) / cell, np.arange(w) / cell
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = (ys - y0)[:, None], (xs - x0)[None, :]
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a, b = g[y0][:, x0], g[y0][:, x0 + 1]
    c, d = g[y0 + 1][:, x0], g[y0 + 1][:, x0 + 1]
    return a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy


def tile_fill(w, h, pick):
    img = np.zeros((h, w, 3))
    for ty in range(h // T):
        for tx in range(w // T):
            v = pick(tx, ty)
            img[ty * T:ty * T + T, tx * T:tx * T + T] = tiles[0:T, v * T:v * T + T]
    return img


def shift(m, dy, dx):
    return np.roll(np.roll(m, dy, 0), dx, 1)


def ellipse(img, cx, cy, rx, ry, col, blend=1.0):
    h, w = img.shape[:2]
    y0, y1 = max(0, int(cy - ry - 1)), min(h, int(cy + ry + 2))
    x0, x1 = max(0, int(cx - rx - 1)), min(w, int(cx + rx + 2))
    yy, xx = np.mgrid[y0:y1, x0:x1] + 0.5
    m = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1
    sub = img[y0:y1, x0:x1]
    sub[m] = sub[m] * (1 - blend) + col * blend


def rock(img, cx, cy):
    ellipse(img, cx + 2, cy + 6, 12, 4, SHADOW, 0.28)
    ellipse(img, cx, cy, 11, 8, ROCK_D)
    ellipse(img, cx, cy - 1, 10, 7, ROCK)
    ellipse(img, cx - 3, cy - 3, 5, 3, ROCK_L)


def stone(img, cx, cy):
    ellipse(img, cx, cy + 1, 9, 5, ROCK_D)
    ellipse(img, cx, cy, 8, 4, ROCK)
    ellipse(img, cx - 2, cy - 1, 4, 2, ROCK_L)


def bush(img, cx, cy):
    ellipse(img, cx + 2, cy + 8, 15, 5, SHADOW, 0.28)
    parts = ((-7, 0, 8), (7, 1, 8), (0, -5, 9), (0, 3, 9))
    for dx, dy, r in parts:
        ellipse(img, cx + dx, cy + dy, r + 1, (r + 1) * 0.85, BUSH_D)
    for dx, dy, r in parts:
        ellipse(img, cx + dx, cy + dy, r - 1 + 1, r * 0.85, BUSH)
    for dx, dy in ((-3, -9), (5, -4), (-8, -3)):
        ellipse(img, cx + dx, cy + dy, 3, 2, BUSH_L)


def render(path):
    rows = [r.rstrip("\n") for r in open(path, encoding="utf-8") if r.strip()]
    cw, ch = len(rows[0]), len(rows)
    grid = np.array([list(r) for r in rows])
    base = np.zeros((ch, cw), int)
    for y in range(ch):
        for x in range(cw):
            k = grid[y, x]
            if k in BASE:
                base[y, x] = BASE[k]
            else:
                # 바위·덤불은 이웃 중 많은 쪽 바닥 위에
                ns = [BASE.get(grid[y + dy, x + dx], GRASS) for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))
                      if 0 <= y + dy < ch and 0 <= x + dx < cw]
                base[y, x] = SAND if ns.count(SAND) >= 2 else GRASS
    w, h = cw * T, ch * T
    # 칸 경계를 흔든다 (±8px). 판정은 칸 그대로라 몇 px 차이만 난다.
    nx = (noise(w, h, 14, 1) - 0.5) * 16
    ny = (noise(w, h, 14, 2) - 0.5) * 16
    yy, xx = np.mgrid[0:h, 0:w]
    sx = np.clip(((xx + nx) // T).astype(int), 0, cw - 1)
    sy = np.clip(((yy + ny) // T).astype(int), 0, ch - 1)
    kind = base[sy, sx]

    def grass_pick(tx, ty):
        return [0, 0, 0, 1, 1, 2, 3][abs((tx * 73856093) ^ (ty * 19349663)) % 7]

    img = tile_fill(w, h, grass_pick) * GRASS_TINT
    sand_img = tile_fill(w, h, lambda tx, ty: 4 + (tx * 7 + ty * 3) % 2)
    sand = kind == SAND
    img[sand] = sand_img[sand]
    img[sand & ~shift(sand, 1, 0) | sand & ~shift(sand, 0, 1)] = PATH_DD
    img[sand & ~shift(sand, -1, 0) | sand & ~shift(sand, 0, -1)] = PATH_D
    rng = np.random.default_rng(len(rows[0]) * 31 + ch)
    # 사금 반짝
    ys, xs = np.nonzero(sand)
    for i in rng.choice(len(ys), size=len(ys) // 900, replace=False):
        y, x = ys[i], xs[i]
        img[y, x] = GOLD_L
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            img[min(h - 1, y + dy), min(w - 1, x + dx)] = GOLD
    # 물: 가장자리에서 멀수록 깊은 색
    water = (kind == DEEP) | (kind == FORD)
    dist = np.zeros((h, w))
    ring = water.copy()
    for d in range(1, 12):
        ring = ring & shift(ring, 1, 0) & shift(ring, -1, 0) & shift(ring, 0, 1) & shift(ring, 0, -1)
        dist += ring
    wet = ~water & (shift(water, 3, 0) | shift(water, -3, 0) | shift(water, 0, 3) | shift(water, 0, -3))
    img[wet] = img[wet] * 0.55 + WET * 0.45
    img[water] = W_SHAL
    img[water & (dist >= 3)] = W_MID
    img[(kind == DEEP) & (dist >= 8)] = W_DEEP
    img[(kind == FORD) & (dist >= 3)] = W_SHAL * 0.6 + W_MID * 0.4
    ys, xs = np.nonzero(water & (dist >= 2))
    for i in rng.choice(len(ys), size=len(ys) // 90, replace=False):
        img[ys[i], xs[i]:xs[i] + 4] = W_LIGHT
    edge = water & ~shift(water, 1, 0)
    img[edge] = W_LIGHT * 0.5 + img[edge] * 0.5
    # 갈대: 깊은 물 칸 위쪽 가장자리 풀에 드문드문
    for y in range(1, ch):
        for x in range(cw):
            if grid[y, x] == "~" and grid[y - 1, x] == "." and rng.random() < 0.35:
                for px in range(x * T, x * T + T, 3):
                    hgt = int(rng.integers(8, 16))
                    yb = y * T + int(rng.integers(-2, 3))
                    img[max(0, yb - hgt):yb, px] = REED_D
                    img[max(0, yb - hgt - 3):max(0, yb - hgt), px] = REED
    for y in range(ch):
        for x in range(cw):
            cx, cy = x * T + 12, y * T + 12
            if grid[y, x] == "o":
                stone(img, cx, cy)
            elif grid[y, x] == "R":
                rock(img, cx, cy)
            elif grid[y, x] == "B":
                bush(img, cx, cy)
    name = os.path.splitext(os.path.basename(path))[0]
    out = os.path.join(ROOT, "assets", "hunt", name + "_ground.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(out)
    print(out, w, h)


for p in sorted(glob.glob(os.path.join(ROOT, "data", "hunt_maps", "*.txt"))):
    render(p)
