"""마을 배경 오브젝트 (농부 집 · 나무 · 밭 울타리) 임시 스프라이트 생성기.

코드로 그린 임시 그림이다. 최종 아트는 같은 크기의 PNG로 파일만 바꾸면 된다.
2026-09-27 결정: 집 B (파란 지붕 시골 양옥) · 나무 A 감나무 여러 그루 + C 당산나무 한 그루 · 울타리 A 나무 말뚝.
  props/house.png           120 x 114  파란 지붕 양옥, 5x4칸
  props/tree_persimmon.png   48 x 72   감나무, 밑동 1칸
  props/tree_dangsan.png     96 x 96   마을 당산나무 (느티나무, 오색 천·금줄), 밑동 2x2칸
  tiles/fence.png           384 x 24   나무 말뚝 울타리, 칸 24x24, 열 = 이웃 연결 비트 (위1 오른2 아래4 왼8)
집·나무는 그림 맨 아래 줄이 차지하는 칸의 아래 끝(땅). 발밑 그림자는 넣지 않는다 (게임이 그림).

실행: python3 tools/make_village_bg.py  (Pillow 필요)
"""
import math
import os
import random

from PIL import Image, ImageDraw

from make_character_sheet import grade_p1, outline

ASSETS = os.path.join(os.path.dirname(__file__), "..", "assets")

WOOD, WOOD_D, WOOD_DD, WOOD_L = (176, 128, 86), (140, 98, 68), (110, 76, 56), (206, 160, 112)
CREAM, CREAM_D, CREAM_L = (240, 234, 218), (206, 196, 180), (252, 248, 238)
PINK, PINK_D = (238, 212, 196), (208, 178, 166)
BLUE, BLUE_D, BLUE_L = (96, 140, 196), (70, 106, 160), (140, 180, 226)
GREEN_R, GREEN_R_D, GREEN_R_L = (96, 160, 110), (70, 126, 90), (136, 196, 140)
METAL, METAL_D, METAL_L = (150, 156, 166), (112, 116, 130), (196, 200, 210)
GLASS, GLASS_D, GLASS_L = (150, 196, 212), (110, 150, 176), (220, 240, 246)
CONC, CONC_D, CONC_L = (186, 182, 176), (150, 146, 142), (210, 206, 200)
GIWA, GIWA_D, GIWA_L = (98, 104, 118), (72, 76, 92), (140, 146, 160)
HANJI, HANJI_D = (246, 238, 214), (214, 200, 170)
ONGGI, ONGGI_D, ONGGI_L = (124, 78, 58), (96, 58, 46), (168, 112, 84)
BARK, BARK_D, BARK_L = (120, 88, 70), (90, 66, 58), (156, 118, 88)
PINE_BARK, PINE_BARK_D = (170, 100, 78), (130, 76, 64)
LEAF, LEAF_D, LEAF_DD, LEAF_L = (104, 160, 92), (78, 132, 80), (58, 104, 72), (150, 196, 112)
PINE, PINE_D, PINE_L = (70, 128, 96), (50, 98, 80), (104, 158, 112)
ZEL, ZEL_D, ZEL_L = (116, 170, 96), (86, 140, 84), (164, 206, 120)
PERSIMMON, PERSIMMON_L = (240, 136, 60), (255, 190, 110)
STONE, STONE_D, STONE_L = (168, 164, 160), (128, 124, 128), (204, 200, 194)
NET, NET_D = (98, 170, 120), (70, 136, 100)
POLE_G, POLE_G_D = (84, 146, 104), (60, 110, 84)
ROPE, ROPE_D = (214, 186, 130), (176, 146, 96)
PAPER = (250, 248, 240)
RIBBONS = [(222, 82, 72), (246, 206, 70), (96, 140, 196), (120, 180, 110), (246, 244, 238)]
GLOW = (255, 240, 170)
SOLAR, SOLAR_L = (60, 76, 120), (110, 130, 180)
RED, RED_D = (214, 82, 70), (168, 58, 58)


class C:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.w, self.h = w, h

    def rect(self, x0, y0, x1, y1, c):
        self.d.rectangle((x0, y0, x1, y1), fill=c)

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), (*c[:3], 255))

    def ell(self, x0, y0, x1, y1, c):
        self.d.ellipse((x0, y0, x1, y1), fill=c)

    def poly(self, pts, c):
        self.d.polygon(pts, fill=c)

    def line(self, x0, y0, x1, y1, c, w=1):
        self.d.line((x0, y0, x1, y1), fill=c, width=w)

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)


def finish(img):
    grade_p1(img)
    outline(img, cell=max(img.size) + 2)
    return img


# ---------------------------------------------------------------- 집

def window(c, x0, y0, w, h, grid=True):
    """알루미늄 창틀 + 유리 + 방범창."""
    c.rect(x0 - 1, y0 - 1, x0 + w, y0 + h, METAL_D)
    c.rect(x0, y0, x0 + w - 1, y0 + h - 1, GLASS)
    c.hline(x0, x0 + w - 1, y0, GLASS_L)
    c.vline(x0 + w // 2, y0, y0 + h - 1, METAL)
    if grid:
        for x in range(x0 + 2, x0 + w, 3):
            c.vline(x, y0, y0 + h - 1, METAL_L)
    c.hline(x0 - 2, x0 + w + 1, y0 + h + 1, CONC_L)


def onggi(c, cx, by, r=4, h=7):
    c.ell(cx - r, by - h, cx + r, by, ONGGI)
    c.rect(cx - r + 1, by - h - 1, cx + r - 1, by - h + 1, ONGGI_D)
    c.hline(cx - r + 2, cx + r - 2, by - h - 1, ONGGI_L)
    c.px(cx - r + 1, by - h + 3, ONGGI_L)
    c.px(cx - r + 1, by - h + 4, ONGGI_L)


def house_b():
    """파란 지붕 시골 양옥 (5x4칸). 70~80년대에 지어 지금도 흔한 시골집. 120x104로 그린 뒤 벽을 10px 높인다."""
    c = C(120, 104)
    # 우진각 지붕: 앞쪽이 넓은 사다리꼴, 파란 골함석
    top_l, top_r, top_y = 22, 97, 6
    eave_l, eave_r, eave_y = 1, 118, 52
    c.poly([(top_l, top_y), (top_r, top_y), (eave_r, eave_y), (eave_l, eave_y)], BLUE)
    for x in range(0, 120, 4):
        # 골 무늬: 지붕 경사를 따라 가운데로 모이는 선
        t = (x - 60) / 60
        c.line(60 + t * 38, top_y + 1, x, eave_y - 1, BLUE_L)
        c.line(60 + t * 38 + 1, top_y + 1, x + 2, eave_y - 1, BLUE_D)
    c.hline(top_l, top_r, top_y, BLUE_L)
    c.hline(top_l - 1, top_r + 1, top_y + 1, BLUE_L)
    c.rect(eave_l, eave_y, eave_r, eave_y + 3, BLUE_D)
    c.hline(eave_l, eave_r, eave_y, BLUE_L)
    # 굴뚝 (연통)
    c.rect(86, 0, 89, 22, METAL)
    c.vline(89, 0, 22, METAL_D)
    c.rect(85, 0, 90, 2, METAL_D)
    # 벽 (분홍빛 미장) + 시멘트 밑단
    c.rect(6, 56, 113, 97, PINK)
    for y in range(58, 96, 5):
        for x in range(7 + (y % 3), 113, 9):
            c.px(x, y, PINK_D)
    c.rect(6, 56, 113, 58, PINK_D)
    c.rect(4, 94, 115, 101, CONC)
    c.hline(4, 115, 94, CONC_L)
    c.rect(2, 101, 117, 103, CONC_D)
    # 창 두 개
    window(c, 14, 64, 20, 14)
    window(c, 84, 64, 20, 14)
    # 현관: 알루미늄 두 짝 문 + 작은 차양
    c.rect(46, 60, 73, 63, GREEN_R_D)
    c.hline(45, 74, 60, GREEN_R_L)
    c.rect(49, 64, 70, 93, METAL_D)
    c.rect(50, 65, 59, 93, GLASS)
    c.rect(60, 65, 69, 93, GLASS)
    for y in (72, 80):
        c.hline(50, 69, y, METAL)
    c.hline(50, 69, 65, GLASS_L)
    c.px(58, 82, METAL_L)
    c.px(61, 82, METAL_L)
    # 현관 계단
    c.rect(44, 97, 75, 103, CONC_L)
    c.hline(44, 75, 100, CONC)
    # 장독대 (오른쪽 앞)
    onggi(c, 101, 100, 4, 7)
    onggi(c, 110, 101, 3, 6)
    # 문패
    c.rect(78, 70, 81, 74, WOOD_L)
    return finish(c.img)


WHITE_EDGE = (252, 250, 244)

# ---------------------------------------------------------------- 나무


def blob_crown(c, cx, cy, rx, ry, cols, seed, n=26, fruit=None, fruit_n=0):
    """잎 무더기: 어두운 바탕 → 중간 → 왼쪽 위 밝은 잎."""
    rng = random.Random(seed)
    dark, mid, light = cols
    c.ell(cx - rx, cy - ry, cx + rx, cy + ry, dark)
    for _ in range(n):
        a, r = rng.uniform(0, 6.283), rng.uniform(0.2, 0.95)
        x = cx + math.cos(a) * rx * r
        y = cy + math.sin(a) * ry * r
        s = rng.randint(4, 7)
        col = mid if (x - cx) * 0.6 + (y - cy) > -ry * 0.25 else light
        c.ell(x - s, y - s + 1, x + s, y + s - 1, col)
    for _ in range(n // 2):
        a, r = rng.uniform(3.4, 5.2), rng.uniform(0.3, 0.8)
        x = cx + math.cos(a) * rx * r
        y = cy + math.sin(a) * ry * r
        c.ell(x - 3, y - 2, x + 3, y + 2, light)
    if fruit:
        for _ in range(fruit_n):
            a, r = rng.uniform(0, 6.283), rng.uniform(0.3, 0.85)
            x = int(cx + math.cos(a) * rx * r)
            y = int(cy + math.sin(a) * ry * r)
            c.rect(x, y, x + 1, y + 1, fruit)
            c.px(x, y, PERSIMMON_L)


def tree_a():
    """감나무 (그림 48x72, 차지하는 칸 1x1). 가을 시골 마당의 상징, 주황 감."""
    c = C(48, 72)
    # 줄기와 가지
    c.rect(21, 44, 26, 71, BARK)
    c.vline(21, 44, 71, BARK_L)
    c.vline(26, 44, 71, BARK_D)
    c.rect(19, 68, 28, 71, BARK)
    c.line(23, 50, 12, 36, BARK, 3)
    c.line(25, 48, 36, 34, BARK, 3)
    blob_crown(c, 24, 26, 22, 22, (LEAF_DD, LEAF_D, LEAF), 3, n=30, fruit=PERSIMMON, fruit_n=11)
    return finish(c.img)


def tree_c():
    """마을 당산나무 (느티나무, 그림 96x96, 칸 2x2). 오색 천과 금줄, 반딧불 같은 빛."""
    c = C(96, 96)
    # 굵은 줄기 + 뿌리
    c.poly([(38, 95), (58, 95), (54, 56), (42, 56)], BARK)
    c.poly([(30, 95), (40, 88), (42, 95)], BARK)
    c.poly([(66, 95), (56, 88), (54, 95)], BARK)
    c.vline(42, 58, 94, BARK_L)
    c.vline(55, 58, 94, BARK_D)
    c.line(47, 64, 22, 40, BARK, 4)
    c.line(49, 62, 74, 38, BARK, 4)
    blob_crown(c, 48, 34, 46, 30, (LEAF_DD, ZEL_D, ZEL), 7, n=60)
    # 오색 천 (가지 끝에 묶인 천 조각)
    rng = random.Random(9)
    for i in range(7):
        x = rng.randint(10, 84)
        y = rng.randint(46, 60)
        col = RIBBONS[i % len(RIBBONS)]
        c.rect(x, y, x + 1, y + 5, col)
    # 금줄 (새끼줄 + 흰 종이)
    for x in range(38, 59):
        y = 74 + (1 if 44 < x < 52 else 0)
        c.px(x, y, ROPE)
        c.px(x, y + 1, ROPE_D)
    for x in (41, 47, 53):
        c.rect(x, 76, x + 2, 80, PAPER)
    # 돌 제단
    c.rect(34, 90, 62, 95, STONE)
    c.hline(34, 62, 90, STONE_L)
    # 반딧불 같은 빛 (판타지)
    for (x, y) in ((16, 20), (80, 26), (30, 52), (70, 50), (60, 12)):
        c.px(x, y, GLOW)
        c.px(x + 1, y, (255, 255, 220))
    return finish(c.img)


# ---------------------------------------------------------------- 울타리 (16칸 autotile)

GROUND_Y = 18  # 칸 안에서 기둥 발 위치
UP, RIGHT, DOWN, LEFT = 1, 2, 4, 8


def fence_row():
    img = Image.new("RGBA", (24 * 16, 24), (0, 0, 0, 0))
    for mask in range(16):
        c = C(24, 24)
        fence_a(c, mask)
        grade_p1(c.img)
        outline(c.img, cell=26)
        img.paste(c.img, (mask * 24, 0), c.img)
    return img


def fence_a(c, m):
    """나무 말뚝 + 가로대 두 줄. 높이 14."""
    H = 14
    top = GROUND_Y - H
    # 세로로 이어지는 쪽은 위에서 본 가로대 (가는 띠)
    if m & UP:
        c.rect(11, 0, 12, top + 1, WOOD_D)
        c.vline(11, 0, top, WOOD_L)
    if m & DOWN:
        c.rect(11, GROUND_Y - 4, 12, 23, WOOD_D)
        c.vline(11, GROUND_Y - 4, 23, WOOD_L)
    for (y, on) in ((top + 3, True), (top + 9, True)):
        x0 = 0 if m & LEFT else 11
        x1 = 23 if m & RIGHT else 12
        if x0 != 11 or x1 != 12:
            c.rect(x0, y, x1, y + 1, WOOD)
            c.hline(x0, x1, y, WOOD_L)
    c.rect(10, top, 13, GROUND_Y, WOOD_D)
    c.rect(10, top, 12, GROUND_Y, WOOD)
    c.hline(10, 13, top, WOOD_L)
    c.px(10, GROUND_Y, BARK_D)


def stretch(img, y0, y1, times):
    """y0..y1 줄 묶음을 times번 더 끼워 넣어 벽을 높인다 (문 높이를 캐릭터에 맞춤)."""
    band = img.crop((0, y0, img.width, y1 + 1))
    out = Image.new("RGBA", (img.width, img.height + band.height * times))
    out.paste(img.crop((0, 0, img.width, y1 + 1)), (0, 0))
    for i in range(times):
        out.paste(band, (0, y1 + 1 + band.height * i))
    out.paste(img.crop((0, y1 + 1, img.width, img.height)), (0, y1 + 1 + band.height * times))
    return out


# 벽 높이기: (시작 줄, 끝 줄, 반복 수)

def main():
    out = {
        "props/house.png": stretch(house_b(), 84, 88, 2),
        "props/tree_persimmon.png": tree_a(),
        "props/tree_dangsan.png": tree_c(),
        "tiles/fence.png": fence_row(),
    }
    for path, img in out.items():
        img.save(os.path.join(ASSETS, path))
        print(path, img.size)


if __name__ == "__main__":
    main()
