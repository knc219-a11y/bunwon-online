"""입는 장비 임시 덧그림 시트 생성기.

캐릭터 시트(assets/characters/*.png)와 같은 규격(288x144, 칸 48x48, 열 0-1 대기 · 2-5 걷기,
행 0 아래 · 1 위 · 2 옆)의 투명 PNG를 만든다. 게임은 캐릭터 그림 위에 같은 칸을 겹쳐 그린다.
코드로 그린 임시 그림이다. 최종 아트는 같은 규격 PNG로 파일만 바꾸면 된다.
마을에서 사는 물건은 현대풍, 사냥터에서 떨어지는 숲 공터 세트는 판타지풍 (2026-09-27 사용자 방향: 제작·마을 물건 현대풍, 사냥터 완제품 판타지풍).

실행: python3 tools/make_wear_sheets.py  (Pillow 필요)
"""
import os

from PIL import Image

from make_character_sheet import CELL, COLS, ROWS, IDLE, WALK, HOODIES, SK, SK_D, Canvas, outline, grade_p1, side_arm

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "wear")
KINDS = ["contact_a", "pass_a", "contact_b", "pass_b"]
# make_character_sheet.side_legs 와 같은 값: (엉덩이 x, 발 x, 들림)
SIDE_NEAR = dict(idle=(23, 23, 0), contact_a=(23, 28, 0), pass_a=(23, 23, 0), contact_b=(21, 15, 0), pass_b=(22, 24, 2))
SIDE_FAR = dict(idle=(20, 19, 0), contact_a=(20, 14, 0), pass_a=(21, 22, 2), contact_b=(22, 27, 0), pass_b=(20, 20, 0))

STRAW, STRAW_D, STRAW_L, BAND = (232, 200, 120), (196, 160, 90), (246, 224, 160), (190, 70, 60)
CAP, CAP_D, CAP_L = (70, 96, 150), (50, 70, 116), (104, 132, 184)
RUBBER, RUBBER_D, RUBBER_L = (64, 120, 84), (44, 90, 62), (96, 156, 112)
VEST, VEST_D, VEST_L = (150, 136, 92), (118, 104, 70), (178, 166, 120)
SEED = (120, 84, 52)
HIKE, HIKE_D, LACE = (132, 92, 60), (96, 64, 42), (232, 140, 60)
# 숲 공터 세트 (사냥터 드롭, 판타지풍)
ACORN, ACORN_D, ACORN_L, CUPULE = (170, 116, 64), (132, 86, 46), (204, 150, 96), (110, 78, 48)
CAPE, CAPE_D, CAPE_L, CLASP = (70, 132, 84), (50, 100, 62), (104, 164, 110), (236, 200, 90)
FEATHER_B, FEATHER_B_D, FEATHER = (112, 128, 176), (84, 96, 140), (246, 246, 240)
# 사냥터 기본 장비 (등급·옵션이 붙는 바탕, 판타지풍 가죽)
LEATHER, LEATHER_D, LEATHER_L, STITCH = (150, 104, 70), (112, 76, 50), (184, 138, 98), (226, 196, 140)


# ---------- 모자 ----------
def straw_hat(c, row, b):
    if row == 2:
        c.ellipse(7, 6 + b, 41, 10 + b, STRAW_D)
        c.ellipse(8, 6 + b, 40, 9 + b, STRAW)
        c.ellipse(13, 0 + b, 32, 8 + b, STRAW)
        c.rect(13, 5 + b, 32, 6 + b, BAND)
        c.rect(15, 1 + b, 20, 2 + b, STRAW_L)
    else:
        c.ellipse(5, 6 + b, 42, 11 + b, STRAW_D)
        c.ellipse(6, 6 + b, 41, 10 + b, STRAW)
        c.ellipse(13, 0 + b, 34, 8 + b, STRAW)
        c.rect(13, 5 + b, 34, 6 + b, BAND if row == 0 else STRAW_D)
        c.rect(16, 1 + b, 22, 2 + b, STRAW_L)


def cap(c, row, b):
    c.ellipse(11, 0 + b, 36, 12 + b, CAP)
    c.ellipse(28, 1 + b, 36, 11 + b, CAP_D)
    c.rect(16, 2 + b, 20, 3 + b, CAP_L)
    if row == 0:
        c.ellipse(14, 8 + b, 33, 12 + b, CAP_D)  # 챙
    elif row == 1:
        c.rect(19, 9 + b, 28, 10 + b, CAP_D)  # 뒤 조절끈
    else:
        c.rect(30, 8 + b, 41, 10 + b, CAP_D)
        c.rect(31, 8 + b, 40, 8 + b, CAP)


def acorn_helm(c, row, b):
    # 도토리 투구: 반들한 몸통 위에 오톨도톨한 깍정이, 꼭지
    c.ellipse(11, 1 + b, 36, 14 + b, ACORN)
    c.ellipse(28, 2 + b, 36, 13 + b, ACORN_D)
    c.ellipse(10, -1 + b, 37, 8 + b, CUPULE)
    for x in range(12, 36, 3):
        c.px(x, 3 + b, ACORN_D)
        c.px(x + 1, 5 + b, ACORN_D)
    c.rect(22, -4 + b, 24, -1 + b, CUPULE)
    if row == 0:
        c.rect(12, 9 + b, 35, 10 + b, ACORN_D)  # 이마 테
        c.rect(15, 11 + b, 17, 12 + b, ACORN_L)
    elif row == 2:
        c.rect(12, 9 + b, 20, 12 + b, ACORN)  # 뒤통수 덮개
    else:
        c.rect(12, 9 + b, 35, 13 + b, ACORN)


def leather_hood(c, row, b):
    # 가죽 두건: 머리를 감싸고 뒤로 늘어지는 천
    c.ellipse(10, 0 + b, 37, 13 + b, LEATHER)
    c.ellipse(29, 1 + b, 37, 12 + b, LEATHER_D)
    c.rect(15, 2 + b, 19, 3 + b, LEATHER_L)
    if row == 0:
        c.rect(12, 9 + b, 35, 10 + b, LEATHER_D)
        for x in range(13, 35, 3):
            c.px(x, 9 + b, STITCH)
    elif row == 1:
        c.rect(14, 9 + b, 33, 16 + b, LEATHER)  # 뒤로 늘어진 천
        c.rect(30, 9 + b, 33, 16 + b, LEATHER_D)
    else:
        c.rect(10, 8 + b, 17, 16 + b, LEATHER)
        c.rect(10, 8 + b, 11, 16 + b, LEATHER_D)


# ---------- 옷 ----------
def cape(c, row, b, swing):
    # 숲지기 망토: 앞에서는 어깨 양옆과 금 브로치, 뒤에서는 등 전체, 옆에서는 등 뒤로 늘어짐
    if row == 1:
        c.rect(15, 21 + b, 32, 38 + b, CAPE)
        c.rect(29, 21 + b, 32, 38 + b, CAPE_D)
        c.rect(16, 22 + b, 17, 34 + b, CAPE_L)
        for x in range(15, 33, 4):
            c.rect(x, 38 + b, x + 1, 39 + b, CAPE_D)  # 잎 모양 끝단
        return
    if row == 2:
        c.rect(12, 21 + b, 18, 37 + b + max(0, swing // 2), CAPE)
        c.rect(12, 21 + b, 13, 37 + b, CAPE_D)
        c.rect(17, 21 + b, 19, 23 + b, CLASP)
        return
    c.rect(13, 21 + b, 16, 37 + b, CAPE)
    c.rect(31, 21 + b, 34, 37 + b, CAPE_D)
    c.rect(16, 21 + b, 31, 22 + b, CAPE)  # 어깨 덮개
    c.rect(22, 22 + b, 25, 24 + b, CLASP)



def vest(c, row, b, swing):
    if row == 2:
        c.rect(18, 22 + b, 29, 34 + b, VEST)
        c.rect(18, 22 + b, 20, 34 + b, VEST_D)
        c.rect(25, 28 + b, 29, 32 + b, VEST_D)  # 씨앗 주머니
        c.rect(26, 29 + b, 28, 31 + b, SEED)
        hd = HOODIES["player"]
        side_arm(c, b, -swing, hd[2], SK, hd[1])  # 가까운 팔은 조끼 위
        return
    c.rect(16, 22 + b, 31, 34 + b, VEST)
    c.rect(28, 22 + b, 31, 34 + b, VEST_D)
    c.rect(17, 23 + b, 18, 30 + b, VEST_L)
    if row == 0:
        c.rect(22, 22 + b, 25, 34 + b, (0, 0, 0, 0))  # 앞섶이 열려 후드티가 보임
        for x0 in (17, 26):
            c.rect(x0, 28 + b, x0 + 4, 32 + b, VEST_D)
            c.rect(x0 + 1, 29 + b, x0 + 3, 31 + b, SEED)
    else:
        c.rect(18, 25 + b, 29, 25 + b, VEST_D)


def jerkin(c, row, b, swing):
    # 사냥꾼 가죽 조끼: 앞을 끈으로 여민다
    if row == 2:
        c.rect(18, 22 + b, 29, 35 + b, LEATHER)
        c.rect(18, 22 + b, 20, 35 + b, LEATHER_D)
        hd = HOODIES["hunter"]
        side_arm(c, b, -swing, hd[2], SK, hd[1])
        return
    c.rect(16, 22 + b, 31, 35 + b, LEATHER)
    c.rect(28, 22 + b, 31, 35 + b, LEATHER_D)
    c.rect(17, 23 + b, 18, 31 + b, LEATHER_L)
    c.rect(16, 33 + b, 31, 33 + b, LEATHER_D)  # 허리띠
    if row == 0:
        for y in range(24, 33, 3):
            c.rect(22, y + b, 25, y + b, STITCH)


# ---------- 신발 ----------
def front_feet(c, pose, draw):
    for side, lift in (("l", pose["l"]), ("r", pose["r"])):
        x0 = 17 if side == "l" else 25
        bottom = 43 - lift
        sx = x0 - 1 if side == "l" else x0
        draw(c, sx, bottom)


def side_feet(c, kind, draw):
    for hip_x, foot_x, lift in (SIDE_FAR[kind], SIDE_NEAR[kind]):
        top, bottom = 36, 43 - lift
        draw(c, foot_x - 1, bottom, hip_x=hip_x, top=top, side=True)


def rubber_boot(c, sx, bottom, hip_x=None, top=None, side=False):
    shaft = bottom - 4
    if side:
        for y in range(shaft, bottom + 1):
            t = (y - top) / max(1, bottom - top)
            x = round(hip_x + (sx + 1 - hip_x) * t)
            c.rect(x - 1, y, x + 5, y, RUBBER)
        c.rect(sx, bottom + 1, sx + 7, bottom + 4, RUBBER)
        c.rect(sx, bottom + 4, sx + 7, bottom + 4, RUBBER_D)
        return
    c.rect(sx, shaft, sx + 6, bottom + 4, RUBBER)
    c.rect(sx, shaft, sx + 6, shaft, RUBBER_L)
    c.rect(sx + 5, shaft + 1, sx + 6, bottom + 4, RUBBER_D)
    c.rect(sx, bottom + 4, sx + 6, bottom + 4, RUBBER_D)


def hiking_shoe(c, sx, bottom, side=False, **_):
    w = 7 if side else 6
    c.rect(sx, bottom, sx + w, bottom + 4, HIKE)
    c.rect(sx, bottom + 4, sx + w, bottom + 4, HIKE_D)
    c.rect(sx + 2, bottom + 1, sx + 3, bottom + 1, LACE)
    c.rect(sx + 2, bottom + 3, sx + 3, bottom + 3, LACE)


def feather_boot(c, sx, bottom, hip_x=None, top=None, side=False):
    shaft = bottom - 5
    if side:
        c.rect(sx, shaft, sx + 5, bottom + 4, FEATHER_B)
        c.rect(sx, bottom + 1, sx + 7, bottom + 4, FEATHER_B)
        c.rect(sx, bottom + 4, sx + 7, bottom + 4, FEATHER_B_D)
        c.rect(sx - 2, shaft - 2, sx, shaft + 1, FEATHER)  # 뒤꿈치 깃털
        return
    c.rect(sx, shaft, sx + 6, bottom + 4, FEATHER_B)
    c.rect(sx + 5, shaft, sx + 6, bottom + 4, FEATHER_B_D)
    c.rect(sx, bottom + 4, sx + 6, bottom + 4, FEATHER_B_D)
    c.rect(sx, shaft - 1, sx + 6, shaft, FEATHER)  # 깃털 테
    c.px(sx + 1, shaft - 2, FEATHER)
    c.px(sx + 4, shaft - 2, FEATHER)


def leather_shoe(c, sx, bottom, hip_x=None, top=None, side=False):
    w = 7 if side else 6
    c.rect(sx, bottom - 1, sx + w, bottom + 4, LEATHER)
    c.rect(sx, bottom - 1, sx + w, bottom - 1, LEATHER_L)
    c.rect(sx, bottom + 4, sx + w, bottom + 4, LEATHER_D)
    c.px(sx + 2, bottom + 1, STITCH)


# ---------- 대장간 제작품 (2026-09-29 사용자 선택 A, 현대풍) ----------
# 있는 그림을 색만 바꿔 쓰고, 안전모만 새로 그린다. 전부 임시.
HARD, HARD_D, HARD_L = (244, 204, 70), (206, 160, 50), (252, 232, 150)


def hard_hat(c, row, b):
    # 노란 안전모: 둥근 머리통 + 가운데 볼록 줄 + 둘레 챙
    c.ellipse(11, 0 + b, 36, 13 + b, HARD)
    c.ellipse(29, 1 + b, 36, 12 + b, HARD_D)
    c.rect(22, 0 + b, 25, 9 + b, HARD_L)
    if row == 2:
        c.rect(8, 9 + b, 39, 11 + b, HARD_D)
    else:
        c.rect(9, 9 + b, 38, 11 + b, HARD_D)
        c.rect(10, 9 + b, 37, 9 + b, HARD)


class Recolor:
    """그리는 색을 바꿔 주는 Canvas 감싸개 (있는 그림을 다른 색 제작품으로)"""

    def __init__(self, c, mapping):
        self.c, self.m = c, mapping

    def _col(self, col):
        return self.m.get(tuple(col[:3]), col) if len(col) == 3 or col[3] else col

    def rect(self, x0, y0, x1, y1, col):
        self.c.rect(x0, y0, x1, y1, self._col(col))

    def px(self, x, y, col):
        self.c.px(x, y, self._col(col))

    def ellipse(self, x0, y0, x1, y1, col):
        self.c.ellipse(x0, y0, x1, y1, self._col(col))


def recolored(fn, mapping):
    return lambda c, row, p, k: fn(Recolor(c, mapping), row, p, k)


def make(name, draw_fn):
    img = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for row in range(ROWS):
        frames = [(i, p, "idle") for i, p in enumerate(IDLE)] + [(2 + i, p, KINDS[i]) for i, p in enumerate(WALK)]
        for col, pose, kind in frames:
            c = Canvas(img, col * CELL, row * CELL)
            draw_fn(c, row, pose, kind)
    outline(img)
    grade_p1(img)
    path = os.path.join(OUT_DIR, f"{name}.png")
    img.save(path)
    return path


def feet_fn(draw):
    def fn(c, row, pose, kind):
        if row == 2:
            side_feet(c, kind, draw)
        else:
            front_feet(c, pose, draw)
    return fn


ITEMS = {
    "straw_hat": lambda c, row, p, k: straw_hat(c, row, p["b"]),
    "seed_vest": lambda c, row, p, k: vest(c, row, p["b"], p["swing"]),
    "rain_boots": feet_fn(rubber_boot),
    "ball_cap": lambda c, row, p, k: cap(c, row, p["b"]),
    "hiking_shoes": feet_fn(hiking_shoe),
    "acorn_helm": lambda c, row, p, k: acorn_helm(c, row, p["b"]),
    "forest_cape": lambda c, row, p, k: cape(c, row, p["b"], p["swing"]),
    "feather_boots": feet_fn(feather_boot),
    "leather_hood": lambda c, row, p, k: leather_hood(c, row, p["b"]),
    "hunter_jerkin": lambda c, row, p, k: jerkin(c, row, p["b"], p["swing"]),
    "leather_shoes": feet_fn(leather_shoe),
    # 대장간 제작품 (현대풍)
    "work_cap": recolored(lambda c, row, p, k: cap(c, row, p["b"]), {CAP: (236, 236, 226), CAP_D: (70, 140, 90), CAP_L: (250, 250, 244)}),
    "rain_suit": recolored(lambda c, row, p, k: vest(c, row, p["b"], p["swing"]), {VEST: (70, 92, 132), VEST_D: (50, 66, 100), VEST_L: (100, 126, 166), SEED: (236, 214, 80)}),
    "work_boots": recolored(feet_fn(rubber_boot), {RUBBER: (62, 62, 72), RUBBER_D: (40, 40, 48), RUBBER_L: (232, 196, 70)}),
    "hard_hat": lambda c, row, p, k: hard_hat(c, row, p["b"]),
    "hiking_vest": recolored(lambda c, row, p, k: jerkin(c, row, p["b"], p["swing"]), {LEATHER: (224, 112, 70), LEATHER_D: (172, 80, 56), LEATHER_L: (244, 152, 112), STITCH: (250, 240, 220)}),
    "safety_shoes": recolored(feet_fn(hiking_shoe), {HIKE: (72, 72, 82), HIKE_D: (44, 44, 52), LACE: (204, 208, 216)}),
}

# ---------- AI 그림 몸에 맞추기 (tools/import_ai_character.py 가 만든 부위 지도를 따른다) ----------
# 부위 지도(tools/char_parts/<몸>.png)가 있는 캐릭터의 장비는 아래 방식으로 새 몸에 맞춘다.
#   모자: 위 모자 그림을 옛 머리(가로 11-36, 머리끝 y=1) 기준에서 새 머리카락 상자로 옮기고 늘려 그린다.
#   옷 · 신발: 새 몸의 옷 · 신발 픽셀을 장비 색으로 다시 칠한다 (밝기 순서를 지켜 음영이 그대로 산다).
BODY_OF = {"farmer": "player"}  # 누가 입는지 → 몸 시트 이름 (사냥꾼은 아직 옛 몸이라 위 그림 그대로)
PARTS_DIR = os.path.join(os.path.dirname(__file__), "char_parts")
PART = {"hair": (40, 40, 40), "skin": (250, 200, 160), "top": (160, 160, 160), "pants": (70, 100, 200),
        "shoes": (120, 60, 20), "detail": (255, 255, 255)}  # import_ai_character.PART_COLORS 와 같음
OLD_HEAD_X0, OLD_HEAD_X1, OLD_HEAD_TOP = 11, 36, 1


class Warp:
    """옛 몸 좌표로 그리는 모자 함수를 새 머리 위치 · 크기로 옮겨 그리는 Canvas 감싸개"""

    def __init__(self, c, ox, oy, sx, sy):
        self.c, self.ox, self.oy, self.sx, self.sy = c, ox, oy, sx, sy

    def _x(self, x):
        return self.ox + (x - OLD_HEAD_X0) * self.sx

    def _y(self, y):
        return self.oy + (y - OLD_HEAD_TOP) * self.sy

    def rect(self, x0, y0, x1, y1, col):
        self.c.rect(round(self._x(x0)), round(self._y(y0)), max(round(self._x(x0)), round(self._x(x1 + 1)) - 1),
                    max(round(self._y(y0)), round(self._y(y1 + 1)) - 1), col)

    def px(self, x, y, col):
        self.c.px(round(self._x(x)), round(self._y(y)), col)

    def ellipse(self, x0, y0, x1, y1, col):
        self.c.ellipse(round(self._x(x0)), round(self._y(y0)), round(self._x(x1 + 1)) - 1, round(self._y(y1 + 1)) - 1, col)


def cell_parts(parts, row, col):
    """칸 하나의 부위별 픽셀 집합 {부위: {(x, y)}} 와 테두리 픽셀"""
    out, edge = {k: set() for k in PART}, set()
    p = parts.load()
    for y in range(CELL):
        for x in range(CELL):
            v = p[col * CELL + x, row * CELL + y]
            if not v[3]:
                continue
            for k, pc in PART.items():
                if v[:3] == pc:
                    out[k].add((x, y))
            if v[3] == 254:
                edge.add((x, y))
    return out, edge


def bbox(pts):
    xs, ys = [x for x, _ in pts], [y for _, y in pts]
    return min(xs), min(ys), max(xs), max(ys)


def body_lums(body, row, col, pts):
    p = body.load()
    return {(x, y): 0.3 * p[col * CELL + x, row * CELL + y][0] + 0.59 * p[col * CELL + x, row * CELL + y][1] + 0.11 * p[col * CELL + x, row * CELL + y][2] for x, y in pts}


def paint_ramp(img, row, col, body, pts, edge, ramp):
    """pts 픽셀을 ramp (어두움, 중간, 밝음) 로 칠한다. 원래 밝기 순서를 따르고, 테두리 · 선은 보랏빛 선 색."""
    if not pts:
        return
    lm = body_lums(body, row, col, pts)
    lo, hi = min(lm.values()), max(lm.values())
    d, m, l = ramp
    line = (int(m[0] * 0.35 + 15.6), int(m[1] * 0.35 + 14.4), int(m[2] * 0.35 + 28.8))
    p = img.load()
    for (x, y), v in lm.items():
        t = (v - lo) / max(1, hi - lo)
        c = line if (x, y) in edge or t < 0.22 else (d if t < 0.5 else (m if t < 0.85 else l))
        p[col * CELL + x, row * CELL + y] = (*c, 255)


def hands(pp, top):
    """윗도리 아래쪽 살색 = 손. 왼손 · 오른손 (옆모습은 하나) 의 x 범위 (가슴의 끈 같은 살색은 뺀다)"""
    _, _, _, ty1 = bbox(top)
    xs = sorted({x for x, y in pp["skin"] if ty1 - 5 <= y <= ty1 + 2})
    groups = []
    for x in xs:
        if groups and x - groups[-1][1] <= 1:
            groups[-1][1] = x
        else:
            groups.append([x, x])
    return groups


def fit_hat(draw_hat):
    def fn(img, row, col, body, pp, edge, pose):
        # 삐친 머리칼은 빼고 머리 몸통으로 잰다: 위에서 4줄 아래의 머리카락 폭
        hx0, hy0, hx1, _ = bbox(pp["hair"])
        band = [x for x, y in pp["hair"] if y == hy0 + 4]
        cx = (min(band) + max(band)) / 2 if band else (hx0 + hx1) / 2
        ox = round(cx - (OLD_HEAD_X1 - OLD_HEAD_X0) / 2)
        c = Warp(Canvas(img, col * CELL, row * CELL), ox, hy0 + 2, 1.0, 1.0)
        draw_hat(c, row, 0)
    return fn


def fit_top(ramp, vest=False, pocket=None, stripe=None):
    """옷: 윗도리 픽셀을 다시 칠한다. vest 면 팔(손 위 세로줄)은 남기고, 정면은 앞섶을 연다."""
    def fn(img, row, col, body, pp, edge, pose):
        top = pp["top"]
        tx0, ty0, tx1, ty1 = bbox(top)
        pts = set(top)
        hs = hands(pp, top)
        mid = (tx0 + tx1) / 2
        if vest:
            for a, b in hs:
                # 소매: 손 위 세로줄 + 몸 쪽으로 2줄
                a, b = (a, b + 2) if b < mid else (a - 2, b)
                pts = {(x, y) for x, y in pts if not (a <= x <= b and y > ty0 + 1)}
            if row == 0:
                    pts = {(x, y) for x, y in pts if abs(x + 0.5 - mid) > 1.6 or y < ty0 + 2}
        paint_ramp(img, row, col, body, pts, edge, ramp)
        c = Canvas(img, col * CELL, row * CELL)
        if pocket and row != 1:
            left = max([b for a, b in hs if b < mid], default=tx0 + 4) + 3
            right = min([a for a, b in hs if a > mid], default=tx1 - 4) - 3
            py = ty1 - 6
            spots = [(left, py), (right - 3, py)] if row == 0 else [(tx1 - 6, py)]
            for x0, y0 in spots:
                c.rect(x0, y0, x0 + 3, y0 + 3, ramp[0])
                c.rect(x0 + 1, y0 + 1, x0 + 2, y0 + 2, pocket)
        if stripe:
            sy = ty0 + (ty1 - ty0) * 2 // 3
            p = img.load()
            for x, y in pts:
                if y == sy and (x, y) not in edge:
                    p[col * CELL + x, row * CELL + y] = (*stripe, 255)
    return fn


def fit_feet(ramp, shaft=0, accent=None):
    """신발: 신발 픽셀을 다시 칠한다. shaft 면 그 줄 수만큼 바짓단도 장화 목으로 덮는다."""
    def fn(img, row, col, body, pp, edge, pose):
        shoes = set(pp["shoes"])
        pts = set(shoes)
        tops = {}
        for x, y in shoes:
            tops[x] = min(tops.get(x, 99), y)
        cover = {(x, y) for x, y in pp["pants"] if x in tops and tops[x] - shaft <= y < tops[x]}
        # 신발이 없는 줄 끝 (다리 가장자리) 도 이웃 줄에 맞춰 덮는다
        for x, y in pp["pants"]:
            near = [tops[k] for k in (x - 1, x + 1) if k in tops]
            if x not in tops and near and min(near) - shaft <= y < max(near):
                cover.add((x, y))
        pts |= cover
        paint_ramp(img, row, col, body, pts, edge, ramp)
        if accent and cover:
            p = img.load()
            for x, y in cover:
                if y == min(yy for xx, yy in cover if xx == x) and (x, y) not in edge:
                    p[col * CELL + x, row * CELL + y] = (*accent, 255)
    return fn


FIT = {
    "straw_hat": fit_hat(straw_hat),
    "work_cap": fit_hat(lambda c, row, b: cap(Recolor(c, {CAP: (236, 236, 226), CAP_D: (70, 140, 90), CAP_L: (250, 250, 244)}), row, b)),
    "seed_vest": fit_top((VEST_D, VEST, VEST_L), vest=True, pocket=SEED),
    "rain_suit": fit_top(((50, 66, 100), (70, 92, 132), (100, 126, 166)), stripe=(236, 214, 80)),
    "rain_boots": fit_feet((RUBBER_D, RUBBER, RUBBER_L), shaft=4),
    "work_boots": fit_feet(((40, 40, 48), (62, 62, 72), (96, 96, 108)), shaft=3, accent=(232, 196, 70)),
}


def make_fit(name, fn, body_name):
    body = Image.open(os.path.join(OUT_DIR, "..", "characters", f"{body_name}.png")).convert("RGBA")
    parts = Image.open(os.path.join(PARTS_DIR, f"{body_name}.png")).convert("RGBA")
    img = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    hat = Image.new("RGBA", img.size, (0, 0, 0, 0))
    poses = IDLE + WALK
    for row in range(ROWS):
        for col in range(COLS):
            pp, edge = cell_parts(parts, row, col)
            fn(hat if fn in HAT_FITS else img, row, col, body, pp, edge, poses[col])
    if fn in HAT_FITS:
        outline(hat)
        img = hat
    grade_p1(img)
    path = os.path.join(OUT_DIR, f"{name}.png")
    img.save(path)
    return path


HAT_FITS = {FIT["straw_hat"], FIT["work_cap"]}


def who_of(name):
    """scripts/wearables.gd 의 who (농부 장비인지)"""
    return "farmer" if name in ("straw_hat", "seed_vest", "rain_boots", "work_cap", "rain_suit", "work_boots") else "hunter"


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, fn in ITEMS.items():
        body = BODY_OF.get(who_of(name))
        if body and name in FIT and os.path.exists(os.path.join(PARTS_DIR, f"{body}.png")):
            print(make_fit(name, FIT[name], body), "(새 몸)")
        else:
            print(make(name, fn))
