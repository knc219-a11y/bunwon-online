"""플레이어 캐릭터 임시 스프라이트 시트 생성기.

코드로 그린 임시 그림이다. 최종 아트는 같은 규격의 PNG로 파일만 바꾸면 된다.
규격 (2026-09-27 결정: 4방향 · 걷기 4프레임 · 대기 2프레임, 칸 48x48):
  열: 0-1 대기, 2-5 걷기
  행: 0 아래(정면), 1 위(뒷모습), 2 옆(오른쪽). 왼쪽은 게임에서 좌우 반전.
  발바닥은 칸의 맨 아래 줄(y=47), 몸 중심은 x=24 근처.

실행: python3 tools/make_character_sheet.py  (Pillow 필요)
"""
import colorsys
import os

from PIL import Image, ImageDraw

CELL = 48
COLS = 6
ROWS = 3
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "characters")

SK, SK_D, SK_L = (242, 204, 170), (214, 168, 138), (252, 222, 192)
HR, HR_D, HR_L = (50, 48, 56), (34, 32, 40), (82, 80, 94)
JN, JN_D, JN_L = (76, 104, 150), (56, 78, 118), (104, 134, 178)
SH, SH_L = (44, 44, 52), (86, 86, 96)
GL, LENS, GLINT = (30, 30, 40), (62, 66, 88), (176, 186, 216)
EYE = (20, 20, 26)
MOUTH = (170, 96, 86)
CHEEK = (240, 170, 150)
STRING = (236, 236, 240)

HOODIES = {
    # 회색 후드티 (콘셉트 15장)
    "player": ((160, 164, 172), (126, 130, 142), (194, 198, 206)),
    # 사냥꾼 외형은 미정. 구분용 임시 초록 후드.
    "hunter": ((118, 150, 98), (88, 118, 76), (150, 182, 124)),
}

# 포즈: (몸 높이 변화 b, 왼발/뒷발 들림, 오른발/앞발 들림, 팔 흔들림)
IDLE = [dict(b=0, l=0, r=0, swing=0), dict(b=1, l=0, r=0, swing=0)]
WALK = [
    dict(b=0, l=0, r=2, swing=1),
    dict(b=-1, l=0, r=0, swing=0),
    dict(b=0, l=2, r=0, swing=-1),
    dict(b=-1, l=0, r=0, swing=0),
]


class Canvas:
    def __init__(self, img, ox, oy):
        self.d = ImageDraw.Draw(img)
        self.ox, self.oy = ox, oy

    def rect(self, x0, y0, x1, y1, c):
        """양 끝 포함 사각형."""
        self.d.rectangle((self.ox + x0, self.oy + y0, self.ox + x1, self.oy + y1), fill=c)

    def px(self, x, y, c):
        self.rect(x, y, x, y, c)

    def ellipse(self, x0, y0, x1, y1, c):
        self.d.ellipse((self.ox + x0, self.oy + y0, self.ox + x1, self.oy + y1), fill=c)


# ---------- 정면 / 뒷모습 공통 하체 ----------
def legs_front(c, pose):
    for side, lift in (("l", pose["l"]), ("r", pose["r"])):
        x0 = 17 if side == "l" else 25
        bottom = 43 - lift
        c.rect(x0, 36, x0 + 5, bottom, JN)
        # 안쪽 음영, 바깥쪽 하이라이트
        if side == "l":
            c.rect(x0 + 5, 38, x0 + 5, bottom, JN_D)
            c.rect(x0, 37, x0, bottom - 1, JN_L)
        else:
            c.rect(x0, 38, x0, bottom, JN_D)
            c.rect(x0 + 5, 37, x0 + 5, bottom, JN_D)
        c.rect(x0, bottom - 1, x0 + 5, bottom - 1, JN_L)  # 밑단
        sx = x0 - 1 if side == "l" else x0
        c.rect(sx, bottom + 1, sx + 6, bottom + 4, SH)
        c.rect(sx + 1, bottom + 1, sx + 4, bottom + 1, SH_L)
    c.rect(16, 34, 31, 37, JN)  # 엉덩이
    c.rect(23, 36, 24, 37, JN_D)
    c.rect(29, 34, 31, 37, JN_D)


def arms_front(c, b, swing, hd, back=False):
    for side in (-1, 1):
        dy = swing * side
        x0 = 12 if side == -1 else 32
        c.rect(x0, 23 + b, x0 + 3, 32 + b + dy, hd[0] if side == -1 else hd[1])
        c.rect(x0 + (3 if side == -1 else 0), 24 + b, x0 + (3 if side == -1 else 0), 32 + b + dy, hd[1])
        if side == -1:
            c.rect(x0, 24 + b, x0, 30 + b + dy, hd[2])
        c.rect(x0, 33 + b + dy, x0 + 3, 34 + b + dy, SK_D if (side == 1 or back) else SK)


def torso(c, b, hd, front=True):
    HD, HD_D, HD_L = hd
    c.rect(15, 22 + b, 32, 35 + b, HD)
    c.rect(29, 22 + b, 32, 35 + b, HD_D)
    c.rect(16, 24 + b, 17, 31 + b, HD_L)
    c.rect(15, 34 + b, 32, 35 + b, HD_D)  # 밑단 고무줄
    if front:
        # 캥거루 주머니
        c.rect(19, 29 + b, 28, 29 + b, HD_D)
        c.rect(19, 29 + b, 19, 32 + b, HD_D)
        c.rect(28, 29 + b, 28, 32 + b, HD_D)
        # 후드 끈
        c.rect(21, 23 + b, 21, 27 + b, STRING)
        c.rect(26, 23 + b, 26, 26 + b, STRING)
        # 목둘레 후드
        c.rect(17, 20 + b, 30, 23 + b, HD_D)
        c.rect(19, 21 + b, 28, 22 + b, HD)
        c.rect(21, 21 + b, 26, 21 + b, SK_D)  # 목
    else:
        # 등에 걸친 후드
        c.rect(16, 19 + b, 31, 23 + b, HD_D)
        c.rect(17, 22 + b, 30, 28 + b, HD_D)
        c.rect(18, 22 + b, 29, 26 + b, HD)
        c.rect(19, 22 + b, 23, 24 + b, HD_L)
        c.rect(19, 28 + b, 28, 28 + b, HD_D)


def head_front(c, b):
    c.ellipse(11, 12 + b, 13, 16 + b, SK_D)  # 귀
    c.ellipse(34, 12 + b, 36, 16 + b, SK_D)
    c.ellipse(12, 2 + b, 35, 23 + b, SK_D)
    c.ellipse(12, 2 + b, 34, 22 + b, SK)
    c.rect(14, 12 + b, 16, 15 + b, SK_L)
    # 헝클어진 머리
    c.ellipse(11, 1 + b, 36, 14 + b, HR)
    c.rect(11, 6 + b, 13, 13 + b, HR)
    c.rect(34, 6 + b, 36, 13 + b, HR_D)
    for x, drop in zip(range(14, 34), [2, 1, 2, 3, 1, 0, 2, 1, 3, 2, 0, 1, 2, 1, 3, 1, 0, 2, 1, 1]):
        c.rect(x, 12 + b, x, 12 + b + drop - 1, HR if x < 30 else HR_D) if drop else None
    c.px(21, 0 + b, HR)
    c.px(22, 0 + b, HR)
    c.px(27, 0 + b, HR_D)
    for x, y0, y1 in ((16, 3, 6), (19, 2, 5), (23, 2, 4), (27, 3, 5)):
        c.rect(x, y0 + b, x, y1 + b, HR_L)
    c.px(10, 8 + b, HR)  # 삐친 머리
    c.px(10, 11 + b, HR)
    c.px(37, 9 + b, HR_D)
    c.px(17, 1 + b, HR)
    c.px(30, 1 + b, HR_D)
    # 둥근 짙은 안경
    for gx in (15, 26):
        c.ellipse(gx, 12 + b, gx + 6, 18 + b, GL)
        c.ellipse(gx + 1, 13 + b, gx + 5, 17 + b, LENS)
        c.rect(gx + 3, 14 + b, gx + 3, 16 + b, EYE)
        c.px(gx + 1, 14 + b, GLINT)
    c.rect(22, 14 + b, 25, 14 + b, GL)
    # 볼, 입
    c.rect(14, 19 + b, 15, 19 + b, CHEEK)
    c.rect(32, 19 + b, 33, 19 + b, CHEEK)
    c.rect(22, 20 + b, 25, 20 + b, MOUTH)
    c.px(21, 19 + b, MOUTH)
    c.px(26, 19 + b, MOUTH)


def head_back(c, b):
    c.ellipse(11, 12 + b, 13, 16 + b, SK_D)
    c.ellipse(34, 12 + b, 36, 16 + b, SK_D)
    c.rect(20, 19 + b, 27, 21 + b, SK_D)  # 목덜미
    c.ellipse(11, 1 + b, 36, 21 + b, HR)
    c.ellipse(28, 3 + b, 36, 20 + b, HR_D)
    for x, y0, y1 in ((16, 3, 6), (20, 2, 5), (24, 2, 4), (28, 3, 6)):
        c.rect(x, y0 + b, x, y1 + b, HR_L)
    c.px(10, 8 + b, HR)
    c.px(37, 9 + b, HR_D)
    for x, drop in zip(range(14, 34, 2), [1, 2, 1, 3, 2, 1, 2, 3, 1, 2]):
        c.rect(x, 20 + b, x, 20 + b + drop - 1, HR_D)
    c.px(21, 0 + b, HR)
    c.px(22, 0 + b, HR)
    c.px(27, 0 + b, HR_D)


# ---------- 옆모습 (오른쪽을 봄) ----------
def leg_side(c, hip_x, foot_x, lift, col, dark):
    top, bottom = 36, 43 - lift
    for y in range(top, bottom + 1):
        t = (y - top) / max(1, bottom - top)
        x = round(hip_x + (foot_x - hip_x) * t)
        c.rect(x, y, x + 4, y, col)
        c.px(x + 4, y, dark)
    x = foot_x
    c.rect(x - 1, bottom + 1, x + 6, bottom + 3, SH)
    c.rect(x, bottom + 1, x + 4, bottom + 1, SH_L)
    c.rect(x - 1, bottom + 4, x + 6, bottom + 4, SH) if lift == 0 else None


def side_legs(c, pose, frame_kind):
    # frame_kind: "idle", "contact_a", "pass_a", "contact_b", "pass_b"
    near = dict(idle=(23, 23, 0), contact_a=(23, 28, 0), pass_a=(23, 23, 0), contact_b=(21, 15, 0), pass_b=(22, 24, 2))[frame_kind]
    far = dict(idle=(20, 19, 0), contact_a=(20, 14, 0), pass_a=(21, 22, 2), contact_b=(22, 27, 0), pass_b=(20, 20, 0))[frame_kind]
    leg_side(c, *far, JN_D, (44, 62, 96))
    leg_side(c, *near, JN, JN_D)
    c.rect(19, 34, 28, 37, JN)
    c.rect(19, 34, 21, 37, JN_D)


def side_arm(c, b, swing, col, hand, edge):
    # swing: +1 앞으로, -1 뒤로, 0 내림
    for y in range(23, 33):
        t = (y - 23) / 9
        x = round(22 + swing * 4 * t)
        c.rect(x, y + b, x + 3, y + b, col)
        c.px(x - 1, y + b, edge)
        c.px(x + 4, y + b, edge)
    hx = 22 + swing * 4
    c.rect(hx, 33 + b, hx + 3, 34 + b, hand)


def body_side(c, b, hd):
    HD, HD_D, HD_L = hd
    c.rect(18, 22 + b, 29, 35 + b, HD)
    c.rect(18, 22 + b, 20, 35 + b, HD_D)
    c.rect(18, 34 + b, 29, 35 + b, HD_D)
    c.rect(27, 24 + b, 28, 31 + b, HD_L)
    c.rect(26, 29 + b, 29, 29 + b, HD_D)  # 주머니 윗선
    c.rect(26, 29 + b, 26, 32 + b, HD_D)
    # 등의 후드
    c.rect(15, 19 + b, 20, 26 + b, HD_D)
    c.rect(16, 20 + b, 19, 24 + b, HD)
    c.rect(29, 23 + b, 29, 27 + b, STRING)  # 후드 끈


def head_side(c, b):
    c.ellipse(13, 2 + b, 35, 23 + b, SK_D)
    c.ellipse(14, 2 + b, 35, 22 + b, SK)
    c.rect(35, 15 + b, 36, 17 + b, SK)  # 코
    c.px(36, 17 + b, SK_D)
    c.rect(28, 12 + b, 30, 16 + b, SK_L)
    # 머리카락은 윗부분과 뒤통수
    c.ellipse(12, 1 + b, 35, 13 + b, HR)
    c.ellipse(12, 3 + b, 23, 20 + b, HR)
    c.ellipse(12, 7 + b, 18, 19 + b, HR_D)
    for x, drop in zip(range(23, 35), [3, 2, 1, 2, 3, 1, 0, 2, 1, 2, 1, 1]):
        c.rect(x, 12 + b, x, 12 + b + drop - 1, HR) if drop else None
    c.px(11, 9 + b, HR_D)  # 삐친 머리
    c.px(11, 12 + b, HR_D)
    c.px(19, 0 + b, HR)
    c.px(20, 0 + b, HR)
    c.px(25, 0 + b, HR_D)
    for x, y0, y1 in ((17, 3, 5), (21, 2, 4), (25, 2, 5), (29, 3, 5)):
        c.rect(x, y0 + b, x, y1 + b, HR_L)
    c.ellipse(21, 13 + b, 24, 18 + b, SK_D)  # 귀
    c.rect(22, 14 + b, 22, 16 + b, SK)
    # 안경: 옆에서 본 렌즈 1개 + 다리
    c.rect(23, 14 + b, 28, 14 + b, GL)
    c.ellipse(28, 12 + b, 34, 18 + b, GL)
    c.ellipse(29, 13 + b, 33, 17 + b, LENS)
    c.rect(32, 14 + b, 32, 16 + b, EYE)
    c.px(29, 14 + b, GLINT)
    c.rect(29, 19 + b, 30, 19 + b, CHEEK)
    c.rect(32, 20 + b, 33, 20 + b, MOUTH)
    c.px(34, 19 + b, MOUTH)


def draw_cell(img, col, row, pose, hd, kind):
    c = Canvas(img, col * CELL, row * CELL)
    b = pose["b"]
    if row == 0:
        legs_front(c, pose)
        arms_front(c, b, pose["swing"], hd)
        torso(c, b, hd, front=True)
        head_front(c, b)
    elif row == 1:
        legs_front(c, pose)
        arms_front(c, b, -pose["swing"], hd, back=True)
        torso(c, b, hd, front=False)
        head_back(c, b)
    else:
        s = pose["swing"]
        side_arm(c, b, s, hd[1], SK_D, hd[1])  # 먼 팔
        side_legs(c, pose, kind)
        body_side(c, b, hd)
        side_arm(c, b, -s, hd[2], SK, hd[1])  # 가까운 팔
        head_side(c, b)


def outline(img, cell=CELL):
    """투명 칸에 닿은 테두리를 이웃 색보다 어둡고 보랏빛으로 칠한다 (부드러운 외곽선)."""
    src = img.copy()
    w, h = img.size
    p, q = src.load(), img.load()
    for y in range(h):
        for x in range(w):
            if p[x, y][3]:
                continue
            if (x % cell) in (0, cell - 1):
                continue
            ns = [p[x + dx, y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if 0 <= x + dx < w and 0 <= y + dy < h and (x + dx) // cell == x // cell and (y + dy) // cell == y // cell]
            ns = [n for n in ns if n[3]]
            if not ns:
                continue
            r = sum(n[0] for n in ns) / len(ns)
            g = sum(n[1] for n in ns) / len(ns)
            bb = sum(n[2] for n in ns) / len(ns)
            q[x, y] = (int(r * 0.35 + 40 * 0.65 * 0.6), int(g * 0.35 + 24 * 0.6), int(bb * 0.35 + 48 * 0.6), 255)


def grade_p1(img):
    """P1 따뜻한 파스텔 보정 (design/art-standard/mockup_step2.py 와 같은 식)."""
    mix_col, mix_amt, shadow_col, shadow_amt = (255, 226, 190), 0.1, (110, 70, 120), 0.3
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            rr, gg, bb = colorsys.hls_to_rgb(h, l, s)
            k = shadow_amt * max(0, 0.55 - l) / 0.55
            out = []
            for v, sc, mc in zip((rr, gg, bb), shadow_col, mix_col):
                v = v * (1 - k) + sc / 255 * k
                v = v * (1 - mix_amt) + mc / 255 * mix_amt
                out.append(int(round(v * 255)))
            px[x, y] = (*out, a)


def make(name, hd):
    img = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    kinds = ["contact_a", "pass_a", "contact_b", "pass_b"]
    for row in range(ROWS):
        for i, pose in enumerate(IDLE):
            draw_cell(img, i, row, pose, hd, "idle")
        for i, pose in enumerate(WALK):
            draw_cell(img, 2 + i, row, pose, hd, kinds[i])
    outline(img)
    grade_p1(img)
    path = os.path.join(OUT_DIR, f"{name}.png")
    img.save(path)
    return path


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, hd in HOODIES.items():
        print(make(name, hd))
