"""입는 장비 임시 덧그림 시트 생성기.

캐릭터 시트(assets/characters/*.png)와 같은 규격(288x144, 칸 48x48, 열 0-1 대기 · 2-5 걷기,
행 0 아래 · 1 위 · 2 옆)의 투명 PNG를 만든다. 게임은 캐릭터 그림 위에 같은 칸을 겹쳐 그린다.
코드로 그린 임시 그림이다. 최종 아트는 같은 규격 PNG로 파일만 바꾸면 된다.
마을에서 사는 물건이라 모두 현대풍 (2026-09-27 사용자 방향: 제작·마을 물건 현대풍, 사냥터 완제품 판타지풍).

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


# ---------- 옷 ----------
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
}

if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, fn in ITEMS.items():
        print(make(name, fn))
