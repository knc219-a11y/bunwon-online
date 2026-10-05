"""주인공 공격 모션 칸 + 무기 덧그림 시트 (2026-10-04 사용자 "공격 모션이 너무 구려").

몸 시트(assets/characters/<몸>.png)의 대기 · 걷기 6칸 오른쪽에 공격 칸 10개를 붙인다 (시트 768 x 144).
  열 6-9   근거리: 치켜들기 · 휘두르기 · 내려베기 · 마무리
  열 10-12 활:     시위 걸기 · 끝까지 당기기 · 놓기
  열 13-15 지팡이: 치켜들기 · 내뻗기(빛) · 거두기
행은 걷기와 같다 (0 아래 · 1 위 · 2 옆 오른쪽, 왼쪽은 좌우 반전).

몸 칸은 대기(또는 옆모습 내려베기는 걷기 디딤 칸) 몸에서 무기 든 팔을 지우고 새 자리에 다시 그린다.
같은 일을 부위 지도(tools/char_parts/<몸>.png)에도 해서 make_wear_sheets.py 가 장비 덧그림을 공격 칸에도 맞춘다.
무기 그림은 몸과 따로 assets/weapons/<종류>.png (같은 배치, 공격 칸만 그림): melee · bow · staff.
칸은 80 x 80 (몸 칸 48 의 사방 16px 여유, 가운데 같음) 이라 치켜든 칼 · 지팡이가 잘리지 않는다.
휘두르는 칸에는 칼끝이 지나간 자리에 옅은 잔상 (smear) 을 함께 그린다.

실행: python3 tools/make_attack_frames.py   (import_ai_character.py · --rewalk 뒤, make_wear_sheets.py 앞에)
      python3 tools/make_attack_frames.py --preview 그림.png   (4배 확대 미리보기)
"""
import math
import os
import sys

from PIL import Image

from make_character_sheet import CELL, ROWS

ROOT = os.path.join(os.path.dirname(__file__), "..")
PARTS_DIR = os.path.join(os.path.dirname(__file__), "char_parts")
BODIES = ["protagonist", "protagonist_b"]
BASE_COLS = 6
PART = {"hair": (40, 40, 40), "skin": (250, 200, 160), "top": (160, 160, 160), "pants": (70, 100, 200),
        "shoes": (120, 60, 20)}
LABEL = {v: k for k, v in PART.items()}

# ---------- 자세 표 ----------
# 칸마다: hand = 어깨에서 손까지 (dx, dy), ang = 무기 방향 (도, 0 오른쪽 · 90 아래), lean = 윗몸 옮김 (dx, dy),
#         base = 몸 바탕 칸 (0 대기, 2 걷기 디딤), smear = 잔상 (이전 칼끝 각도에서), 활은 pull = 시위 손 (어깨 기준)
# 행 0 (정면): 무기 손은 화면 왼쪽 (오른손), 위에서 아래로 비스듬히 벤다.
# 행 1 (뒷모습): 무기 손은 화면 오른쪽, 앞(화면 위)으로 넘겨 벤다. 무기는 몸 뒤에 그린다 (게임에서 z).
# 행 2 (옆 오른쪽): 뒤로 치켜들었다가 앞으로 내려벤다. 내려벨 때 다리를 벌리고 윗몸을 앞으로.
MELEE = {
    0: [dict(hand=(-5, -8), ang=-140, lean=(0, -1)),
        dict(hand=(2, -9), ang=-55, lean=(0, 0)),
        dict(hand=(8, 5), ang=25, lean=(0, 1), smear=True),
        dict(hand=(8, 9), ang=70, lean=(0, 1), smear=True, faint=True)],
    1: [dict(hand=(3, -8), ang=-50, lean=(0, -1)),
        dict(hand=(-1, -11), ang=-95, lean=(0, 0)),
        dict(hand=(-8, -6), ang=-160, lean=(0, 1), smear=True),
        dict(hand=(-9, -1), ang=165, lean=(0, 1), smear=True, faint=True)],
    2: [dict(hand=(-4, -8), ang=-140, lean=(-1, 0)),
        dict(hand=(2, -10), ang=-65, lean=(0, 0)),
        dict(hand=(9, 0), ang=15, lean=(1, 0), base=2, smear=True),
        dict(hand=(7, 5), ang=60, lean=(1, 0), base=2, smear=True, faint=True)],
}
# 활: 무기 손이 활을 잡고 겨누는 쪽으로 뻗는다. pull = 시위 당기는 손 (다른 손, 어깨 기준이 아니라 무기 손 어깨 기준)
BOW = {
    0: [dict(hand=(4, 6), aim=(0, 1), pull=(4, 4), lean=(0, 0)),
        dict(hand=(4, 7), aim=(0, 1), pull=(4, 1), lean=(0, -1)),
        dict(hand=(4, 7), aim=(0, 1), pull=None, back=(9, 0), lean=(0, 0))],
    1: [dict(hand=(-4, -7), aim=(0, -1), pull=(-4, -4), lean=(0, 0)),
        dict(hand=(-4, -8), aim=(0, -1), pull=(-4, -1), lean=(0, 0)),
        dict(hand=(-4, -8), aim=(0, -1), pull=None, back=(-9, 2), lean=(0, 1))],
    2: [dict(hand=(9, 1), aim=(1, 0), pull=(5, 1), lean=(0, 0)),
        dict(hand=(10, 0), aim=(1, 0), pull=(0, 0), lean=(-1, 0)),
        dict(hand=(10, 0), aim=(1, 0), pull=None, back=(-4, -2), lean=(-1, 0))],
}
STAFF = {
    0: [dict(hand=(-2, -9), ang=-95, lean=(0, -1)),
        dict(hand=(6, 4), ang=-60, lean=(0, 1), glow=True),
        dict(hand=(1, 7), ang=-88, lean=(0, 0))],
    1: [dict(hand=(2, -9), ang=-85, lean=(0, -1)),
        dict(hand=(-3, -11), ang=-110, lean=(0, 0), glow=True),
        dict(hand=(1, 6), ang=-92, lean=(0, 0))],
    2: [dict(hand=(-1, -9), ang=-100, lean=(-1, 0)),
        dict(hand=(9, -3), ang=-35, lean=(1, 0), base=2, glow=True),
        dict(hand=(5, 4), ang=-75, lean=(0, 0))],
}
KINDS = [("melee", 6, MELEE), ("bow", 10, BOW), ("staff", 13, STAFF)]
COLS_ALL = 16
# 무기 칸은 몸 칸보다 사방 PAD 씩 크다 (치켜든 칼 · 지팡이가 48px 칸 밖으로 나가도 잘리지 않게). 같은 가운데.
PAD = 16
WCELL = CELL + 2 * PAD

STEEL = [(64, 58, 84), (150, 158, 184), (214, 220, 236), (250, 252, 255)]  # 선 · 어둠 · 중간 · 날빛
GUARD = (204, 160, 72)
GRIP = (112, 72, 52)
WOOD = [(70, 46, 40), (128, 86, 56), (170, 120, 76)]
STRING = (238, 232, 214)
ORB = [(70, 90, 140), (120, 200, 250), (230, 250, 255)]
SMEAR = (255, 250, 228)


def line_px(a, b):
    """a → b 정수 픽셀 (끝 포함)"""
    (x0, y0), (x1, y1) = a, b
    n = max(abs(round(x1) - round(x0)), abs(round(y1) - round(y0)), 1)
    out = []
    for i in range(n + 1):
        p = (round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n))
        if not out or out[-1] != p:
            out.append(p)
    return out


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def dark_line(c):
    """이웃 색을 어둡게 한 보랏빛 테두리 (make_character_sheet.outline 과 같은 식)"""
    return (int(c[0] * 0.35 + 15.6), int(c[1] * 0.35 + 14.4), int(c[2] * 0.35 + 28.8), 255)


def label(pm, x, y):
    v = pm[x, y]
    return LABEL.get(v[:3]) if v[3] else None


def shift_upper(img, waist, dx, dy):
    if (dx, dy) == (0, 0):
        return img
    out = img.copy()
    top = img.crop((0, 0, CELL, waist))
    out.paste(Image.new("RGBA", top.size, (0, 0, 0, 0)), (0, 0))
    out.alpha_composite(top, (dx, dy))
    return out


class Fig:
    """몸 한 칸 (그림 + 부위 지도)"""

    def __init__(self, img, part):
        self.img, self.part = img, part
        self.p, self.pm = img.load(), part.load()

    def pts(self, *names):
        return [(x, y) for y in range(CELL) for x in range(CELL) if label(self.pm, x, y) in names]

    def bbox(self, *names):
        ps = self.pts(*names)
        xs, ys = [x for x, _ in ps], [y for _, y in ps]
        return min(xs), min(ys), max(xs), max(ys)

    def waist(self):
        """바지가 윗도리보다 많아지는 첫 줄"""
        for y in range(CELL):
            row = [label(self.pm, x, y) for x in range(CELL)]
            if row.count("pants") > row.count("top"):
                return y
        return CELL * 2 // 3

    def ramp(self, name):
        cs = sorted((self.p[x, y] for x, y in self.pts(name) if self.pm[x, y][3] == 255), key=lum)
        if not cs:
            return [(200, 160, 130, 255)] * 3
        return [cs[len(cs) // 5], cs[len(cs) // 2], cs[len(cs) * 4 // 5]]

    def set(self, x, y, col, part, edge=False):
        if 0 <= x < CELL and 0 <= y < CELL:
            self.p[x, y] = col
            self.pm[x, y] = (*PART[part], 254 if edge else 255) if part else (0, 0, 0, 0)


def erase_arm(f, row, side, waist, y_from):
    """무기 든 팔(어깨 아래 팔 · 손)을 지운다. side: -1 화면 왼쪽 팔, +1 오른쪽 (정면 · 뒷모습), 0 옆모습 앞팔.
    정면 · 뒷모습: 몸 가장자리에서 안쪽으로 살 · 테두리 픽셀을 윗도리 · 바지를 만날 때까지 지우고, 드러난 몸 가장자리에 테두리.
    옆모습: 몸통 위 살색을 같은 줄 뒤쪽 몸통 색으로 메운다."""
    gone = set()
    if side:
        for y in range(y_from, waist + 5):
            xs = range(CELL) if side < 0 else range(CELL - 1, -1, -1)
            started = False
            for x in xs:
                lb = label(f.pm, x, y)
                if lb is None:
                    if started:
                        break
                    continue
                started = True
                if lb == "skin" or f.pm[x, y][3] == 254:
                    gone.add((x, y))
                else:
                    break
        for x, y in gone:
            f.set(x, y, (0, 0, 0, 0), None)
        for x, y in gone:
            n = (x - side, y)
            if 0 <= n[0] < CELL and label(f.pm, *n) and n not in gone:
                f.set(n[0], n[1], dark_line(f.p[n]), label(f.pm, *n), True)
        return
    for y in range(y_from, waist + 4):
        for x in range(CELL):
            if label(f.pm, x, y) != "skin":
                continue
            # 뒤쪽(왼쪽)으로 살색이 아닌 몸통 색을 찾아 메운다
            src = None
            for bx in range(x - 1, -1, -1):
                lb = label(f.pm, bx, y)
                if lb in ("top", "pants") and f.pm[bx, y][3] == 255:
                    src = (bx, y)
                    break
            if src is None:
                continue
            edge_out = x + 1 >= CELL or not f.pm[x + 1, y][3]
            col = f.p[src]
            f.set(x, y, dark_line(col) if edge_out else col, label(f.pm, *src), edge_out)


def draw_arm(f, s, h, sleeve, skin, width=2):
    """어깨 s → 손 h 로 팔을 그린다: 어깨 쪽 3px 소매 (윗도리 색), 나머지 살 + 손, 둘레에 테두리."""
    arm = {}
    pts = line_px(s, h)
    vertical = abs(h[1] - s[1]) >= abs(h[0] - s[0])
    for i, (x, y) in enumerate(pts):
        part = "top" if i < 3 and sleeve else "skin"
        ramp = sleeve if part == "top" else skin
        arm[(x, y)] = (ramp[1], part)
        if width > 1:
            o = (x + 1, y) if vertical else (x, y + 1)
            arm.setdefault(o, (ramp[0], part))
    hx, hy = h
    for q in ((hx, hy), (hx + 1, hy), (hx, hy + 1), (hx + 1, hy + 1)):
        arm[q] = (skin[2] if q == (hx, hy) else skin[1], "skin")
    near = {(x, y) for x, y in pts[:2]}
    for (x, y) in list(arm):
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n in arm or not (0 <= n[0] < CELL and 0 <= n[1] < CELL):
                continue
            if any(abs(n[0] - a) + abs(n[1] - b) <= 1 for a, b in near):
                continue
            base = arm[(x, y)][0]
            f.set(n[0], n[1], dark_line(base), "skin", True)
    for (x, y), (col, part) in arm.items():
        f.set(x, y, col, part)


# ---------- 무기 그리기 (덧그림 칸) ----------
class Over:
    """무기 칸 (WCELL, 몸 칸 좌표 그대로 받아 PAD 만큼 옮겨 그린다)"""

    def __init__(self, img):
        self.img, self.p = img, img.load()

    def px(self, x, y, c, a=255):
        x, y = x + PAD, y + PAD
        if 0 <= x < WCELL and 0 <= y < WCELL:
            if a < 255 and self.p[x, y][3]:
                return
            self.p[x, y] = (*c[:3], a)

    def outline(self, col=STEEL[0], keep=()):
        src = self.img.copy().load()
        for y in range(WCELL):
            for x in range(WCELL):
                if src[x, y][3] or (x, y) in keep:
                    continue
                if any(0 <= x + dx < WCELL and 0 <= y + dy < WCELL and src[x + dx, y + dy][3] == 255
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.p[x, y] = (*col, 255)


def unit(deg):
    return math.cos(math.radians(deg)), math.sin(math.radians(deg))


def sword(o, h, ang, length=13):
    ux, uy = unit(ang)
    hx, hy = h
    # 자루 (손 뒤 2px) · 날밑 (손 앞, 가로 3px) · 날
    for p in line_px((hx - ux * 2, hy - uy * 2), (hx, hy)):
        o.px(*p, GRIP)
    gx, gy = hx + ux * 2, hy + uy * 2
    for k in (-2, -1, 0, 1, 2):
        o.px(round(gx - uy * k), round(gy + ux * k), GUARD)
    blade = line_px((hx + ux * 3, hy + uy * 3), (hx + ux * length, hy + uy * length))
    for i, p in enumerate(blade):
        o.px(*p, STEEL[2] if i < len(blade) - 1 else STEEL[3])
    o.outline()
    return (hx + ux * length, hy + uy * length)


def smear(o, pivot, tip0, tip1, faint):
    """칼끝 잔상: 지난 칸 칼끝 → 이 칸 칼끝을 어깨(pivot) 둘레로 잇는 호.
    칼날 바깥 절반 두께 (4px), 지난 쪽일수록 옅고 얇게."""
    a0 = math.degrees(math.atan2(tip0[1] - pivot[1], tip0[0] - pivot[0]))
    a1 = math.degrees(math.atan2(tip1[1] - pivot[1], tip1[0] - pivot[0]))
    r0, r1 = math.dist(tip0, pivot), math.dist(tip1, pivot)
    d = (a1 - a0 + 540) % 360 - 180
    steps = max(int(abs(d) / 3), 2)
    top = 130 if faint else 230
    for i in range(steps + 1):
        t = i / steps
        a = a0 + d * t
        r = r0 + (r1 - r0) * t
        alpha = int(top * (0.2 + 0.8 * t))
        thick = 2 + round(3 * t)
        ux, uy = unit(a)
        for k in range(thick):
            o.px(round(pivot[0] + ux * (r - k)), round(pivot[1] + uy * (r - k)), SMEAR, alpha)


def bow(o, h, aim, pull, back):
    """활: 손 h 에서 aim 쪽으로 휜 활대 (길이 15), 시위는 활 끝 둘에서 pull (당기는 손) 까지"""
    ax, ay = aim
    px_, py_ = -ay, ax  # 활대 방향 (겨눈 쪽에 수직)
    tips = []
    for k in range(-7, 8):
        bend = 2.5 * (1 - (k / 7) ** 2)
        x = round(h[0] + px_ * k + ax * bend)
        y = round(h[1] + py_ * k + ay * bend)
        o.px(x, y, WOOD[2] if abs(k) < 5 else WOOD[1])
        if abs(k) == 7:
            tips.append((x, y))
    o.outline(WOOD[0])
    if pull is not None:
        for t in tips:
            for p in line_px(t, pull)[1:-1]:
                o.px(*p, STRING)
        # 화살 (당긴 손 → 활 앞)
        for p in line_px(pull, (h[0] + ax * 5, h[1] + ay * 5)):
            o.px(*p, (200, 170, 120))
        o.px(round(h[0] + ax * 6), round(h[1] + ay * 6), STEEL[3])
        # 당기는 손
        for q in (pull, (pull[0] + 1, pull[1])):
            o.px(*q, (232, 180, 150))
    else:
        for p in line_px(tips[0], tips[1])[1:-1]:
            o.px(*p, STRING)
        if back:
            for q in (back, (back[0] + 1, back[1])):
                o.px(*q, (232, 180, 150))


def staff(o, h, ang, glow, length=19):
    ux, uy = unit(ang)
    hx, hy = h
    tip = (hx + ux * (length - 6), hy + uy * (length - 6))
    for p in line_px((hx - ux * 6, hy - uy * 6), tip):
        o.px(*p, WOOD[1])
    o.outline(WOOD[0])
    # 끝 구슬: 나무 위에 따로 그리고 구슬 둘레만 짙은 남색 테두리
    cx, cy = round(tip[0] + ux * 2), round(tip[1] + uy * 2)
    gem = Over(Image.new("RGBA", (WCELL, WCELL), (0, 0, 0, 0)))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if abs(dx) + abs(dy) < 2:
                gem.px(cx + dx, cy + dy, ORB[1])
    gem.px(cx, cy, ORB[2])
    gem.px(cx - 1, cy - 1, ORB[2])
    gem.outline(ORB[0])
    if glow:
        for k in range(8):
            ux2, uy2 = unit(k * 45 + 22)
            for r in (3, 4, 5) if k % 2 == 0 else (4,):
                gem.px(round(cx + ux2 * r), round(cy + uy2 * r), ORB[2] if r < 5 else ORB[1], 230 if r < 5 else 150)
    o.img.alpha_composite(gem.img)


# ---------- 칸 만들기 ----------
def make_cell(sheet, parts, row, kind, pose, prev):
    base = pose.get("base", 0)
    box = (base * CELL, row * CELL, base * CELL + CELL, row * CELL + CELL)
    f0 = Fig(sheet.crop(box), parts.crop(box))
    waist = f0.waist()
    lean = pose.get("lean", (0, 0))
    f = Fig(shift_upper(f0.img, waist, *lean), shift_upper(f0.part, waist, *lean))
    _, ty0, _, _ = f.bbox("top")
    side = {0: -1, 1: 1, 2: 0}[row]
    # 어깨: 윗도리 맨 윗줄에서 4줄 아래, 팔 쪽 가장자리에서 2px 안
    sy = ty0 + 4
    xs = [x for x in range(CELL) if label(f.pm, x, sy) == "top"]
    if side < 0:
        s = (min(xs) + 2, sy)
    elif side > 0:
        s = (max(xs) - 2, sy)
    else:
        s = ((min(xs) + max(xs)) // 2 + 1, sy)
    sleeve, skin = f.ramp("top"), f.ramp("skin")
    erase_arm(f, row, side, waist, sy + 3)
    h = (s[0] + pose["hand"][0], s[1] + pose["hand"][1])
    over = Image.new("RGBA", (WCELL, WCELL), (0, 0, 0, 0))
    o = Over(over)
    if kind == "bow" and side:
        # 정면 · 뒷모습 활: 다른 팔도 지우고 시위 쪽으로 굽혀 다시 그린다
        s2 = (max(xs) - 2, sy) if side < 0 else (min(xs) + 2, sy)
        erase_arm(f, row, -side, waist, sy + 3)
        pull = pose["pull"]
        h2 = (s[0] + pull[0], s[1] + pull[1]) if pull else (s2[0] - side * 2, s2[1] + 8)
        draw_arm(f, s2, h2, sleeve, skin)
    draw_arm(f, s, h, sleeve, skin)
    if kind == "melee":
        tip = sword(o, h, pose["ang"])
        if prev is not None and "smear" in pose:
            ph = (s[0] + prev["hand"][0], s[1] + prev["hand"][1])
            ux, uy = unit(prev["ang"])
            smear(o, s, (ph[0] + ux * 13, ph[1] + uy * 13), tip, pose.get("faint", False))
    elif kind == "bow":
        pull = pose["pull"]
        pp = (s[0] + pull[0], s[1] + pull[1]) if pull else None
        back = pose.get("back")
        bb = (s[0] + back[0], s[1] + back[1]) if back and not side else None
        bow(o, h, pose["aim"], pp, bb)
    else:
        staff(o, h, pose["ang"], pose.get("glow", False))
    return f.img, f.part, over


def build(body):
    sheet_path = os.path.join(ROOT, "assets", "characters", f"{body}.png")
    parts_path = os.path.join(PARTS_DIR, f"{body}.png")
    sheet = Image.open(sheet_path).convert("RGBA")
    parts = Image.open(parts_path).convert("RGBA")
    base_box = (0, 0, CELL * BASE_COLS, CELL * ROWS)
    # 공격 칸 뒤 (16 열부터) 에 걷기 칸이 더 있으면 그대로 둔다 (SpriteCook 주인공 A 걷기 8칸: import_spritecook_hero.py)
    cols = max(COLS_ALL, sheet.width // CELL)
    new_sheet = Image.new("RGBA", (CELL * cols, CELL * ROWS), (0, 0, 0, 0))
    new_parts = Image.new("RGBA", new_sheet.size, (0, 0, 0, 0))
    new_sheet.paste(sheet.crop(base_box), (0, 0))
    new_parts.paste(parts.crop(base_box), (0, 0))
    if cols > COLS_ALL:
        extra = (CELL * COLS_ALL, 0, CELL * cols, CELL * ROWS)
        new_sheet.paste(sheet.crop(extra), extra[:2])
        new_parts.paste(parts.crop(extra), extra[:2])
    weapons = {}
    for kind, col0, table in KINDS:
        wimg = Image.new("RGBA", (WCELL * COLS_ALL, WCELL * ROWS), (0, 0, 0, 0))
        for row in range(ROWS):
            prev = None
            for i, pose in enumerate(table[row]):
                img, part, over = make_cell(sheet, parts, row, kind, pose, prev)
                at = ((col0 + i) * CELL, row * CELL)
                new_sheet.paste(img, at)
                new_parts.paste(part, at)
                wimg.paste(over, ((col0 + i) * WCELL, row * WCELL))
                prev = pose
        weapons[kind] = wimg
    new_sheet.save(sheet_path)
    new_parts.save(parts_path)
    print("attack frames", body, new_sheet.size)
    return weapons


def main():
    weapons = None
    for body in BODIES:
        w = build(body)
        weapons = weapons or w
    # 무기 그림은 몸에 상관없이 하나 (손 자리는 두 몸이 같은 규격: 키 46px · 어깨 높이 같음)
    out = os.path.join(ROOT, "assets", "weapons")
    os.makedirs(out, exist_ok=True)
    for kind, img in weapons.items():
        img.save(os.path.join(out, f"{kind}.png"))
        print("weapon", kind)
    if len(sys.argv) > 2 and sys.argv[1] == "--preview":
        preview(sys.argv[2])


# 미리보기에 겹칠 사냥 옷 (있으면): 사냥꾼 조끼 · 가죽 두건 · 가죽신
PREVIEW_WEAR = ["hunter_jerkin", "leather_hood", "leather_shoes"]


def wear_layers(body):
    sub = "" if body == "protagonist" else "b"
    out = []
    if os.environ.get("WEAR"):
        for name in PREVIEW_WEAR:
            p = os.path.join(ROOT, "assets", "wear", sub, f"{name}.png")
            if os.path.exists(p):
                im = Image.open(p).convert("RGBA")
                if im.width >= CELL * COLS_ALL:
                    out.append(im)
    return out


def preview(path):
    """두 몸 x 공격 칸, 무기를 겹친 4배 그림 (뒷모습 줄은 무기를 몸 뒤에)"""
    rows = []
    for body in BODIES:
        sheet = Image.open(os.path.join(ROOT, "assets", "characters", f"{body}.png")).convert("RGBA")
        img = Image.new("RGBA", (CELL * 10, CELL * ROWS), (92, 98, 84, 255))
        for kind, col0, table in KINDS:
            w = Image.open(os.path.join(ROOT, "assets", "weapons", f"{kind}.png")).convert("RGBA")
            for row in range(ROWS):
                for i in range(len(table[row])):
                    box = ((col0 + i) * CELL, row * CELL, (col0 + i + 1) * CELL, (row + 1) * CELL)
                    wbox = ((col0 + i) * WCELL + PAD, row * WCELL + PAD, (col0 + i) * WCELL + PAD + CELL, row * WCELL + PAD + CELL)
                    at = ((col0 - 6 + i) * CELL, row * CELL)
                    if row == 1:
                        img.alpha_composite(w.crop(wbox), at)
                    img.alpha_composite(sheet.crop(box), at)
                    for layer in wear_layers(body):
                        img.alpha_composite(layer.crop(box), at)
                    if row != 1:
                        img.alpha_composite(w.crop(wbox), at)
        rows.append(img)
    out = Image.new("RGBA", (CELL * 10, CELL * ROWS * len(rows)), (0, 0, 0, 0))
    for i, r in enumerate(rows):
        out.paste(r, (0, i * CELL * ROWS))
    out.resize((out.width * 4, out.height * 4), Image.NEAREST).save(path)
    print("preview", path)


if __name__ == "__main__":
    main()
