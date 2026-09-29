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
  S E N W 는 모래 위, J 는 풀 위, K c 는 이웃 칸 바닥 위.
  분원농협 (논·들판·창고 마당) · 광동리 (추수 벌판 · 짚가리 · 군량 곳간 H · 배수로 ~ 와 나무 다리 b)
  p  논 (물 댄 논, 사냥꾼 걷기 느려짐)   b  나무 다리 (물 위, 모두 건넘)
  x  추수한 논 그루터기   r  밭 이랑   %  콘크리트 마당   m  멍석 (벼 말리기)
  h  볏짚 더미 (막힘)   w  곤포 볏짚 (흰 비닐, 막힘)   s  쌀 포대 더미 (막힘)
  H  창고 (막힘, 칸 덩어리 하나가 창고 한 채)   F  철망 울타리 (막힘)
  도마리 (나무꾼 벌목터): G 장작 쌓인 비닐하우스 (막힘, 칸 덩어리 하나가 한 동)   l 장작더미 (막힘)   u 그루터기 (막힘)

실행: python3 tools/make_hunt_maps.py [지도.txt ...] [--out 폴더]  (Pillow, numpy 필요)
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
T = 24
tiles = np.array(Image.open(os.path.join(ROOT, "assets/tiles/farm_tiles.png")).convert("RGB")).astype(float)
## 구역 풀빛 (Config.HUNT_ZONES ground_tint 와 같게). 파일 이름 앞부분으로 고른다.
GRASS_TINTS = {"geumsa": np.array([0.9, 0.86, 0.72]), "nonghyup": np.array([0.82, 0.9, 0.8]), "gwangdong": np.array([0.92, 0.88, 0.74]), "doma": np.array([0.78, 0.86, 0.7])}

PATH_D = np.array((188, 162, 124)); PATH_DD = np.array((160, 134, 104))
WET = np.array((176, 150, 116))
W_DEEP = np.array((92, 140, 176)); W_MID = np.array((120, 172, 200)); W_SHAL = np.array((150, 196, 206)); W_LIGHT = np.array((214, 236, 240))
GOLD = np.array((252, 222, 110)); GOLD_L = np.array((255, 246, 200))
ROCK = np.array((150, 144, 146)); ROCK_L = np.array((186, 180, 178)); ROCK_D = np.array((108, 100, 108))
BUSH = np.array((96, 150, 84)); BUSH_L = np.array((130, 180, 100)); BUSH_D = np.array((62, 108, 70))
REED = np.array((196, 176, 110)); REED_D = np.array((140, 150, 84))
SHADOW = np.array((70, 45, 85))
PADDY = np.array((124, 166, 158)); PADDY_D = np.array((96, 130, 118)); RICE = np.array((96, 160, 72)); RICE_L = np.array((140, 196, 96))
STUB = np.array((214, 192, 142)); STUB_D = np.array((176, 146, 96))
FIELD = np.array((168, 128, 92)); FIELD_D = np.array((136, 100, 72)); LEAF = np.array((110, 168, 90))
CONC = np.array((204, 202, 194)); CONC_D = np.array((176, 174, 168))
MAT = np.array((196, 162, 104)); MAT_D = np.array((168, 134, 84)); GRAIN = np.array((240, 208, 110))
STRAW = np.array((226, 194, 112)); STRAW_D = np.array((184, 148, 80)); STRAW_L = np.array((246, 222, 150))
WRAP = np.array((238, 238, 232)); WRAP_D = np.array((196, 200, 206))
SACK = np.array((236, 228, 204)); SACK_D = np.array((196, 184, 156)); SACK_BAND = np.array((112, 150, 196))
PALLET = np.array((164, 124, 86))
ROOF = np.array((138, 156, 176)); ROOF_D = np.array((112, 128, 150)); ROOF_L = np.array((168, 184, 200))
WALL = np.array((232, 224, 204)); WALL_D = np.array((196, 186, 164)); DOOR = np.array((116, 104, 100)); DOOR_L = np.array((140, 128, 122))
PLANK = np.array((176, 136, 94)); PLANK_D = np.array((136, 100, 70))
POST = np.array((120, 120, 126)); MESH = np.array((150, 152, 160))

GRASS, SAND, DEEP, FORD, PADDY_K, STUB_K, FIELD_K, CONC_K, MAT_K = range(9)
BASE = {".": GRASS, "T": GRASS, "J": GRASS, ",": SAND, "S": SAND, "E": SAND, "N": SAND, "W": SAND,
        "~": DEEP, "o": DEEP, "b": DEEP, "=": FORD,
        "p": PADDY_K, "x": STUB_K, "r": FIELD_K, "%": CONC_K, "H": CONC_K, "m": MAT_K}


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


def rect(img, x0, y0, x1, y1, col, blend=1.0):
    h, w = img.shape[:2]
    x0, y0, x1, y1 = max(0, int(x0)), max(0, int(y0)), min(w, int(x1)), min(h, int(y1))
    if x1 > x0 and y1 > y0:
        img[y0:y1, x0:x1] = img[y0:y1, x0:x1] * (1 - blend) + col * blend


def bridge(img, x, y, grid):
    # 나무 다리: 물을 위아래로 건너면 가로 널, 좌우로 건너면 세로 널
    vertical = grid[y - 1, x] not in "~b" or grid[y + 1, x] not in "~b" if 0 < y < len(grid) - 1 else True
    x0, y0 = x * T, y * T
    rect(img, x0, y0, x0 + T, y0 + T, PLANK)
    for i in range(0, T, 6):
        if vertical:
            rect(img, x0, y0 + i, x0 + T, y0 + i + 1, PLANK_D)
        else:
            rect(img, x0 + i, y0, x0 + i + 1, y0 + T, PLANK_D)
    if vertical:
        rect(img, x0, y0, x0 + 2, y0 + T, PLANK_D)
        rect(img, x0 + T - 2, y0, x0 + T, y0 + T, PLANK_D)


def mat(img, x, y):
    # 멍석 위에 벼를 펴 말린다
    x0, y0 = x * T + 1, y * T + 1
    rect(img, x0, y0, x0 + T - 2, y0 + T - 2, MAT)
    for i in range(0, T - 2, 4):
        rect(img, x0 + i, y0, x0 + i + 1, y0 + T - 2, MAT_D)
    rng = np.random.default_rng(x * 131 + y)
    for _ in range(40):
        px, py = x0 + 2 + int(rng.integers(0, T - 6)), y0 + 2 + int(rng.integers(0, T - 6))
        rect(img, px, py, px + 2, py + 1, GRAIN)


def fence(img, x, y, grid):
    # 철망 울타리: 기둥 + 가는 그물
    x0, y0 = x * T, y * T + 6
    rect(img, x0, y0 + 14, x0 + T, y0 + 17, SHADOW, 0.2)
    for i in range(0, T, 4):
        rect(img, x0 + i, y0, x0 + i + 1, y0 + 14, MESH, 0.8)
    rect(img, x0, y0 + 1, x0 + T, y0 + 2, MESH)
    rect(img, x0, y0 + 12, x0 + T, y0 + 13, MESH)
    rect(img, x0 + 10, y0 - 3, x0 + 13, y0 + 15, POST)


def haystack(img, cx, cy, rng):
    # 볏짚 더미 (짚가리): 둥근 지붕 모양
    ellipse(img, cx + 2, cy + 8, 13, 4, SHADOW, 0.3)
    ellipse(img, cx, cy + 1, 12, 10, STRAW_D)
    ellipse(img, cx, cy, 11, 9, STRAW)
    ellipse(img, cx - 3, cy - 4, 5, 3, STRAW_L)
    for i in range(6):
        px = cx - 8 + int(rng.integers(0, 16))
        rect(img, px, cy - 2 + int(rng.integers(0, 6)), px + 1, cy + 6, STRAW_D)


def wrapped(img, cx, cy):
    # 곤포 볏짚: 흰 비닐로 싼 원통을 눕혀 놓음
    ellipse(img, cx + 2, cy + 8, 13, 4, SHADOW, 0.3)
    rect(img, cx - 10, cy - 7, cx + 10, cy + 7, WRAP)
    rect(img, cx - 10, cy + 3, cx + 10, cy + 7, WRAP_D)
    ellipse(img, cx + 10, cy, 4, 7, WRAP_D)
    ellipse(img, cx - 10, cy, 4, 7, WRAP)
    ellipse(img, cx - 10, cy, 2, 4, WRAP_D)


def sacks(img, cx, cy):
    # 쌀 포대 더미: 나무 팔레트 위에 포대 여러 개
    rect(img, cx - 12, cy + 5, cx + 12, cy + 10, PALLET)
    for dx, dy in ((-6, 2), (6, 2), (0, -5)):
        ellipse(img, cx + dx, cy + dy + 1, 7, 5, SACK_D)
        ellipse(img, cx + dx, cy + dy, 6, 4, SACK)
        rect(img, cx + dx - 5, cy + dy, cx + dx + 5, cy + dy + 1, SACK_BAND)


def blocks(grid, ch):
    """같은 글자 칸 덩어리들의 (x0, y0, x1, y1) 칸 상자."""
    seen = set()
    out = []
    hh, ww = grid.shape
    for y in range(hh):
        for x in range(ww):
            if grid[y, x] != ch or (x, y) in seen:
                continue
            stack, cells = [(x, y)], []
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                cells.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < ww and 0 <= ny < hh and grid[ny, nx] == ch and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            xs = [c[0] for c in cells]; ys = [c[1] for c in cells]
            out.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    return out


def warehouse(img, x0, y0, x1, y1):
    # 창고 (3/4 시점): 위쪽은 골함석 지붕, 아래 두 칸은 벽과 큰 미닫이문
    X0, Y0, X1, Y1 = x0 * T, y0 * T, x1 * T, y1 * T
    wall = Y1 - 2 * T
    rect(img, X0 + 4, Y1 - 2, X1 + 6, Y1 + 5, SHADOW, 0.3)
    rect(img, X0, Y0, X1, wall, ROOF)
    for x in range(X0, X1, 6):
        rect(img, x, Y0, x + 2, wall, ROOF_D)
        rect(img, x + 3, Y0, x + 4, wall, ROOF_L)
    rect(img, X0, (Y0 + wall) // 2, X1, (Y0 + wall) // 2 + 2, ROOF_L)
    rect(img, X0 - 2, wall - 3, X1 + 2, wall + 1, ROOF_D)
    rect(img, X0, wall + 1, X1, Y1, WALL)
    rect(img, X0, Y1 - 4, X1, Y1, WALL_D)
    mid = (X0 + X1) // 2
    dw = min(2 * T, (X1 - X0) // 3)
    rect(img, mid - dw, wall + 10, mid + dw, Y1, DOOR)
    for x in range(mid - dw, mid + dw, 8):
        rect(img, x, wall + 10, x + 1, Y1, DOOR_L)
    rect(img, mid - 1, wall + 10, mid + 1, Y1, WALL_D)


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
                # 바위·덤불·몬스터 자리는 이웃 중 많은 쪽 바닥 위에 (물·다리는 빼고)
                ns = [BASE[grid[y + dy, x + dx]] for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))
                      if 0 <= y + dy < ch and 0 <= x + dx < cw and grid[y + dy, x + dx] in BASE
                      and BASE[grid[y + dy, x + dx]] not in (DEEP, FORD)]
                rest = [n for n in ns if n != SAND]
                base[y, x] = SAND if ns.count(SAND) >= 2 else (max(set(rest), key=rest.count) if rest else GRASS)
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

    name = os.path.splitext(os.path.basename(path))[0]
    img = tile_fill(w, h, grass_pick) * GRASS_TINTS.get(name.split("_")[0], GRASS_TINTS["geumsa"])
    rng0 = np.random.default_rng(7)
    fine = noise(w, h, 3, 5)
    # 분원농협 바닥: 콘크리트 · 밭 · 그루터기 · 논 · 멍석
    conc = (kind == CONC_K) | (kind == MAT_K)
    img[conc] = CONC * (0.94 + 0.08 * fine[conc, None])
    img[conc & (((xx % 48) == 0) | ((yy % 48) == 0))] = CONC_D
    field = kind == FIELD_K
    stripe = ((yy // 4) % 3 == 0)
    img[field] = FIELD
    img[field & stripe] = FIELD_D
    img[field & ((yy % 12) == 5) & ((xx % 8) < 3)] = LEAF
    stub = kind == STUB_K
    img[stub] = STUB * (0.95 + 0.08 * fine[stub, None])
    img[stub & ((yy % 6) < 2) & (((xx + (yy // 6) * 3) % 5) == 0)] = STUB_D
    paddy = kind == PADDY_K
    img[paddy] = PADDY * (0.95 + 0.08 * fine[paddy, None])
    img[paddy & ((yy % 8) < 3) & ((xx % 8) == 3)] = RICE
    img[paddy & ((yy % 8) == 0) & ((xx % 8) == 3)] = RICE_L
    # 논둑 그림자: 논 위쪽 가장자리는 어둡게 (둑이 솟아 보이게)
    pe = paddy & ~shift(paddy, 2, 0)
    img[pe] = PADDY_D
    img[paddy & ~shift(paddy, -1, 0)] = PADDY_D * 0.9 + PADDY * 0.1
    sand_img = tile_fill(w, h, lambda tx, ty: 4 + (tx * 7 + ty * 3) % 2)
    sand = kind == SAND
    img[sand] = sand_img[sand]
    sparkle = name.startswith("geumsa")
    img[sand & ~shift(sand, 1, 0) | sand & ~shift(sand, 0, 1)] = PATH_DD
    img[sand & ~shift(sand, -1, 0) | sand & ~shift(sand, 0, -1)] = PATH_D
    rng = np.random.default_rng(len(rows[0]) * 31 + ch)
    # 사금 반짝 (금사리만)
    ys, xs = np.nonzero(sand)
    for i in rng.choice(len(ys), size=len(ys) // 900 if sparkle else 0, replace=False):
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
            k = grid[y, x]
            if k == "o":
                stone(img, cx, cy)
            elif k == "R":
                rock(img, cx, cy)
            elif k == "B":
                bush(img, cx, cy)
            elif k == "b":
                bridge(img, x, y, grid)
            elif k == "m":
                mat(img, x, y)
            elif k == "F":
                fence(img, x, y, grid)
            elif k == "h":
                haystack(img, cx, cy, rng)
            elif k == "w":
                wrapped(img, cx, cy)
            elif k == "s":
                sacks(img, cx, cy)
            elif k == "l":
                log_pile(img, cx, cy)
            elif k == "u":
                tree_stump(img, cx, cy)
    for box in blocks(grid, "G"):
        vinyl_house(img, *box)
    for box in blocks(grid, "H"):
        warehouse(img, *box)
    out = os.path.join(OUT or os.path.join(ROOT, "assets", "hunt"), name + "_ground.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(out)
    print(out, w, h)


def vinyl_house(img, x0, y0, x1, y1):
    """도마리: 장작을 쌓아 둔 비닐하우스 (칸 덩어리 하나 = 한 동). 위는 둥근 비닐 지붕, 아래 앞면은 열려서 장작 단면이 보임."""
    X0, Y0, X1, Y1 = x0 * T, y0 * T, (x1 + 1) * T, (y1 + 1) * T
    front = Y1 - 30
    roof = img[Y0:front, X0:X1]
    roof[:] = roof * 0.25 + np.array((232, 238, 236)) * 0.75
    for xx in range(X0 + 6, X1, 12):
        img[Y0:front, xx] = (150, 156, 160)
    hh = front - Y0
    for i in range(hh):
        sh = 0.82 + 0.3 * np.sin(i / hh * np.pi)
        img[Y0 + i, X0:X1] = img[Y0 + i, X0:X1] * min(sh, 1.08)
    img[Y0:Y0 + 2, X0:X1] = (170, 176, 180)
    img[front:Y1, X0:X1] = (70, 56, 46)
    for cy in range(front + 5, Y1 - 2, 8):
        for cx in range(X0 + 5 + (cy // 8 % 2) * 4, X1 - 4, 8):
            for dy in range(-3, 4):
                for dx in range(-3, 4):
                    if dx * dx + dy * dy <= 10:
                        img[cy + dy, cx + dx] = (214, 184, 134) if dx * dx + dy * dy <= 3 else (150, 108, 72)
    img[front:Y1, X0:X0 + 3] = (150, 156, 160)
    img[front:Y1, X1 - 3:X1] = (150, 156, 160)
    img[front - 2:front, X0:X1] = (120, 126, 130)


def log_pile(img, cx, cy):
    for i, (dx, dy) in enumerate(((-6, 4), (0, 4), (6, 4), (-3, -2), (3, -2), (0, -8))):
        for yy in range(-3, 4):
            for xx in range(-3, 4):
                if xx * xx + yy * yy <= 10:
                    img[cy + dy + yy, cx + dx + xx] = (214, 184, 134) if xx * xx + yy * yy <= 3 else (140, 100, 66)


def tree_stump(img, cx, cy):
    for yy in range(-5, 6):
        for xx in range(-7, 8):
            if (xx / 7) ** 2 + (yy / 4) ** 2 <= 1:
                img[cy + yy + 3, cx + xx] = (110, 80, 56)
    for yy in range(-3, 4):
        for xx in range(-6, 7):
            if (xx / 6) ** 2 + (yy / 3) ** 2 <= 1:
                img[cy + yy, cx + xx] = (222, 196, 150) if (xx / 6) ** 2 + (yy / 3) ** 2 > 0.3 else (186, 150, 108)


args = sys.argv[1:]
OUT = None
if "--out" in args:
    i = args.index("--out")
    OUT = args[i + 1]
    del args[i:i + 2]
for p in args or sorted(glob.glob(os.path.join(ROOT, "data", "hunt_maps", "*.txt"))):
    render(p)
