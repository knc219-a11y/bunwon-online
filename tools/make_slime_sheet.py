"""슬라임 임시 스프라이트 시트 생성기 (물속성 · 땅속성).

코드로 그린 임시 그림이다. 최종 아트는 같은 규격의 PNG로 파일만 바꾸면 된다.
규격 (2026-09-27 결정: 방향 없음 · 대기 2 · 깡충 4 · 급수 4, 칸 32x32):
  열: 0-1 대기, 2-5 깡충 이동, 6-9 급수
  행: 0 정면 (방향 없음. 방향을 늘리면 행을 추가한다)
  몸 가로 약 22px, 땅에 붙은 프레임은 몸 아래가 칸의 맨 아래 줄(y=31), 몸 중심은 x=16.

실행: python3 tools/make_slime_sheet.py  (Pillow 필요)
"""
import math
import os

from PIL import Image

from make_character_sheet import grade_p1, outline

CELL = 32
COLS = 10
ROWS = 1
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "creatures")

EYE, GLINT = (44, 34, 56), (250, 250, 255)
MOUTH, CHEEK = (120, 60, 80), (244, 160, 170)
SPOUT, SPOUT_L = (150, 205, 245), (225, 244, 255)

ELEMENTS = {
    # 물: 맑은 하늘색, 기포, 물방울 꼭지
    "water": dict(base=(116, 188, 238), dark=(72, 128, 204), light=(196, 232, 255), extra="drop"),
    # 땅: 황토·흙색, 돌 알갱이, 새싹 한 잎
    "earth": dict(base=(200, 160, 100), dark=(146, 108, 70), light=(232, 204, 146), extra="sprout"),
}

# 프레임: 몸 가로 w, 몸 높이 h, 뜬 높이 lift, 물줄기 단계 spout (0 없음)
IDLE = [dict(w=22, h=16, lift=0), dict(w=23, h=15, lift=0)]
HOP = [
    dict(w=25, h=12, lift=0),  # 눌림 (준비)
    dict(w=18, h=19, lift=4),  # 솟음
    dict(w=20, h=17, lift=9),  # 공중
    dict(w=25, h=12, lift=0),  # 착지 눌림
]
WATER = [
    dict(w=25, h=12, lift=0, spout=0),  # 힘주기
    dict(w=19, h=18, lift=0, spout=1),  # 꼭지에서 물이 솟기 시작
    dict(w=21, h=17, lift=0, spout=2),  # 물줄기 최고점
    dict(w=23, h=15, lift=0, spout=3),  # 물방울이 주위로 떨어짐
]


class Layer:
    def __init__(self):
        self.img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        self.p = self.img.load()

    def px(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < CELL and 0 <= y < CELL:
            self.p[x, y] = (*c, 255)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(round(y0)), int(round(y1)) + 1):
            for x in range(int(round(x0)), int(round(x1)) + 1):
                self.px(x, y, c)


def body_rows(w, h, lift):
    """몸 모양: 윗부분은 둥근 반타원, 아랫부분은 납작한 초타원. y → (왼쪽 x, 오른쪽 x)."""
    cx = 15.5
    bottom = CELL - 1 - lift
    top = bottom - h + 1
    yc = top + h * 0.62
    rows = {}
    for y in range(top, bottom + 1):
        yy = y + 0.5
        if yy < yc:
            t = (yc - yy) / (yc - top)
            k = math.sqrt(max(0.0, 1 - t * t))
        else:
            t = (yy - yc) / (bottom + 1 - yc)
            k = max(0.0, 1 - t ** 4) ** 0.25
        half = w / 2 * k
        if half >= 0.5:
            rows[y] = (int(round(cx - half)), int(round(cx + half)) - 1)
    return rows, top, bottom


def draw_body(l, f, el):
    w, h, lift = f["w"], f["h"], f["lift"]
    rows, top, bottom = body_rows(w, h, lift)
    cx = 15.5
    for y, (x0, x1) in rows.items():
        for x in range(x0, x1 + 1):
            c = el["base"]
            # 아래 두 줄과 오른쪽 아래는 그림자
            if y >= bottom - 1 or (x > cx + (x1 - cx) * 0.55 and y > top + h * 0.62):
                c = el["dark"]
            l.px(x, y, c)
    # 하이라이트 (왼쪽 위)
    hx, hy = cx - w * 0.26, top + h * 0.26
    l.rect(hx - 1, hy, hx + 1, hy, el["light"])
    l.rect(hx - 1, hy + 1, hx - 1, hy + 1, el["light"])
    l.px(hx + 3, hy - 1, el["light"])
    # 얼굴
    ey = top + h * 0.5
    eye_h = 3 if h >= 14 else 2
    for ex in (cx - w * 0.2, cx + w * 0.2 - 1):
        l.rect(ex, ey, ex + 1, ey + eye_h - 1, EYE)
        l.px(ex, ey, GLINT)
    my = ey + eye_h + 1
    l.rect(cx - 1, my, cx, my, MOUTH)
    l.px(cx - w * 0.3, my - 1, CHEEK)
    l.px(cx + w * 0.3 - 1, my - 1, CHEEK)
    # 속성 장식
    if el["extra"] == "drop":
        # 물방울처럼 뾰족한 꼭지, 몸 안 기포
        l.rect(cx - 1, top - 1, cx, top - 1, el["base"])
        l.px(cx, top - 2, el["light"])
        l.px(cx + w * 0.18, top + h * 0.72, el["light"])
        l.px(cx + w * 0.28, top + h * 0.5, el["light"])
    else:
        # 새싹 한 잎, 돌 알갱이
        leaf, leaf_d = (132, 190, 96), (84, 142, 72)
        # 급수 물줄기가 가운데 꼭지로 나오므로 새싹은 조금 오른쪽
        sx = cx + 3
        l.rect(sx, top - 3, sx, top, leaf_d)
        l.rect(sx - 3, top - 3, sx - 1, top - 3, leaf)
        l.px(sx - 2, top - 4, leaf)
        l.rect(sx + 1, top - 4, sx + 2, top - 4, leaf)
        l.px(sx + 3, top - 5, leaf)
        pebble = (118, 90, 66)
        for fx, fy in ((-0.3, 0.72), (0.12, 0.8), (0.3, 0.52)):
            l.px(cx + w * fx, top + h * fy, pebble)
    return top


def draw_spout(l, stage, top):
    cx = 15.5
    if stage == 1:
        # 꼭지 위로 짧게 솟는 물
        l.rect(cx - 1, top - 5, cx, top - 1, SPOUT)
        l.px(cx - 1, top - 5, SPOUT_L)
        l.rect(cx - 1, top - 8, cx, top - 7, SPOUT)
    elif stage == 2:
        # 높은 물줄기와 꼭대기에서 퍼지는 물방울
        l.rect(cx - 1, 3, cx, top - 1, SPOUT)
        l.rect(cx - 1, 3, cx - 1, top - 2, SPOUT_L)
        l.rect(cx - 3, 1, cx + 2, 2, SPOUT)
        for x, y in ((cx - 6, 3), (cx + 5, 3), (cx - 8, 6), (cx + 7, 6)):
            l.rect(x, y, x + 1, y + 1, SPOUT)
            l.px(x, y, SPOUT_L)
    elif stage == 3:
        # 몸 둘레로 떨어지는 물방울
        for x, y in ((cx - 12, 12), (cx + 11, 12), (cx - 13, 20), (cx + 12, 20), (cx - 5, 5), (cx + 4, 5)):
            l.rect(x, y, x + 1, y + 2, SPOUT)
            l.px(x, y, SPOUT_L)


def draw_frame(f, el):
    l = Layer()
    top = draw_body(l, f, el)
    if f.get("spout"):
        draw_spout(l, f["spout"], top)
    return l.img


def make(name, el):
    img = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for i, f in enumerate(IDLE + HOP + WATER):
        img.alpha_composite(draw_frame(f, el), (i * CELL, 0))
    outline(img, CELL)
    grade_p1(img)
    path = os.path.join(OUT_DIR, f"slime_{name}.png")
    img.save(path)
    return path


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, el in ELEMENTS.items():
        print(make(name, el))
