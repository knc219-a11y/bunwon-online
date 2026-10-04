"""역동(4막 첫 구역) 임시 스프라이트 시트 생성기 (2026-10-02 사용자 선택 A 켄타우로스 창기병 + 역마 장군 → 아기 망아지).

역동 = 광주시 驛洞 (옛 경안역 역참, 역마). 사용자: "역동에는 말이 유명하니 켄타우로스 같은 것으로".
코드로 그린 임시 그림이다. 규격 (32x32 칸, 방향 없음, 앞이 오른쪽, 발바닥 y=30~31):
  몬스터 (384 x 48, 창기병은 사람보다 커 보이게 48칸 1:1): 0-1 대기, 2-5 이동, 6 예고 (앞발 들고 발 구름), 7 돌격 뒤 돌아섬 (때릴 틈)
  대장 (256 x 32, 게임이 정수 2배): 칸은 몬스터와 같음
  크리처 (320 x 32): 0-1 대기, 2-5 이동, 6-9 일 (앞발 들기 · 뒷발차기)
  wild_lancer.png: 켄타우로스 창기병 (밤색 말, 전립, 창, 붉게 빛나는 눈)
  wild_post_general.png: 역마 장군 (붉은 갑옷 · 금빛 전립, 게임이 대장 배율 정수 2배로 그림)
  baby_foal.png: 아기 망아지 (땅)
궁수 · 불갈기 역마 후보 그림은 프로젝트 파일 design/act4/ 에만 남김.

2026-10-04 새 크기 AI 그림으로 바뀐 시트 (AI_DONE) 는 --force 일 때만 assets 에 쓴다.
실행: python3 tools/make_yeokdong_sheets.py [--preview 파일] [--force]  (Pillow 필요)
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_character_sheet import grade_p1, outline
from make_slime_sheet import CELL, Layer

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "creatures")

INK = (36, 30, 44)
WHITE = (250, 246, 236)
SKIN = (232, 186, 150); SKIN_D = (196, 140, 110)


def ell(l, cx, cy, rx, ry, c, dark=None, split=0.35):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                l.px(x, y, dark if dark and y > cy + ry * split else c)


def line(l, x0, y0, x1, y1, c):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / n
        l.px(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c)


def horse(l, body, dark, mane, bx=13, by=21, s=1.0, step=0, rear=0, tired=0, lift=0, eye=INK, head=True, flame=None, baby=False, base=30):
    by = by - lift + tired * 2
    base = base - lift
    legs = (bx - 6 * s, bx - 3.5 * s, bx + 4 * s, bx + 6.5 * s)
    for i, lx in enumerate(legs):
        off = (step if i % 2 else -step) * 0.8
        top = by + 2
        if rear and i >= 2:
            line(l, lx, top, lx + 2 + off, top + 4 - rear * 2, dark)
            continue
        l.rect(lx + off, top, lx + off + 1, base, dark)
        l.px(lx + off, base, INK); l.px(lx + off + 1, base, INK)
    ell(l, bx, by, 8.5 * s, 4.2 * s - tired * 0.5, body, dark, 0.35)
    # 꼬리
    tc = flame or mane
    for k in range(int(6 * s)):
        l.rect(bx - 8.5 * s - k * 0.6, by - 2 + k * 0.9 - (step % 2) * 0.5, bx - 8.5 * s - k * 0.6 + 1, by - 1 + k * 0.9, tc)
    if head:
        # 목 + 말머리 (사람 몸 없는 말)
        hx, hy = bx + 8 * s, by - 6 * s - rear * 2 + tired * 3
        if baby:
            hy += 1
        line(l, bx + 5 * s, by - 2, hx, hy + 2, body); line(l, bx + 6 * s, by - 1, hx + 1, hy + 3, body)
        line(l, bx + 4 * s, by - 3, hx - 1, hy + 1, body)
        hr = 3.0 * s * (1.3 if baby else 1)
        ell(l, hx, hy, hr, hr * 0.8, body)
        ell(l, hx + hr * 1.1, hy + 1, hr * 0.7, hr * 0.55, dark)
        l.px(hx + hr * 1.6, hy + 1, INK)
        l.rect(hx - 1, hy - hr - 1, hx - 1, hy - hr + 1, body)
        l.rect(hx, hy - 1, hx + 1, hy - 1, eye if not tired else INK)
        mc = flame or mane
        for k in range(5):
            l.rect(hx - 2 - k * 0.8, hy - 2 + k * 1.2, hx - 1 - k * 0.8, hy - 1 + k * 1.2, mc)
        if flame:
            for k in range(3):
                l.px(hx - 3 - k, hy - 3 - (k + step) % 2, (255, 230, 120))


def rider(l, bx, by, s, skin, armor, hat, weapon, step=0, rear=0, tired=0, pose=0, eye=INK, lift=0):
    """사람 윗몸: 말 몸 앞쪽에서 솟음. pose 0 보통 / 1 예고 (무기를 뒤로) / 2 공격 뒤."""
    by = by - lift + tired * 2
    tx, ty = bx + 5 * s, by - 3 - rear * 2
    top = ty - 9 * s
    l.rect(tx - 2.5 * s, top + 3, tx + 2.5 * s, ty, armor)
    l.rect(tx - 2.5 * s, ty - 1, tx + 2.5 * s, ty, INK)
    hx, hy = tx + 0.5, top + tired * 1
    ell(l, hx, hy, 2.6 * s, 2.6 * s, skin)
    l.rect(hx + 1, hy - 1, hx + 1, hy, eye if not tired else INK)
    hat(l, hx, hy, s)
    weapon(l, tx, top, ty, s, pose)


def jeollip(col, plume):
    def f(l, hx, hy, s):
        l.rect(hx - 4 * s, hy - 2 * s, hx + 4 * s, hy - 2 * s, col)
        ell(l, hx, hy - 3 * s, 2.4 * s, 1.6 * s, col)
        l.px(hx, hy - 5 * s, plume); l.px(hx + 1, hy - 5 * s, plume); l.px(hx, hy - 6 * s, plume)
    return f


def crown(col):
    def f(l, hx, hy, s):
        l.rect(hx - 2 * s, hy - 3 * s, hx + 2 * s, hy - 2 * s, col)
        for dx in (-2, 0, 2):
            l.px(hx + dx * s, hy - 4 * s, col)
    return f


def horns(col):
    def f(l, hx, hy, s):
        line(l, hx - 2, hy - 2, hx - 4, hy - 6 * s, col); line(l, hx + 1, hy - 2, hx + 3, hy - 6 * s, col)
        for k in range(4):
            l.px(hx - 2 - k, hy - 1 + k * 0.3, (60, 40, 30))
    return f


def spear(col, tip):
    def f(l, tx, top, ty, s, pose):
        if pose == 1:
            line(l, tx - 8 * s, top + 1, tx + 6 * s, top + 7 * s, col); l.rect(tx - 10 * s, top, tx - 9 * s + 1, top + 1, tip)
        else:
            reach = 1 if pose == 2 else 0
            line(l, tx - 4 * s, top + 7 * s, tx + (12 + reach) * s, top + 4 * s, col)
            l.rect(tx + (12 + reach) * s, top + 4 * s - 1, tx + (14 + reach) * s, top + 4 * s, tip)
        l.rect(tx + 2 * s, top + 5 * s, tx + 3 * s, top + 6 * s, SKIN)
    return f


def bow(col, string):
    def f(l, tx, top, ty, s, pose):
        x = tx + 5
        for k in range(-5, 6):
            l.px(x + (2 - abs(k) * 0.4), top + 5 + k, col)
        pull = 3 if pose == 1 else 0
        line(l, x - pull, top + 0, x - pull, top + 10, string) if pose == 1 else line(l, x - 1, top, x - 1, top + 10, string)
        if pose == 1:
            line(l, x - 4, top + 5, x + 5, top + 5, (200, 180, 140)); l.px(x + 6, top + 5, (220, 220, 230))
        l.rect(tx + 2, top + 5, tx + 4, top + 5, SKIN)
    return f


def horn_staff(col, tip):
    def f(l, tx, top, ty, s, pose):
        if pose == 1:
            ell(l, tx + 3, top + 2, 2, 1.5, (240, 230, 200)); l.px(tx + 5, top + 1, (180, 120, 80))
        line(l, tx + 5, top - 2, tx + 5, ty + 2, col); l.rect(tx + 4, top - 4, tx + 6, top - 2, tip)
    return f


class BigLayer(Layer):
    """칸 크기를 고를 수 있는 Layer (창기병 44칸)"""
    def __init__(self, cell):
        self.cell = cell
        self.img = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        self.p = self.img.load()

    def px(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.cell and 0 <= y < self.cell:
            self.p[x, y] = (*c, 255)


def sheet(draws, cell=CELL):
    img = Image.new("RGBA", (cell * len(draws), cell), (0, 0, 0, 0))
    for i, d in enumerate(draws):
        l = BigLayer(cell); d(l); img.alpha_composite(l.img, (i * cell, 0))
    outline(img, cell); grade_p1(img)
    return img


def centaur(pal, s=1.0, eye=INK, bx=13, by=21, base=30, **w):
    body, dark, mane = pal

    def fr(step=0, rear=0, tired=0, pose=0, lift=0):
        def d(l):
            horse(l, body, dark, mane, bx=bx, by=by, s=s, step=step, rear=rear, tired=tired, lift=lift, head=False, base=base)
            rider(l, bx, by, s, w['skin'], w['armor'], w['hat'], w['weapon'], step=step, rear=rear, tired=tired, pose=pose, eye=eye, lift=lift)
        return d
    return [fr(), fr(lift=1), fr(step=1), fr(step=2), fr(step=1), fr(), fr(rear=1, pose=1), fr(tired=1, pose=2)]


def steed(pal, s=1.0, eye=INK, flame=None):
    body, dark, mane = pal
    f = lambda **k: (lambda l: horse(l, body, dark, mane, s=s, eye=eye, flame=flame, **k))
    return [f(), f(lift=1), f(step=1), f(step=2), f(step=1), f(), f(rear=1), f(tired=1)]


def foal(pal, eye=INK, flame=None, rider_w=None):
    body, dark, mane = pal
    s = 0.7

    def fr(**k):
        def d(l):
            horse(l, body, dark, mane, bx=14, by=24, s=s, eye=eye, flame=flame, baby=True, head=rider_w is None, **{x: v for x, v in k.items() if x != 'pose'})
            if rider_w:
                rider(l, 14, 24, s * 1.2, SKIN, rider_w['armor'], rider_w['hat'], rider_w['weapon'], eye=eye, pose=k.get('pose', 0), **{x: v for x, v in k.items() if x in ('step', 'rear', 'tired', 'lift')})
        return d
    return [fr(), fr(lift=1), fr(step=1), fr(step=2), fr(step=1), fr(), fr(rear=1, pose=1), fr(step=2), fr(rear=1, pose=1), fr()]


BAY = ((128, 78, 50), (86, 50, 34), (40, 30, 28))
GLOW = (255, 120, 80)
GOLD = (236, 196, 84)


AI_DONE = {"wild_post_general", "wild_lancer", "baby_foal"}


def make():
    out = {
        "wild_lancer": sheet(centaur(BAY, s=1.35, bx=19, by=35, base=46, eye=GLOW, skin=(170, 150, 140), armor=(120, 60, 50), hat=jeollip((40, 36, 44), (220, 60, 50)), weapon=spear((150, 110, 70), (220, 220, 230))), cell=48),
        "wild_post_general": sheet(centaur(((96, 60, 44), (60, 36, 30), (30, 24, 24)), eye=GLOW, skin=(170, 150, 140), armor=(170, 52, 44), hat=jeollip(GOLD, (230, 60, 50)), weapon=spear((120, 80, 50), GOLD))),
        "baby_foal": sheet(foal(((176, 116, 70), (130, 80, 50), (70, 50, 40)))),
    }
    os.makedirs(OUT, exist_ok=True)
    for k, img in out.items():
        # 2026-10-04: 사용자 AI 그림 (새 크기, tools/import_ai_monster.py 의 역동 줄) 으로 바뀐 시트는 --force 일 때만 덮어쓴다
        if k in AI_DONE and "--force" not in sys.argv:
            print(k, "건너뜀 (AI 그림이 있음, 옛 코드 그림으로 덮으려면 --force)")
            continue
        img.save(os.path.join(OUT, k + ".png"))
        print(k)
    return out


if __name__ == "__main__":
    out = make()
    if "--preview" in sys.argv:
        ims = [i.resize((i.width * 4, i.height * 4), Image.NEAREST) for i in out.values()]
        pv = Image.new("RGBA", (max(i.width for i in ims), sum(i.height + 8 for i in ims)), (70, 90, 70, 255))
        y = 0
        for i in ims:
            pv.alpha_composite(i, (0, y))
            y += i.height + 8
        pv.save(sys.argv[sys.argv.index("--preview") + 1])
