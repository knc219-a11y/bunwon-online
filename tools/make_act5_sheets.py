"""5막 스프라이트 시트 (2026-10-03, 임시 그림 = 코드로 그림). 후보 목업 design/act5/mock/make_act5_candidates.py 에서 옮김.
사용자: "9구역에서는 도마뱀인간 종류 보스는 알아서 후보정해주고 / 10구역 은 와이번이고 마지막보스는 신비로운 용? 드래곤?"
귀여리 A 방패 도마뱀 + 도마뱀 족장 → 아기 도마뱀 / B 늪 도마뱀 + 악어 왕 → 아기 도롱뇽 / C 카멜레온 도마뱀 + 바실리스크 → 아기 카멜레온
소내섬 A 독꼬리 와이번 + 팔당 청룡 → 아기 청룡 / B 불 와이번 + 운룡 → 아기 와이번 / C 청동 와이번 + 황금 드래곤 → 아기 드래곤
몬스터 48칸 (8칸: 0-1 대기, 2-5 이동, 6 예고, 7 지침), 대장 64칸 (1:1), 크리처 32칸 (10칸). 앞이 오른쪽, 발바닥 = 칸 아래 끝.
소내섬 (사용자: "마지막은 기본이 일반용이고 희귀한 확률로 세가지 용이 우연하게나오는 구조로가자"): 와이번 48칸,
용 넷 (일반 용 · 청룡 · 운룡 · 황금 드래곤) 은 96칸에 1.5배 크기로 1:1 로 그린다 (늘이지 않음), 아기 32칸 x 10.
실행: python3 tools/make_act5_sheets.py
"""
import os, sys, math
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image, ImageDraw
from make_character_sheet import grade_p1, outline
OUT = os.path.join(HERE, "..", "assets", "creatures")
INK = (30, 22, 30); EYE = (255, 226, 90); TEETH = (245, 240, 220); MOUTH = (130, 30, 40)
WOOD = (150, 104, 66); WOOD_D = (104, 70, 46); BRONZE = (196, 150, 70); BRONZE_D = (140, 100, 50); STEEL = (196, 200, 210)
FIRE = (255, 140, 40); FIRE_L = (255, 220, 110); POISON = (150, 230, 90)


class D:
    """좌표를 k 배로 늘려 (ox, oy) 에 놓고 그리는 붓 (몬스터 48 그림을 대장 64 에 크게)."""

    def __init__(self, d, k=1.0, ox=0.0, oy=0.0):
        self.d, self.k, self.ox, self.oy = d, k, ox, oy

    def p(self, x, y):
        return (self.ox + x * self.k, self.oy + y * self.k)

    def poly(self, pts, c):
        self.d.polygon([self.p(x, y) for x, y in pts], fill=c)

    def line(self, pts, c, w=1):
        self.d.line([self.p(x, y) for x, y in pts], fill=c, width=max(1, int(round(w * self.k))))

    def ell(self, cx, cy, rx, ry, c):
        x, y = self.p(cx, cy)
        self.d.ellipse([x - rx * self.k, y - ry * self.k, x + rx * self.k, y + ry * self.k], fill=c)

    def rect(self, x0, y0, x1, y1, c):
        a, b = self.p(x0, y0)
        e, f = self.p(x1, y1)
        self.d.rectangle([a, b, e, f], fill=c)

    def dot(self, x, y, c, r=0):
        a, b = self.p(x, y)
        rr = max(0, int(round(r * self.k)))
        self.d.rectangle([a - rr, b - rr, a + rr, b + rr], fill=c)


def sheet(fns, cell):
    img = Image.new("RGBA", (cell * len(fns), cell), (0, 0, 0, 0))
    for i, fn in enumerate(fns):
        fr = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        fn(ImageDraw.Draw(fr), cell)
        img.alpha_composite(fr, (i * cell, 0))
    outline(img, cell); grade_p1(img)
    return img


def brush(d, C, k):
    # 48 기준 그림을 C 칸에 k 배로, 발바닥을 칸 아래 끝에 맞춰 가운데 정렬
    return D(d, k, (C - 48 * k) / 2, (C - 1) - 47 * k)


# ================= 귀여리: 도마뱀인간 (서서 걷는 도마뱀) =================
def lizard(skin, dark, belly, kit="shield", step=0, pose=0, tired=0, k=1.0, extra=None):
    def f(d0, C):
        d = brush(d0, C, k)
        sy = 2 * tired + (1 if step % 2 else 0)
        # 꼬리 (뒤로 길게, 끝은 땅에)
        if kit == "chameleon":
            d.poly([(18, 28 + sy), (10, 36), (8, 42), (12, 46), (16, 44), (14, 40), (20, 34 + sy)], dark)
            d.ell(12, 42, 3, 3, skin); d.ell(12, 42, 1.4, 1.4, dark)
        else:
            d.poly([(19, 27 + sy), (9, 36), (2, 45), (6, 46), (13, 40), (21, 33 + sy)], dark)
            d.line([(17, 30 + sy), (6, 43)], skin, 2)
        # 다리 (뒤 · 앞)
        for i, (lx, off) in enumerate(((19, -step), (26, step))):
            lx += off * 0.8
            c = dark if i == 0 else skin
            d.poly([(lx - 3, 31 + sy), (lx + 3, 31 + sy), (lx + 4, 38), (lx + 1, 46), (lx - 2, 46), (lx - 1, 38)], c)
            d.rect(lx - 2, 45, lx + 4, 47, INK)
            d.dot(lx + 4, 47, (220, 210, 180))
        # 몸통 (앞으로 숙인 상체)
        d.poly([(17, 19 + sy), (29, 14 + sy), (32, 30 + sy), (19, 34 + sy)], skin)
        d.poly([(27, 16 + sy), (31, 16 + sy), (32, 30 + sy), (28, 31 + sy)], belly)
        for yy in range(19, 31, 3):
            d.line([(28, yy + sy), (31, yy + sy)], (belly[0] - 40, belly[1] - 40, belly[2] - 30))
        if kit == "shield":
            d.rect(18, 29 + sy, 31, 31 + sy, WOOD_D)  # 가죽 허리띠
        # 등 가시 (볏)
        fin = (70, 150, 200) if kit == "swim" else dark
        for i in range(5):
            x, y = 29 - i * 3, 12 + i * 3 + sy
            h = 4 if kit == "swim" else 2.5
            d.poly([(x, y), (x - 1.5, y - h - (1 if kit == "swim" and i % 2 else 0)), (x - 3, y + 1)], fin)
        # 머리 + 주둥이
        hx, hy = 33, 11 + sy + (3 if tired else 0)
        d.ell(hx, hy, 5, 4, skin)
        jaw = 2 if pose == 1 and kit != "shield" else 0
        d.poly([(hx + 1, hy - 2), (hx + 11, hy), (hx + 11, hy + 2), (hx + 1, hy + 2)], skin)  # 윗턱
        d.poly([(hx + 1, hy + 2), (hx + 10, hy + 2 + jaw), (hx + 9, hy + 4 + jaw), (hx, hy + 4)], belly)  # 아래턱
        if jaw:
            d.poly([(hx + 2, hy + 2), (hx + 10, hy + 2), (hx + 9, hy + 2 + jaw)], MOUTH)
            d.dot(hx + 5, hy + 2, TEETH); d.dot(hx + 8, hy + 2, TEETH)
        d.dot(hx + 10, hy - 0.5, INK)  # 콧구멍
        if kit == "chameleon":
            d.ell(hx + 1, hy - 1, 3, 3, skin); d.ell(hx + 1.5, hy - 1, 1.6, 1.6, EYE)
            d.dot(hx + 2 + (1 if pose else 0), hy - 1, INK)
            d.poly([(hx - 4, hy - 3), (hx, hy - 7), (hx + 3, hy - 4)], dark)  # 투구 볏
        elif tired:
            d.line([(hx + 1, hy - 1), (hx + 4, hy - 1)], INK)
        else:
            ec = (255, 90, 60) if pose == 1 else EYE
            d.rect(hx + 2, hy - 2, hx + 3, hy - 1, ec); d.dot(hx + 3, hy - 1.5, INK)
        if kit == "swim":
            d.poly([(hx - 3, hy - 3), (hx - 6, hy - 9), (hx - 1, hy - 5)], fin)
            d.poly([(hx - 4, hy), (hx - 8, hy - 3), (hx - 5, hy + 2)], fin)  # 귀지느러미
        # 팔 · 무기
        if kit == "shield":
            # 뒤 손: 창, 앞 손: 둥근 나무 방패
            if pose == 1:
                d.line([(6, 20 + sy), (40, 18 + sy)], WOOD, 1)  # 창을 뒤로 당김 (찌르기 예고)
                d.poly([(40, 16 + sy), (45, 18 + sy), (40, 20 + sy)], STEEL)
                d.line([(21, 21 + sy), (16, 22 + sy)], dark, 2)
            elif tired:
                d.line([(14, 46), (30, 26 + sy)], WOOD, 1)
                d.poly([(12, 47), (14, 43), (16, 46)], STEEL)
            else:
                d.line([(21, 4 + sy), (23, 42)], WOOD, 1)
                d.poly([(19, 5 + sy), (21, -1 + sy), (23, 5 + sy)], STEEL)
                d.line([(22, 21 + sy), (22, 25 + sy)], dark, 2)
            shy = 30 + sy if tired else (20 + sy if pose == 1 else 24 + sy)
            d.ell(37, shy, 4.5, 8, WOOD); d.ell(37, shy, 3, 6.5, WOOD_D); d.ell(37.5, shy, 1.6, 1.6, BRONZE)
            d.line([(37, shy - 8), (37, shy + 8)], BRONZE_D)
        elif kit == "swim":
            # 작살 (세 갈래)
            if pose == 1:
                d.line([(30, 20 + sy), (38, 24 + sy)], skin, 3)
                d.line([(22, 26 + sy), (46, 30 + sy)], WOOD, 1)
                for dy in (-2, 0, 2):
                    d.line([(43, 29 + sy + dy), (47, 30 + sy + dy)], STEEL)
            else:
                sw = (step - 1) * 1.5 if step else 0
                d.line([(30, 20 + sy), (35 + sw, 26 + sy)], skin, 3)
                d.line([(35 + sw, 40), (37 + sw, 6 + sy)], WOOD, 1)
                for dx in (-2, 0, 2):
                    d.line([(37 + sw + dx, 6 + sy), (37 + sw + dx, 2 + sy)], STEEL)
        else:
            # 카멜레온: 혀 채찍
            d.line([(30, 20 + sy), (34, 26 + sy), (36, 28 + sy)], skin, 2)
            if pose == 1:
                d.line([(hx + 10, hy + 2), (47, hy + 6)], (230, 100, 130), 2)
                d.ell(46, hy + 6, 2, 2, (240, 120, 150))
        if extra:
            extra(d, sy, hx, hy)
    return f


def chief_extra(step=0, pose=0, tired=0):
    def ex(d, sy, hx, hy):
        # 깃털 · 뼈 머리장식 + 목걸이 이빨 + 북
        for i, c in enumerate(((220, 70, 60), (250, 200, 80), (90, 170, 210))):
            d.line([(hx - 2 + i, hy - 3), (hx - 6 + i * 3, hy - 11 - (1 if i == 1 else 0))], c, 2)
        d.line([(24, 18 + sy), (30, 20 + sy)], TEETH)
        for x in (25, 27, 29):
            d.poly([(x, 19 + sy), (x + 1, 22 + sy), (x + 2, 19 + sy)], TEETH)
    return ex


# 큰 대장 (64칸): 네 발 도마뱀 몸 (악어 왕 · 바실리스크)
def quad(skin, dark, belly, kind="croc", step=0, pose=0, tired=0):
    def f(d0, C):
        d = D(d0)
        b = C - 1
        sy = 2 * tired + (1 if step % 2 else 0)
        # 꼬리
        d.poly([(16, 40 + sy), (4, 46), (1, 52), (6, 52), (18, 48 + sy)], dark)
        # 다리 넷
        for i, (lx, off) in enumerate(((18, -step), (24, step), (38, step), (44, -step))):
            c = dark if i in (0, 2) else skin
            lx += off
            d.poly([(lx - 3, 44 + sy), (lx + 3, 44 + sy), (lx + 3, b - 3), (lx - 3, b - 3)], c)
            d.rect(lx - 4, b - 3, lx + 4, b, INK)
        # 몸통
        d.ell(31, 42 + sy, 17, 8, skin)
        d.poly([(16, 44 + sy), (46, 44 + sy), (44, 50 + sy), (18, 50 + sy)], belly)
        # 등 비늘 줄
        for x in range(16, 46, 4):
            d.poly([(x, 36 + sy), (x + 2, 31 + sy - (2 if kind == "basilisk" else 0)), (x + 4, 36 + sy)], dark)
        # 머리 (오른쪽)
        hy = 36 + sy + (4 if tired else 0)
        open_ = 6 if pose == 1 else 0
        if kind == "croc":
            d.poly([(42, hy - 4), (62, hy - 1), (62, hy + 2), (42, hy + 3)], skin)  # 윗턱
            d.poly([(42, hy + 3), (61, hy + 3 + open_), (60, hy + 6 + open_), (42, hy + 7)], belly)  # 아래턱
            if open_:
                d.poly([(43, hy + 3), (61, hy + 2), (61, hy + 3 + open_)], MOUTH)
            for x in range(45, 61, 3):
                d.poly([(x, hy + 2), (x + 1, hy + 4), (x + 2, hy + 2)], TEETH)
            d.ell(46, hy - 5, 3, 2.5, skin)
            if tired:
                d.line([(45, hy - 5), (48, hy - 5)], INK)
            else:
                d.rect(46, hy - 6, 47, hy - 5, EYE); d.dot(47, hy - 5, INK)
            # 금관
            d.poly([(40, hy - 7), (50, hy - 7), (50, hy - 11), (48, hy - 9), (45, hy - 13), (43, hy - 9), (40, hy - 11)], (240, 200, 80))
            d.dot(45, hy - 9, (90, 200, 220))
        else:
            # 바실리스크: 짧은 머리, 닭 볏, 빛나는 눈
            d.ell(48, hy - 2, 8, 6, skin)
            d.poly([(52, hy), (61, hy + 2), (52, hy + 5)], belly)
            if open_:
                d.poly([(53, hy + 2), (61, hy + 1), (60, hy + 6)], MOUTH)
            for i in range(4):
                d.ell(42 + i * 3, hy - 9 + (i % 2), 2.5, 3, (200, 50, 60))
            ec = (180, 255, 120) if pose == 1 else EYE
            if tired:
                d.line([(49, hy - 3), (53, hy - 3)], INK)
            else:
                d.ell(51, hy - 3, 2, 2, ec)
                if pose == 1:
                    for a in range(-2, 3):
                        d.line([(53, hy - 3), (63, hy - 3 + a * 3)], (200, 255, 150), 1)
            d.poly([(50, hy + 5), (52, hy + 10), (54, hy + 5)], (200, 50, 60))  # 턱 볏
    return f


def chieftain(step=0, pose=0, tired=0):
    return lizard((96, 132, 70), (60, 92, 54), (210, 200, 140), "shield", step, pose, tired, k=1.3, extra=chief_extra(step, pose, tired))


# ---------- 아기 (32칸) ----------
def baby_lizard(step=0, pose=0, tired=0):
    def f(d0, C):
        d = D(d0)
        sy = (1 if step % 2 else 0) + tired * 2
        sk, dk, bl = (110, 170, 90), (70, 120, 64), (220, 214, 150)
        d.poly([(10, 24 + sy), (2, 29), (4, 30), (12, 27 + sy)], dk)
        for lx in (12, 18):
            d.rect(lx - 1 + (step % 2), 26 + sy, lx + 1 + (step % 2), 30, dk)
        d.ell(15, 22 + sy, 7, 6, sk); d.ell(17, 24 + sy, 4, 3, bl)
        d.ell(21, 15 + sy, 6, 5, sk)
        d.poly([(23, 15 + sy), (29, 16 + sy), (28, 18 + sy), (23, 18 + sy)], sk)
        d.rect(22, 13 + sy, 23, 14 + sy, INK); d.dot(23, 13 + sy, (255, 255, 255))
        # 냄비 뚜껑 방패
        d.ell(25, 24 + sy, 3.5, 5, (170, 176, 186)); d.dot(25, 24 + sy, (110, 110, 120), 1)
        if pose:
            d.line([(29, 17 + sy), (31, 17 + sy)], (240, 120, 140), 1)
    return f


def baby_newt(step=0, pose=0, tired=0):
    def f(d0, C):
        d = D(d0)
        sy = (1 if step % 2 else 0) + tired * 2
        sk, dk, gill = (246, 170, 186), (210, 120, 150), (240, 90, 130)
        d.poly([(9, 22 + sy), (1, 20 + sy + step % 2), (2, 25), (10, 26 + sy)], (190, 220, 240))  # 지느러미 꼬리
        for lx in (11, 19):
            d.rect(lx - 1, 25 + sy, lx + 1, 29, dk)
        d.ell(15, 23 + sy, 8, 5, sk)
        d.ell(22, 17 + sy, 7, 6, sk)
        for i in range(3):
            d.line([(17, 13 + sy + i * 3), (13, 11 + sy + i * 3)], gill, 2)
        d.rect(24, 15 + sy, 25, 16 + sy, INK); d.rect(19, 15 + sy, 20, 16 + sy, INK)
        d.line([(21, 20 + sy), (24, 20 + sy)], dk)
        if pose:
            d.line([(28, 18 + sy), (31, 16 + sy)], (130, 200, 250), 2)
    return f


def baby_chameleon(step=0, pose=0, tired=0):
    def f(d0, C):
        d = D(d0)
        sy = (1 if step % 2 else 0) + tired * 2
        sk = [(120, 190, 100), (110, 170, 200), (220, 150, 90)][step % 3]
        dk = (sk[0] - 40, sk[1] - 40, sk[2] - 40)
        d.ell(6, 24 + sy, 4, 4, dk); d.ell(6, 24 + sy, 2, 2, (0, 0, 0, 0))
        d.line([(9, 22 + sy), (12, 22 + sy)], dk, 2)
        for lx in (12, 19):
            d.rect(lx - 1, 25 + sy, lx + 1, 29, dk)
        d.ell(16, 21 + sy, 7, 5, sk)
        d.poly([(18, 14 + sy), (21, 9 + sy), (24, 14 + sy)], dk)
        d.ell(23, 17 + sy, 6, 5, sk)
        d.ell(24, 16 + sy, 3, 3, dk); d.ell(24.5, 16 + sy, 1.8, 1.8, EYE); d.dot(25, 16 + sy, INK)
        if pose:
            d.line([(28, 19 + sy), (31, 19 + sy)], (240, 120, 150), 2)
    return f


# ================= 소내섬: 와이번 · 용 =================
def wyvern(skin, dark, belly, wing, tip, kind="poison", step=0, pose=0, tired=0, k=1.0):
    def f(d0, C):
        d = brush(d0, C, k)
        sy = 2 * tired
        flap = [0, 1, 2, 1][step % 4] if not tired else 3
        if pose == 1 and kind == "poison":
            flap = 3  # 날개 접고 내리꽂기
        bob = (1 if step % 2 else 0)
        by = 22 + bob + sy + (6 if tired else 0)
        # 뒤 날개
        wy = [-14, -6, 4, 8][flap]
        d.poly([(22, by - 2), (14, by + wy), (6, by + wy + 3), (10, by + 2), (20, by + 4)], (wing[0] - 30, wing[1] - 30, wing[2] - 30))
        # 꼬리 + 가시
        d.poly([(16, by + 2), (6, by + 8), (2, by + 14), (4, by + 15), (10, by + 10), (18, by + 6)], dark)
        tc = POISON if kind == "poison" else (FIRE if kind == "fire" else BRONZE)
        d.poly([(1, by + 13), (3, by + 18), (6, by + 14)], tc)
        # 다리 (지치면 땅에 섬)
        legy = 46 if tired else by + 12
        for lx in (22, 27):
            d.line([(lx, by + 4), (lx - 1, legy)], dark, 2)
            d.line([(lx - 3, legy), (lx + 1, legy)], INK)
        # 몸통
        d.ell(24, by + 2, 9, 6, skin)
        d.ell(26, by + 4, 6, 3, belly)
        # 목 + 머리
        dive = pose == 1 and kind == "poison"
        hx, hy = (38, by + 6) if dive else (37, by - 8 + (4 if tired else 0))
        d.line([(30, by - 1), (hx - 2, hy + 1)], skin, 4)
        d.ell(hx, hy, 4, 3.5, skin)
        open_ = 3 if pose == 1 and kind != "poison" else 0
        d.poly([(hx + 1, hy - 2), (hx + 9, hy), (hx + 8, hy + 1), (hx + 1, hy + 1)], skin)
        d.poly([(hx + 1, hy + 1), (hx + 8, hy + 1 + open_), (hx + 7, hy + 3 + open_), (hx, hy + 3)], belly)
        d.poly([(hx - 3, hy - 2), (hx - 7, hy - 6), (hx - 2, hy - 4)], tip)  # 뿔
        if tired:
            d.line([(hx, hy - 1), (hx + 2, hy - 1)], INK)
        else:
            d.rect(hx + 1, hy - 2, hx + 2, hy - 1, (255, 90, 60) if pose == 1 else EYE)
        if open_:
            if kind == "fire":
                d.poly([(hx + 8, hy + 2), (47, hy - 3), (47, hy + 8)], FIRE)
                d.poly([(hx + 8, hy + 2), (47, hy), (47, hy + 5)], FIRE_L)
            else:
                d.poly([(hx + 1, hy + 1), (hx + 8, hy + 1), (hx + 8, hy + 1 + open_)], MOUTH)
        # 앞 날개
        wx, wy2 = 30 + [-8, -2, 4, 6][flap], by + [-18, -10, 2, 7][flap]
        mem = [(wx, wy2), (wx + 4, wy2 + 5), (wx + 9, wy2 + 4), (wx + 10, wy2 + 9), (wx + 14, wy2 + 10)] if flap < 2 else [(wx, wy2), (wx + 4, wy2 + 2), (wx + 6, wy2 + 6)]
        d.poly([(26, by - 3)] + mem + [(32, by + 1)], wing)
        d.line([(26, by - 3), (wx, wy2)], dark, 1)
        for mx, my in mem[1::2]:
            d.line([(wx, wy2), (mx, my)], dark)
    return f


def serpent(skin, dark, belly, mane, kind="blue", step=0, pose=0, tired=0, C64=True, k=1.0):
    """동양 용 (긴 뱀 몸, 사슴뿔, 수염, 여의주). kind: blue 청룡 / cloud 운룡."""
    def f(d0, C):
        d = D(d0, k, 0, (C - 1) - 60 * k if k > 1 else 0)
        sy = 3 * tired
        ph = step * 0.5
        # 몸: 왼쪽 아래 꼬리 → 물결 → 오른쪽 위 머리
        pts = []
        for i in range(26):
            t = i / 25
            x = 4 + t * 46
            y = 50 - t * 24 + math.sin(t * 8 + ph) * 8 + sy * (1 - t * 0.3)
            pts.append((x, y))
        if kind == "cloud":
            for i, (x, y) in enumerate(pts[::3]):
                d.ell(x + 2, y + 6, 6, 3, (236, 240, 250))
        for i, (x, y) in enumerate(pts):
            r = 1.5 + 3.6 * math.sin(min(1, i / 25 + 0.12) * math.pi * 0.9)
            d.ell(x, y, r, r, skin)
        for i, (x, y) in enumerate(pts):
            r = 1.5 + 3.6 * math.sin(min(1, i / 25 + 0.12) * math.pi * 0.9)
            d.ell(x, y + r * 0.55, r * 0.55, r * 0.3, belly)
            if i % 2 == 0 and i < 24:
                d.poly([(x - 1, y - r + 1), (x + 1, y - r - 3), (x + 3, y - r + 1)], mane)
        # 앞발 (여의주를 쥠)
        cx, cy = pts[17]
        d.line([(cx, cy + 3), (cx + 4, cy + 10)], skin, 2)
        orb = (210, 250, 255) if kind == "cloud" else (130, 230, 240)
        glow = pose == 1
        if glow:
            d.ell(cx + 5, cy + 12, 6, 6, (255, 255, 220))
        d.ell(cx + 5, cy + 12, 3.5, 3.5, orb); d.dot(cx + 4, cy + 11, (255, 255, 255))
        tx, ty = pts[4]
        d.line([(tx, ty + 3), (tx + 2, ty + 9)], skin, 2)
        # 꼬리 털
        d.poly([(pts[0][0] - 2, pts[0][1]), (pts[0][0] - 4, pts[0][1] - 6), (pts[0][0] + 3, pts[0][1] - 2)], mane)
        # 머리
        hx, hy = pts[-1][0] + 4, pts[-1][1] - 2 + (5 if tired else 0)
        d.ell(hx, hy, 6, 5, skin)
        op = 4 if pose == 1 else 0
        d.poly([(hx + 2, hy - 3), (hx + 12, hy - 1), (hx + 12, hy + 2), (hx + 2, hy + 2)], skin)
        d.poly([(hx + 2, hy + 2), (hx + 11, hy + 2 + op), (hx + 10, hy + 4 + op), (hx + 1, hy + 5)], belly)
        if op:
            d.poly([(hx + 3, hy + 2), (hx + 11, hy + 2), (hx + 11, hy + 2 + op)], MOUTH)
        # 사슴뿔
        for dx, c in ((-3, dark), (0, (236, 220, 170))):
            d.line([(hx + dx, hy - 4), (hx + dx - 3, hy - 12)], c, 1)
            d.line([(hx + dx - 2, hy - 9), (hx + dx + 1, hy - 12)], c, 1)
        # 갈기 · 수염
        d.poly([(hx - 5, hy - 2), (hx - 11, hy - 6), (hx - 9, hy + 1), (hx - 12, hy + 4), (hx - 4, hy + 3)], mane)
        d.line([(hx + 10, hy + 1), (hx + 14, hy + 6), (hx + 12, hy + 10)], (250, 236, 180), 1)
        if tired:
            d.line([(hx + 2, hy - 1), (hx + 5, hy - 1)], INK)
        else:
            d.rect(hx + 3, hy - 2, hx + 4, hy - 1, (255, 255, 200) if glow else EYE)
    return f


GOLD_COLS = ((220, 172, 64), (160, 112, 40), (250, 226, 140), (150, 90, 50), (190, 120, 60), (90, 60, 40))
## 일반 용 (소내섬 기본 대장): 잿빛 청록 비늘, 보물 더미 없음
PLAIN_COLS = ((104, 126, 120), (60, 80, 80), (196, 200, 170), (92, 104, 118), (124, 140, 150), (230, 222, 196))


def bat_wing(d, root, tip, back, col, bone, membrane):
    """박쥐 날개: 어깨 root → 손목 tip (팔뼈), 손가락 셋이 back 쪽으로 펼쳐지고 그 사이 막은 오목하게 처짐."""
    fingers = [tip.__class__((tip[0] + (back[0] - tip[0]) * t + (6 if 0 < t < 1 else 0) * (1 - t), tip[1] + (back[1] - tip[1]) * t + 10 * math.sin(t * math.pi))) for t in (0.0, 0.35, 0.7, 1.0)]
    pts = [root, tip]
    for a, b in zip(fingers, fingers[1:]):
        mid = ((a[0] + b[0]) / 2 - 2, (a[1] + b[1]) / 2 - 3)
        pts += [mid, b]
    d.poly(pts, membrane)
    d.line([root, tip], bone, 2)
    for fpt in fingers[1:]:
        d.line([tip, fpt], col, 1)


def golden_dragon(step=0, pose=0, tired=0, cols=GOLD_COLS, hoard=True, k=1.0):
    def f(d0, C):
        d = D(d0, k, (C - 64 * k) / 2, (C - 1) - 63 * k + (0 if hoard else 3 * k))
        b = 63
        sy = 2 * tired + (1 if step % 2 else 0)
        G, GD, GL, WING_B, WING_F, HORN_C = cols
        if hoard:
            # 보물 더미
            d.ell(32, b - 2, 24, 4, (240, 200, 70))
            for x, y in ((14, b - 3), (22, b - 5), (40, b - 4), (49, b - 2), (30, b - 6)):
                d.ell(x, y, 2.5, 1.5, (255, 236, 130))
        # 뒤 날개
        flap = [0, 1, 2, 1][step % 4] if not tired else 2
        wy = [-20, -12, -4, -12][flap]
        bat_wing(d, (28, 30 + sy), (16, 4 + wy + 14 + sy), (10, 34 + sy), GD, GD, WING_B)
        # 꼬리
        d.poly([(16, 44 + sy), (4, 52), (1, 58), (5, 58), (18, 50 + sy)], GD)
        d.poly([(0, 56), (2, 61), (6, 57)], GD)
        # 다리
        for i, lx in enumerate((20, 26, 38, 44)):
            c = GD if i in (0, 2) else G
            d.ell(lx, 46 + sy, 5, 6, c)
            d.poly([(lx - 2, 48 + sy), (lx + 3, 48 + sy), (lx + 3, b - 5), (lx - 2, b - 5)], c)
            d.rect(lx - 2, b - 6, lx + 5, b - 4, INK)
            d.dot(lx + 5, b - 5, TEETH)
        d.ell(32, 43 + sy, 16, 9, G)
        d.ell(34, 47 + sy, 11, 4, GL)
        # 목 + 머리
        hx, hy = 50, 20 + sy + (8 if tired else 0)
        d.line([(40, 36 + sy), (hx - 2, hy + 2)], G, 6)
        for t in range(3):
            d.line([(41 + t * 3, 34 + sy - t * 4), (43 + t * 3, 33 + sy - t * 4)], GL, 2)
        d.ell(hx, hy, 6, 5, G)
        op = 5 if pose == 1 else 0
        d.poly([(hx + 2, hy - 3), (hx + 13, hy), (hx + 12, hy + 2), (hx + 2, hy + 2)], G)
        d.poly([(hx + 2, hy + 2), (hx + 12, hy + 2 + op), (hx + 11, hy + 4 + op), (hx + 1, hy + 5)], GL)
        if op:
            d.poly([(hx + 12, hy + 3), (63, hy - 2), (63, hy + 12)], FIRE)
            d.poly([(hx + 12, hy + 3), (63, hy + 2), (63, hy + 7)], FIRE_L)
        for dx in (-3, 1):
            d.poly([(hx + dx, hy - 4), (hx + dx - 5, hy - 13), (hx + dx + 2, hy - 5)], HORN_C)
        if tired:
            d.line([(hx + 2, hy - 1), (hx + 5, hy - 1)], INK)
        else:
            d.rect(hx + 3, hy - 2, hx + 4, hy - 1, (255, 80, 40) if pose == 1 else (90, 220, 120))
        # 앞 날개
        bat_wing(d, (34, 31 + sy), (30 + [-4, 0, 6, 0][flap], 2 + [0, 8, 18, 8][flap]), (22, 34 + sy), GD, GD, WING_F)
        # 등 가시
        for x in range(18, 44, 4):
            d.poly([(x, 35 + sy), (x + 2, 31 + sy), (x + 4, 35 + sy)], GD)
    return f


def baby_dragon_blue(step=0, pose=0, tired=0):
    return serpent((80, 170, 170), (40, 110, 120), (240, 230, 170), (90, 210, 200), "blue", step, pose, tired, k=0.55)


def baby_wyvern(step=0, pose=0, tired=0):
    def f(d0, C):
        sub = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        wyvern((96, 160, 124), (56, 108, 88), (220, 222, 170), (128, 188, 146), (236, 236, 196), "poison", step, pose, tired)(ImageDraw.Draw(sub), 48)
        sm = sub.resize((32, 32), Image.NEAREST)
        d0._image.paste(sm, (0, 0), sm)
    return f


def baby_gold(step=0, pose=0, tired=0):
    def f(d0, C):
        d = D(d0)
        sy = (1 if step % 2 else 0) + tired * 2
        G, GD, GL = (230, 184, 74), (170, 120, 48), (252, 232, 150)
        flap = step % 2
        d.poly([(13, 18 + sy), (6, 8 + sy + flap * 4), (4, 16 + sy), (11, 22 + sy)], (190, 120, 60))
        d.poly([(9, 24 + sy), (2, 28), (5, 29), (11, 27 + sy)], GD)
        for lx in (11, 19):
            d.rect(lx - 2, 25 + sy, lx + 2, 29, GD)
        d.ell(15, 22 + sy, 8, 6, G); d.ell(16, 24 + sy, 5, 3, GL)
        d.ell(22, 15 + sy, 6, 5, G)
        d.poly([(24, 15 + sy), (30, 16 + sy), (29, 19 + sy), (24, 19 + sy)], G)
        d.poly([(19, 11 + sy), (16, 5 + sy), (21, 10 + sy)], (110, 70, 40))
        d.rect(23, 13 + sy, 24, 14 + sy, INK)
        if pose:
            d.ell(31, 18 + sy, 1.5, 1.5, FIRE)
    return f


def frames8(mk):
    return [mk(), mk(step=1), mk(step=1), mk(step=2), mk(step=3), mk(step=0), mk(pose=1), mk(tired=1, pose=2)]


def frames10(mk):
    return [mk(), mk(step=1), mk(step=1), mk(step=2), mk(step=3), mk(), mk(pose=1), mk(step=2), mk(pose=1), mk()]


def baby_cloud_dragon(step=0, pose=0, tired=0):
    return serpent((226, 230, 240), (150, 160, 190), (252, 248, 226), (180, 200, 240), "cloud", step, pose, tired, k=0.55)


DK = 1.5
WY = ((80, 140, 110), (50, 96, 80), (210, 214, 160), (110, 170, 130), (230, 230, 190))
GL_ = ((88, 140, 76), (56, 98, 58), (214, 206, 146))
out = {
    # 귀여리 (임시: 추천 A 방패 도마뱀 + 족장, 사용자가 고르면 그 안으로 다시 만듦)
    "wild_shield_lizard": sheet(frames8(lambda **k: lizard(*GL_, "shield", **k)), 48),
    "wild_lizard_chief": sheet(frames8(lambda **k: chieftain(**k)), 64),
    "baby_lizard": sheet(frames10(lambda **k: baby_lizard(**k)), 32),
    # 소내섬 (2026-10-03): 독꼬리 와이번 · 일반 용 + 희귀 용 셋 · 아기
    "wild_wyvern": sheet(frames8(lambda **k: wyvern(*WY, "poison", **k)), 48),
    "wild_dragon": sheet(frames8(lambda **k: golden_dragon(cols=PLAIN_COLS, hoard=False, k=DK, **k)), 96),
    "wild_blue_dragon": sheet(frames8(lambda **k: serpent((64, 150, 160), (34, 96, 110), (240, 228, 170), (80, 200, 190), "blue", k=DK, **k)), 96),
    "wild_cloud_dragon": sheet(frames8(lambda **k: serpent((222, 226, 236), (150, 156, 180), (250, 246, 220), (180, 200, 240), "cloud", k=DK, **k)), 96),
    "wild_gold_dragon": sheet(frames8(lambda **k: golden_dragon(k=DK, **k)), 96),
    "baby_wyvern": sheet(frames10(lambda **k: baby_wyvern(**k)), 32),
    "baby_blue_dragon": sheet(frames10(lambda **k: baby_dragon_blue(**k)), 32),
    "baby_cloud_dragon": sheet(frames10(lambda **k: baby_cloud_dragon(**k)), 32),
    "baby_gold_dragon": sheet(frames10(lambda **k: baby_gold(**k)), 32),
}
for k, img in out.items():
    img.save(os.path.join(OUT, k + ".png"))
ims = [img.resize((img.width * 2, img.height * 2), Image.NEAREST) for img in out.values()]
pv = Image.new("RGBA", (max(i.width for i in ims), sum(i.height + 6 for i in ims)), (70, 76, 80, 255))
y = 0
for i in ims:
    pv.alpha_composite(i, (0, y)); y += i.height + 6
pv.save(os.path.join(os.environ.get("PREVIEW", "/tmp"), "act5_sheet_x2.png"))
print("ok")
