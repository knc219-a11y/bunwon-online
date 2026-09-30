"""UI 창 · 아이콘 생성기 (2026-09-30 그래픽 시범).

  assets/ui/window.png 32 x 32  선택창 · 아침 카드: 한지 바탕 + 나무 테두리 (9칸 나눔 여백 9px)
  assets/ui/bar.png    16 x 16  위 · 아래 줄: 반투명 짙은 나무 (여백 5px)
  assets/ui/chip.png   14 x 14  위 줄 칸 하나: 연한 한지 알약 (여백 5px)
  assets/ui/icons.png  12 x 12 칸 16개
      0 해 · 1 달 · 2 돈 · 3 씨앗 · 4 무 · 5 나물 · 6 알 · 7 크리처 · 8 도구 · 9 하트 · 10 빈 하트 · 11 물약
      12 구역 깃발 · 13 몬스터 · 14 잡템 · 15 사람
글씨는 갈무리9 (assets/fonts, SIL OFL 1.1).

실행: python3 tools/make_ui_skin.py  (Pillow 필요)
"""
import os
import random

from PIL import Image, ImageDraw

from make_character_sheet import grade_p1
from make_polish_sprites import soft_outline

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")

PAPER, PAPER_D, PAPER_L = (250, 242, 222), (232, 218, 190), (255, 250, 238)
WOOD, WOOD_D, WOOD_DD, WOOD_L = (170, 118, 78), (132, 88, 60), (96, 62, 48), (204, 156, 108)
DARK, DARK_L = (58, 44, 52), (86, 66, 72)
RED, RED_D, RED_L = (226, 72, 84), (170, 46, 66), (252, 150, 150)
GREY, GREY_D = (150, 134, 140), (112, 98, 108)
GOLD, GOLD_D, GOLD_L = (240, 196, 80), (196, 146, 52), (255, 236, 150)
SUN, SUN_D = (255, 200, 90), (236, 150, 60)
MOON, MOON_D = (236, 230, 190), (196, 186, 150)
LEAF, LEAF_D, LEAF_L = (104, 176, 88), (72, 138, 74), (160, 214, 120)
WHITE, WHITE_D = (250, 248, 238), (214, 208, 200)
SEED, SEED_D = (214, 170, 110), (170, 126, 80)
EGG, EGG_D = (246, 232, 196), (214, 190, 150)
SLIME, SLIME_D, SLIME_L = (110, 176, 230), (74, 132, 196), (200, 236, 255)
METAL, METAL_D = (190, 194, 204), (130, 134, 150)
FLAG = (226, 90, 80)
ORANGE, ORANGE_D = (230, 150, 80), (186, 104, 60)
SKIN, HAIR, SHIRT = (246, 206, 170), (80, 62, 70), (110, 150, 200)


def window():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, 31, 31), 4, fill=WOOD_DD)
    d.rounded_rectangle((1, 1, 30, 30), 3, fill=WOOD)
    d.line((3, 1, 28, 1), fill=WOOD_L)
    d.line((3, 30, 28, 30), fill=WOOD_D)
    d.rectangle((4, 4, 27, 27), fill=WOOD_D)
    d.rectangle((5, 5, 26, 26), fill=PAPER)
    # 한지 결은 테두리 안쪽 띠에만 (가운데는 늘어나므로 무늬 없이)
    rng = random.Random(3)
    for _ in range(14):
        x, y = rng.choice([(rng.randrange(6, 26), rng.choice([5, 6, 25, 26])), (rng.choice([5, 6, 25, 26]), rng.randrange(6, 26))])
        img.putpixel((x, y), (*(PAPER_D if rng.random() < 0.6 else PAPER_L), 255))
    # 모서리 쇠 장식
    for x, y in ((1, 1), (28, 1), (1, 28), (28, 28)):
        d.rectangle((x, y, x + 2, y + 2), fill=GOLD_D)
        img.putpixel((x + 1, y + 1), (*GOLD_L, 255))
    return img


def bar():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, 15, 15), 3, fill=(*DARK, 215))
    d.rounded_rectangle((1, 1, 14, 14), 2, outline=(*DARK_L, 230))
    d.line((3, 1, 12, 1), fill=(*WOOD_L, 160))
    return img


def chip():
    img = Image.new("RGBA", (14, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, 13, 13), 4, fill=(*PAPER_D, 255))
    d.rounded_rectangle((0, 0, 13, 12), 4, fill=(*PAPER, 255))
    d.line((4, 1, 9, 1), fill=PAPER_L)
    return img


class I:
    def __init__(self):
        self.img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def px(self, x, y, c):
        self.img.putpixel((x, y), (*c, 255))

    def ell(self, box, c):
        self.d.ellipse(box, fill=c)

    def rect(self, box, c):
        self.d.rectangle(box, fill=c)

    def line(self, box, c):
        self.d.line(box, fill=c)


def i_sun(c):
    for x, y in ((5, 0), (5, 10), (0, 5), (10, 5), (2, 2), (8, 2), (2, 8), (8, 8)):
        c.rect((x, y, x + 1, y + 1), SUN_D)
    c.ell((2, 2, 9, 9), SUN)
    c.px(4, 4, (255, 240, 180))


def i_moon(c):
    c.ell((1, 1, 10, 10), MOON)
    c.ell((4, 0, 12, 8), (0, 0, 0, 0))
    c.px(3, 7, MOON_D)


def i_coin(c):
    c.ell((1, 2, 10, 11), GOLD_D)
    c.ell((1, 1, 10, 10), GOLD)
    c.rect((4, 4, 7, 7), GOLD_D)
    c.rect((5, 5, 6, 6), GOLD)
    c.px(3, 3, GOLD_L)


def i_seed(c):
    c.ell((2, 3, 9, 11), SEED)
    c.rect((4, 1, 7, 3), SEED_D)
    c.ell((4, 6, 7, 9), LEAF)
    c.px(5, 5, LEAF_L)


def i_radish(c):
    c.line((5, 4, 3, 0), LEAF_D)
    c.line((6, 4, 8, 0), LEAF)
    c.ell((3, 3, 8, 10), WHITE)
    c.px(5, 11, WHITE_D)
    c.rect((3, 3, 8, 4), (200, 226, 160))


def i_herb(c):
    for a, b in (((6, 11), (2, 3)), ((6, 11), (6, 1)), ((6, 11), (10, 4))):
        c.line((*a, *b), LEAF_D)
    c.ell((1, 2, 4, 5), LEAF)
    c.ell((5, 0, 8, 3), LEAF_L)
    c.ell((8, 3, 11, 6), LEAF)


def i_egg(c):
    c.ell((2, 1, 9, 11), EGG)
    c.px(4, 3, (255, 250, 232))
    c.px(7, 7, EGG_D)
    c.px(5, 8, (196, 150, 110))


def i_slime(c):
    c.ell((1, 3, 10, 11), SLIME_D)
    c.ell((1, 2, 10, 10), SLIME)
    c.px(4, 6, DARK)
    c.px(7, 6, DARK)
    c.px(3, 4, SLIME_L)


def i_tool(c):
    c.line((2, 10, 8, 4), WOOD)
    c.line((3, 10, 9, 4), WOOD_D)
    c.rect((7, 1, 10, 3), METAL)
    c.rect((9, 3, 10, 5), METAL_D)


def i_heart(c, col=RED, dark=RED_D, lite=RED_L):
    c.ell((0, 1, 6, 7), col)
    c.ell((5, 1, 11, 7), col)
    c.d.polygon([(0, 5), (11, 5), (6, 11), (5, 11)], fill=col)
    c.px(2, 3, lite)
    c.px(8, 8, dark)


def i_heart_empty(c):
    i_heart(c, GREY, GREY_D, (190, 176, 180))


def i_potion(c):
    c.rect((5, 0, 6, 2), WOOD_L)
    c.ell((2, 3, 9, 11), RED)
    c.ell((2, 6, 9, 11), RED_D)
    c.px(4, 5, RED_L)


def i_flag(c):
    c.line((2, 1, 2, 11), WOOD_D)
    c.d.polygon([(3, 1), (10, 3), (3, 6)], fill=FLAG)
    c.px(4, 2, (252, 170, 150))


def i_monster(c):
    c.ell((1, 3, 10, 11), ORANGE_D)
    c.ell((1, 2, 10, 10), ORANGE)
    c.line((3, 5, 5, 6), DARK)
    c.line((8, 5, 6, 6), DARK)
    c.line((4, 8, 7, 8), DARK)
    c.line((5, 2, 6, 0), LEAF)


def i_junk(c):
    c.ell((2, 3, 9, 11), (178, 150, 120))
    c.line((4, 3, 5, 1), (138, 112, 90))
    c.line((7, 3, 6, 1), (138, 112, 90))
    c.px(5, 6, (206, 182, 150))


def i_person(c):
    c.ell((3, 0, 8, 5), SKIN)
    c.rect((3, 0, 8, 2), HAIR)
    c.ell((2, 6, 9, 13), SHIRT)


ICONS = [i_sun, i_moon, i_coin, i_seed, i_radish, i_herb, i_egg, i_slime, i_tool, i_heart, i_heart_empty, i_potion,
         i_flag, i_monster, i_junk, i_person]


def main():
    os.makedirs(OUT, exist_ok=True)
    window().save(os.path.join(OUT, "window.png"))
    bar().save(os.path.join(OUT, "bar.png"))
    chip().save(os.path.join(OUT, "chip.png"))
    sheet = Image.new("RGBA", (12 * len(ICONS), 12), (0, 0, 0, 0))
    for i, fn in enumerate(ICONS):
        c = I()
        fn(c)
        soft_outline(c.img)
        grade_p1(c.img)
        sheet.alpha_composite(c.img, (i * 12, 0))
    sheet.save(os.path.join(OUT, "icons.png"))
    print("saved ui skin to", OUT)


if __name__ == "__main__":
    main()
