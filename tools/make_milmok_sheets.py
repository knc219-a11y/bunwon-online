"""밀목(3막 둘째 구역) 임시 스프라이트 시트 생성기 (2026-09-30 사용자 선택 B 늑대 + 호랑이, 판타지풍으로).

밀목 = 광주시 송정동 자연마을, "나무가 빽빽하게 우거졌다" (密木), 솔치 고개. 사용자: "몬스터를 좀 더 판타지 풍으로 해도 괜찮아
배경이 몬스터 침공 이후 정착한 분원리 이기때문에", "알은 아기 호랑이 일반이 나올 수 있고 낮은 확률로 백호가 나올수도있게하자".
코드로 그린 임시 그림이다. 규격 (32x32 칸, 방향 없음, 앞이 오른쪽, 발바닥 y=31):
  몬스터 (256 x 32): 0-1 대기, 2-5 이동, 6 예고 (웅크림), 7 공격 뒤 지침 (때릴 틈)
  크리처 (320 x 32): 0-1 대기, 2-5 이동, 6-9 일
  wild_shadow_wolf.png: 그림자 늑대 (검푸른 털, 빛나는 눈)
  wild_white_tiger.png: 3막 대장 산군 백호 (흰 털 · 푸른 불빛 줄무늬, 게임이 대장 배율로 키움)
  baby_tiger.png: 아기 호랑이 (땅) · baby_white_tiger.png: 아기 백호 (신령)
여우 · 구미호 · 살모사 · 이무기 후보 그림은 프로젝트 파일 design/act3/ 에만 남김.

2026-10-04 넷 다 사용자 AI 그림 (새 크기) 으로 바뀜: tools/import_ai_monster.py 의 밀목 줄. 이 파일은 --force 일 때만 assets 에 쓴다.
실행: python3 tools/make_milmok_sheets.py [--preview 파일] [--force]  (Pillow 필요)
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
GLOW = (150, 230, 255)


def ell(l, cx, cy, rx, ry, c, dark=None, split=0.35):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                l.px(x, y, dark if dark and y > cy + ry * split else c)

def beast(l, col, dark, light, size=1.0, lift=0, step=0, crouch=0, lunge=0, tired=0, tails=1, ears='point', stripes=None, tailcol=None, baby=False, eye=None):
    s = size
    base = 30 - lift
    bx = 14 + lunge * 3
    by = base - 7 * s + crouch * 2 + tired * 2
    # legs
    for i, lx in enumerate((bx - 5 * s, bx - 2 * s, bx + 3 * s, bx + 6 * s)):
        off = (step if i % 2 else -step)
        l.rect(lx + off * 0.5, by + 2, lx + off * 0.5 + 1, base, dark)
    ell(l, bx, by, 8 * s, 4.5 * s - tired, col, dark, 0.3)
    if stripes:
        for sx in range(-6, 7, 3):
            l.rect(bx + sx * s, by - 4 * s + 1, bx + sx * s, by, stripes)
    # tail(s)
    tc = tailcol or col
    for t in range(tails):
        ang = (t - (tails - 1) / 2) * 1.6
        for k in range(int(7 * s)):
            l.rect(bx - 8 * s - k * 0.8, by - 1 - k * 0.7 + ang * k * 0.25 - (step % 2), bx - 8 * s - k * 0.8 + 1.5, by - k * 0.7 + ang * k * 0.25 + 1 - (step % 2), tc)
        l.px(bx - 8 * s - 7 * s * 0.8, by - 7 * s * 0.7 + ang * 7 * s * 0.25 - (step % 2), WHITE if tails > 1 or ears == 'point' else tc)
    # head
    hx = bx + 8 * s + lunge * 2
    hy = by - 4 * s + crouch * 2 + tired * 2
    hr = 4.2 * s * (1.25 if baby else 1)
    ell(l, hx, hy, hr, hr * 0.9, col, None)
    ell(l, hx + hr * 0.8, hy + 1, hr * 0.55, hr * 0.4, light)
    l.px(hx + hr * 1.3, hy, INK)
    if ears == 'point':
        for ex in (hx - hr * 0.5, hx + hr * 0.3):
            l.rect(ex, hy - hr - 2, ex + 1, hy - hr + 1, col); l.px(ex, hy - hr - 3, dark)
    else:
        for ex in (hx - hr * 0.5, hx + hr * 0.3):
            ell(l, ex + 0.5, hy - hr + 0.5, 1.5, 1.5, dark)
    if tired:
        l.rect(hx + 0.5, hy - 1, hx + 1.5, hy - 1, INK)
    else:
        l.rect(hx + 0.5, hy - 2, hx + 1.5, hy - 1, eye or INK); l.px(hx + 1, hy - 2, WHITE)
    if stripes:
        l.rect(hx - 1, hy - hr + 1, hx - 1, hy - hr + 3, stripes)



def sheet(draws):
    img = Image.new("RGBA", (CELL * len(draws), CELL), (0, 0, 0, 0))
    for i, d in enumerate(draws):
        l = Layer()
        d(l)
        img.alpha_composite(l.img, (i * CELL, 0))
    outline(img, CELL)
    grade_p1(img)
    return img


WOLF = ((64, 66, 92), (40, 40, 62), (120, 124, 160))
WHITE_TIGER = ((244, 244, 250), (190, 200, 222), (255, 255, 255))
TIGER = ((236, 150, 50), (180, 100, 30), (250, 240, 220))
SPIRIT_STRIPE = (90, 170, 230)


def monster(pal, **k):
    return [lambda l: beast(l, *pal, **k), lambda l: beast(l, *pal, lift=1, **k),
            lambda l: beast(l, *pal, step=1, **k), lambda l: beast(l, *pal, step=2, **k), lambda l: beast(l, *pal, step=1, **k), lambda l: beast(l, *pal, **k),
            lambda l: beast(l, *pal, crouch=1, **k), lambda l: beast(l, *pal, tired=1, **k)]


def baby(pal, **k):
    k = dict(size=0.65, baby=True, ears="round", **k)
    return [lambda l: beast(l, *pal, **k), lambda l: beast(l, *pal, lift=1, **k),
            lambda l: beast(l, *pal, step=1, **k), lambda l: beast(l, *pal, step=2, **k), lambda l: beast(l, *pal, step=1, **k), lambda l: beast(l, *pal, **k),
            lambda l: beast(l, *pal, crouch=1, **k), lambda l: beast(l, *pal, lunge=1, **k), lambda l: beast(l, *pal, crouch=1, **k), lambda l: beast(l, *pal, **k)]


def make():
    out = {
        "wild_shadow_wolf": sheet(monster(WOLF, size=0.95, eye=GLOW, tailcol=(50, 50, 76))),
        "wild_white_tiger": sheet(monster(WHITE_TIGER, size=1.05, ears="round", stripes=SPIRIT_STRIPE, eye=(80, 170, 240))),
        "baby_tiger": sheet(baby(TIGER, stripes=INK)),
        "baby_white_tiger": sheet(baby(WHITE_TIGER, stripes=SPIRIT_STRIPE, eye=(80, 170, 240))),
    }
    os.makedirs(OUT, exist_ok=True)
    for k, img in out.items():
        # 2026-10-04: 넷 다 사용자 AI 그림 (새 크기, tools/import_ai_monster.py) 으로 바뀌었다. 덮어쓰지 않게 --force 일 때만 쓴다
        if "--force" not in sys.argv:
            print(k, "건너뜀 (AI 그림이 있음, 옛 코드 그림으로 덮으려면 --force)")
            continue
        img.save(os.path.join(OUT, k + ".png"))
        print(k)
    return out


if __name__ == "__main__":
    out = make()
    if "--preview" in sys.argv:
        ims = [i.resize((i.width * 4, i.height * 4), Image.NEAREST) for i in out.values()]
        pv = Image.new("RGBA", (max(i.width for i in ims), sum(i.height + 8 for i in ims)), (60, 80, 60, 255))
        y = 0
        for i in ims:
            pv.alpha_composite(i, (0, y))
            y += i.height + 8
        pv.save(sys.argv[sys.argv.index("--preview") + 1])
