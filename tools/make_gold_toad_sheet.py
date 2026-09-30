"""아기 금두꺼비 임시 스프라이트 시트 생성기 (땅속성).

코드로 그린 임시 그림이다. 최종 아트는 같은 규격의 PNG로 파일만 바꾸면 된다.
금사리 대장 금두꺼비의 알에서 나오는 크리처 (2026-09-28 사용자 선택). 사금이 나는 하천 마을 금사리 이야기.
규격 (슬라임 시트와 같음, docs/sprites.md): 32x32 칸, 방향 없음
  열: 0-1 대기, 2-5 깡충 이동, 6-9 일 (혀를 내밀고 발밑에서 사금이 반짝)
  발바닥은 칸의 맨 아래 줄(y=31), 몸 중심은 x=16.

실행: python3 tools/make_gold_toad_sheet.py  (Pillow 필요)
2026-09-30: 모래게 · 금두꺼비 · 아기 금두꺼비 시트는 사용자 AI 그림 (tools/import_ai_monster.py) 으로 바뀌었다. 이 스크립트를 돌리면 코드 그림으로 덮어쓰니 주의.
"""
import os

from PIL import Image

from make_character_sheet import grade_p1, outline
from make_slime_sheet import CELL, Layer

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "creatures")

EYE, GLINT = (44, 34, 56), (250, 250, 255)
MOUTH, CHEEK = (120, 60, 80), (244, 160, 170)
BELLY = (236, 226, 170)
TONGUE, TONGUE_D, TONGUE_L = (232, 110, 120), (190, 76, 96), (255, 190, 196)
GOLD, GOLD_L = (252, 222, 96), (255, 248, 200)

ELEMENTS = {
    # 땅: 금빛 몸, 등에 짙은 금빛 얼룩
    "earth": dict(base=(226, 182, 78), dark=(176, 130, 54), light=(248, 218, 128), spot=(200, 150, 60)),
}

# 프레임: (가로 늘임, 세로 늘임, 뜬 높이, 일 단계)
IDLE = [(0.85, 0.9, 0, 0), (0.88, 0.86, 0, 0)]
HOP = [(0.95, 0.77, 0, 0), (0.77, 0.99, 3, 0), (0.81, 0.95, 6, 0), (0.95, 0.77, 0, 0)]
WORK = [(0.94, 0.81, 0, 0), (0.81, 0.95, 0, 1), (0.85, 0.9, 0, 2), (0.88, 0.86, 0, 3)]


def ell(l, cx, cy, rx, ry, c, shade=None, light=None):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = dx * dx + dy * dy
            if d <= 1.0:
                col = c
                if shade and (dy > 0.45 or (dx > 0.45 and dy > 0.0)):
                    col = shade
                if light and dx < -0.2 and dy < -0.3 and d < 0.55:
                    col = light
                l.px(x, y, col)


def draw_frame(f, c):
    sx, sy, lift, stage = f
    l = Layer()
    cx, bottom = 15.5, CELL - 1 - lift
    rx, ry = 11.5 * sx, 8 * sy
    cy = bottom - ry + 0.5
    # 뒷다리
    ell(l, cx - rx + 1, bottom - 1.5, 3.5, 2.2, c["dark"])
    ell(l, cx + rx - 1, bottom - 1.5, 3.5, 2.2, c["dark"])
    ell(l, cx, cy, rx, ry, c["base"], c["dark"], c["light"])
    ell(l, cx, cy + ry * 0.35, rx * 0.55, ry * 0.5, BELLY)
    for mx, my in ((-0.45, -0.3), (0.35, -0.45), (0.55, 0.05)):
        l.rect(cx + rx * mx, cy + ry * my, cx + rx * mx + 1, cy + ry * my, c["spot"])
    # 머리 위 불룩 눈
    top = cy - ry
    for ex in (cx - 5.5, cx + 5.5):
        ell(l, ex, top + 1, 3.2, 3.0, c["base"], None, c["light"])
    for ex in (cx - 6, cx + 5):
        l.rect(ex, top, ex + 1, top + 1, EYE)
        l.px(ex, top, GLINT)
    my = cy + 0.5
    l.rect(cx - 4, my, cx + 3, my, MOUTH)
    l.px(cx - 6, my - 1, CHEEK)
    l.px(cx + 5, my - 1, CHEEK)
    # 일: 혀를 앞으로 쭉, 발밑에서 사금이 반짝
    if stage:
        n = {1: 2, 2: 6, 3: 3}[stage]
        l.rect(cx - 1, my, cx, my + 1, TONGUE_D)
        for i in range(n):
            l.rect(cx - 1, my + 1 + i, cx, my + 1 + i, TONGUE)
        if stage == 2:
            l.rect(cx - 2, my + n, cx + 1, my + n + 1, TONGUE)
            l.px(cx - 1, my + n, TONGUE_L)
    if stage >= 2:
        for x, y in ((6, 29), (25, 28), (9, 24), (23, 23)) if stage == 3 else ((8, 28), (24, 27)):
            l.px(x, y, GOLD)
            l.px(x, y - 1, GOLD_L)
            l.px(x - 1, y, GOLD_L)
    return l.img


def make(name, c):
    img = Image.new("RGBA", (CELL * 10, CELL), (0, 0, 0, 0))
    for i, f in enumerate(IDLE + HOP + WORK):
        img.alpha_composite(draw_frame(f, c), (i * CELL, 0))
    outline(img, CELL)
    grade_p1(img)
    path = os.path.join(OUT_DIR, f"gold_toad_{name}.png")
    img.save(path)
    return path


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, c in ELEMENTS.items():
        print(make(name, c))
