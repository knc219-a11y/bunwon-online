"""곤지암 (4막 대장 구역) 스프라이트 시트 (2026-10-02 사용자 선택 A: 뿔 악귀 + 마왕 + 아기 악귀). 임시 그림 (코드로 그림).
사용자: "몬스터 더 강해보이는걸로하자 4막인만큼 악마타입으로".
뿔 악귀 48칸 x 8 (0-1 대기, 2-5 걷기, 6 팔 치켜듦 = 예고, 7 숨 고름), 마왕 64칸 x 8 (6 등불 깜빡 · 7 지침), 늘이지 않고 1:1 로 그린다.
아기 악귀 32칸 x 10 (0-1 대기, 2-5 이동, 6-9 일 · 불).
실행: python3 tools/make_gonjiam_sheets.py
"""
import os, sys, math
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image, ImageDraw
from make_character_sheet import grade_p1, outline
OUT = os.path.join(HERE, "..", "assets", "creatures")
INK = (30, 20, 30); EYE = (255, 230, 90); FIRE = (255, 140, 40); FIRE_L = (255, 220, 110); GREENF = (120, 255, 140)
HORN = (40, 34, 38); HORN_L = (90, 80, 84); TEETH = (245, 240, 220); MOUTH = (120, 20, 30)


def E(d, cx, cy, rx, ry, c):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=c)


def L(d, pts, c, w=1):
    d.line(pts, fill=c, width=w)


def P(d, pts, c):
    d.polygon(pts, fill=c)


def sheet(fns, cell):
    img = Image.new("RGBA", (cell * len(fns), cell), (0, 0, 0, 0))
    for i, fn in enumerate(fns):
        fr = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        fn(ImageDraw.Draw(fr), cell)
        img.alpha_composite(fr, (i * cell, 0))
    outline(img, cell); grade_p1(img)
    return img


BONE = (226, 210, 172); BONE_D = (150, 130, 104)


def horns(d, hx, hy, s, col=None, tip=None, big=1.0):
    # 뒤로 솟았다 앞으로 꺾이는 뼈빛 뿔 둘 (뒤쪽 뿔은 어둡게), 끝은 검게
    k = s * big
    path = [(0, 0), (-2, -3), (-2.4, -6), (-1, -8.5), (1.5, -9.5)]
    widths = [3, 2.5, 2, 1]
    for dx, c in ((-3, BONE_D), (1.5, BONE)):
        bx, by = hx + dx * s, hy - 3.5 * s
        pts = [(bx + px * k, by + py * k) for px, py in path]
        for i, (p0, p1) in enumerate(zip(pts, pts[1:])):
            L(d, [p0, p1], c if i < 3 else INK, max(1, int(round(widths[i] * k * 0.8))))


# ---------- A 뿔 악귀 (48) ----------
RED = (176, 44, 44); RED_D = (112, 26, 34); RED_L = (214, 84, 70)


def brute(skin=RED, dark=RED_D, light=RED_L, step=0, pose=0, tired=0, wing=(70, 30, 40)):
    def f(d, C):
        b = C - 1
        sy = 2 * tired + (1 if step % 2 else 0)
        # 날개 (찢어진 박쥐 날개, 등 뒤)
        wy = 12 + sy - (3 if pose == 1 else 0)
        P(d, [(16, 24 + sy), (3, wy), (6, wy + 6), (1, wy + 10), (8, wy + 12), (5, wy + 17), (14, 30 + sy)], wing)
        L(d, [(16, 24 + sy), (3, wy)], (40, 16, 24))
        # 다리 (굽은 짐승 다리)
        for i, (lx, off) in enumerate(((17, -step), (26, step))):
            lx += off * 0.8
            P(d, [(lx - 3, 33 + sy), (lx + 3, 33 + sy), (lx + 4, 40), (lx + 1, b - 1), (lx - 3, b - 1), (lx - 1, 40)], dark if i == 0 else skin)
            d.rectangle([lx - 4, b - 1, lx + 2, b], fill=INK)
        # 몸통 (어깨가 넓은 역삼각)
        P(d, [(12, 18 + sy), (34, 16 + sy), (30, 34 + sy), (16, 35 + sy)], skin)
        P(d, [(16, 28 + sy), (30, 27 + sy), (29, 34 + sy), (17, 35 + sy)], dark)
        L(d, [(20, 22 + sy), (24, 25 + sy), (28, 22 + sy)], dark)  # 가슴 근육
        d.rectangle([15, 33 + sy, 31, 35 + sy], fill=(60, 40, 40))  # 허리 사슬띠
        for x in range(16, 31, 3):
            d.point([(x, 34 + sy)], fill=(160, 160, 170))
        # 머리
        hx, hy = 33, 14 + sy + (2 if tired else 0)
        E(d, hx, hy, 5, 5, skin)
        P(d, [(hx + 1, hy + 2), (hx + 7, hy + 3), (hx + 5, hy + 6), (hx, hy + 5)], dark)  # 턱
        if pose == 1:
            P(d, [(hx + 2, hy + 3), (hx + 7, hy + 2), (hx + 6, hy + 6), (hx + 2, hy + 5)], MOUTH)
            d.point([(hx + 3, hy + 3), (hx + 5, hy + 3), (hx + 4, hy + 5)], fill=TEETH)
        else:
            d.point([(hx + 4, hy + 4), (hx + 6, hy + 4)], fill=TEETH)
        ec = (255, 90, 60) if pose == 1 else EYE
        if tired:
            L(d, [(hx + 1, hy - 1), (hx + 4, hy - 1)], INK)
        else:
            d.rectangle([hx + 1, hy - 2, hx + 2, hy - 1], fill=ec); d.rectangle([hx + 4, hy - 2, hx + 5, hy - 1], fill=ec)
        L(d, [(hx, hy - 3), (hx + 5, hy - 2)], dark)  # 눈썹
        horns(d, hx, hy, 1.2, big=0.75)
        # 팔 + 발톱
        if pose == 1:
            L(d, [(31, 19 + sy), (38, 8), (42, 4)], skin, 4)
            for k in range(3):
                L(d, [(41 + k, 3), (44 + k, 0)], TEETH)
            L(d, [(14, 20 + sy), (9, 10), (8, 6)], dark, 3)
        elif pose == 2:
            L(d, [(31, 20 + sy), (38, 30 + sy), (40, 36)], skin, 4)
        else:
            sw = (step - 1) * 1.5 if step else 0
            L(d, [(31, 19 + sy), (37 + sw, 26 + sy), (39 + sw, 31 + sy)], skin, 4)
            for k in range(3):
                L(d, [(38 + sw + k, 32 + sy), (39 + sw + k, 35 + sy)], TEETH)
            L(d, [(13, 20 + sy), (10 - sw, 28 + sy), (11 - sw, 32 + sy)], dark, 3)
    return f


# ---------- A 마왕 (64) ----------
VO = (70, 34, 84); VO_D = (40, 18, 52); VO_L = (110, 60, 120)


def archdemon(step=0, pose=0, tired=0, lantern=True):
    def f(d, C):
        b = C - 1
        sy = 3 * tired + (1 if step % 2 else 0)
        # 큰 날개 둘
        for side, x0 in ((-1, 26), (1, 40)):
            up = -6 if pose == 1 else 0
            tipx = x0 + side * 24
            pts = [(x0, 24 + sy), (tipx, 4 + up + sy), (tipx - side * 3, 14 + sy), (tipx + side * 1, 20 + sy), (tipx - side * 6, 24 + sy), (tipx - side * 3, 32 + sy), (x0 + side * 4, 36 + sy)]
            P(d, [(max(0, min(C - 1, x)), y) for x, y in pts], (52, 20, 40) if side < 0 else (66, 26, 50))
            L(d, [(x0, 24 + sy), (max(0, min(C - 1, tipx)), 4 + up + sy)], (30, 10, 24), 2)
        # 다리 · 옷자락 (해진 검은 도포)
        P(d, [(22, 34 + sy), (44, 34 + sy), (48, b - 2), (18, b - 2)], (34, 24, 40))
        for x in range(19, 48, 4):
            P(d, [(x, b - 3), (x + 2, b), (x + 4, b - 3)], (34, 24, 40))
        d.rectangle([24, b - 1, 30, b], fill=INK); d.rectangle([36, b - 1, 42, b], fill=INK)
        # 몸통
        P(d, [(20, 18 + sy), (46, 17 + sy), (42, 36 + sy), (24, 36 + sy)], VO)
        P(d, [(24, 28 + sy), (42, 28 + sy), (42, 36 + sy), (24, 36 + sy)], VO_D)
        P(d, [(30, 20 + sy), (36, 20 + sy), (33, 30 + sy)], (230, 120, 50))  # 가슴 불씨
        # 머리 + 불꽃 뿔 왕관
        hx, hy = 34, 17 + sy + (3 if tired else 0)
        E(d, hx, hy, 6, 6, VO_L)
        P(d, [(hx - 3, hy + 3), (hx + 7, hy + 3), (hx + 4, hy + 8), (hx - 1, hy + 7)], VO_D)
        ec = (120, 255, 140) if pose == 1 else (255, 240, 120)
        if tired:
            L(d, [(hx, hy), (hx + 5, hy)], INK)
        else:
            d.rectangle([hx, hy - 1, hx + 1, hy + 1], fill=ec); d.rectangle([hx + 4, hy - 1, hx + 5, hy + 1], fill=ec)
        d.point([(hx + 1, hy + 5), (hx + 3, hy + 5), (hx + 5, hy + 5)], fill=TEETH)
        horns(d, hx, hy - 1, 1.4, big=0.8)
        for k, (dx, h) in enumerate(((-4, 5), (-1, 7), (2, 6), (5, 4))):
            fy = hy - 6 - (step + k) % 2
            P(d, [(hx + dx - 1, fy), (hx + dx + 1, fy - h), (hx + dx + 3, fy)], FIRE if k % 2 else FIRE_L)
        # 팔: 오른손 지옥불 등불, 왼손 발톱
        if lantern:
            ax, ay = (52, 10) if pose == 1 else (50, 26 + sy)
            L(d, [(44, 20 + sy), (ax - 2, ay - 2)], VO, 4)
            L(d, [(ax, ay - 2), (ax, ay + 2)], HORN)
            lc = (60, 70, 60) if pose == 2 else GREENF
            d.rectangle([ax - 4, ay + 2, ax + 4, ay + 11], fill=(40, 36, 40))
            d.rectangle([ax - 3, ay + 3, ax + 3, ay + 10], fill=lc)
            d.point([(ax, ay + 6), (ax - 1, ay + 5)], fill=(230, 255, 230))
        L(d, [(21, 20 + sy), (16, 30 + sy), (17, 36 + sy)], VO, 4)
        for k in range(3):
            L(d, [(15 + k * 2, 37 + sy), (15 + k * 2, 40 + sy)], TEETH)
    return f


# ---------- 크리처 (32) ----------
def baby_imp(step=0, pose=0, tired=0):
    def f(d, C):
        sy = (1 if step % 2 else 0) + tired * 2
        P(d, [(12, 18 + sy), (5, 12 + sy), (7, 18 + sy), (4, 21 + sy), (11, 22 + sy)], (90, 36, 50))
        E(d, 16, 25 + sy, 6, 5, RED)
        L(d, [(13, 28 + sy), (12, 31)], RED_D, 2); L(d, [(19, 28 + sy), (20 - step % 2, 31)], RED_D, 2)
        E(d, 18, 15 + sy, 7, 6, RED_L)
        d.rectangle([18, 14 + sy, 19, 16 + sy], fill=INK); d.rectangle([22, 14 + sy, 23, 16 + sy], fill=INK)
        d.point([(18, 14 + sy), (22, 14 + sy)], fill=(255, 255, 255))
        d.point([(20, 19 + sy), (22, 19 + sy)], fill=TEETH)
        P(d, [(14, 10 + sy), (12, 4 + sy), (16, 9 + sy)], HORN); P(d, [(21, 9 + sy), (24, 4 + sy), (23, 10 + sy)], HORN)
        L(d, [(10, 27 + sy), (5, 29 + sy), (4, 26 + sy)], RED_D)
        P(d, [(3, 25 + sy), (5, 24 + sy), (4, 27 + sy)], RED_D)
        if pose:
            for k in range(3):
                P(d, [(25 + k * 2, 22 + sy), (26 + k * 2, 17 + sy - k), (27 + k * 2, 22 + sy)], FIRE if k % 2 else FIRE_L)
    return f


def frames8(mk):
    return [mk(), mk(step=1), mk(step=1), mk(step=2), mk(step=1), mk(), mk(pose=1), mk(tired=1, pose=2)]


def frames10(mk):
    return [mk(), mk(step=1), mk(step=1), mk(step=2), mk(step=1), mk(), mk(pose=1), mk(step=2), mk(pose=1), mk()]



out = {
    "wild_horn_demon": sheet(frames8(lambda **k: brute(**k)), 48),
    "wild_archdemon": sheet(frames8(lambda **k: archdemon(**k)), 64),
    "baby_imp": sheet(frames10(lambda **k: baby_imp(**k)), 32),
}
for k, img in out.items():
    img.save(os.path.join(OUT, k + ".png"))
    print(k, img.size)
