"""마을 오브젝트 (부화기 · 마을 공급함 · 사냥터 입구) 임시 스프라이트 생성기.

코드로 그린 임시 그림이다. 최종 아트는 같은 크기의 PNG로 파일만 바꾸면 된다.
2026-09-27 결정: 세 오브젝트 모두 B (시골 생활형). 규격은 docs/sprites.md "마을 오브젝트".
  incubator.png  48 x 48  짚 깐 나무 상자 + 빨간 보온등, 2x2칸
  supply_box.png 48 x 44  무인 판매대 모양 공동 선반, 2x1칸
  hunt_gate.png  72 x 56  철망 울타리 문 + 경고판, 뒤로 숲, 3x2칸
  stash.png      24 x 28  공용 창고 (나무 궤짝, 쇠 띠), 1x1칸. 2026-09-28 임시 그림
  forge_ruin.png 72 x 56  무너진 대장간 터, 3x2칸. 2026-09-29 임시 그림
  forge.png      72 x 76  고친 대장간 (벽돌 · 함석지붕 · 화덕 · 모루), 3x2칸
  scrap_pile.png 40 x 26  고물 더미 (녹슨 경운기 바퀴 · 삽 · 파이프), 2x1칸
그림 맨 아래 줄이 차지하는 칸의 아래 끝(땅). 발밑 그림자는 넣지 않는다 (게임이 그림).

실행: python3 tools/make_village_props.py  (Pillow 필요)
"""
import os

from PIL import Image, ImageDraw

from make_character_sheet import grade_p1, outline

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "props")

# ---------- 공통 색 ----------
CREAM, CREAM_D, CREAM_L = (240, 234, 218), (206, 196, 180), (252, 248, 238)
EGG, EGG_D, EGG_SPOT = (246, 232, 196), (218, 196, 158), (196, 150, 110)
RED, RED_D, RED_L = (214, 82, 70), (168, 58, 58), (244, 140, 116)
WOOD, WOOD_D, WOOD_DD, WOOD_L = (176, 128, 86), (140, 98, 68), (110, 76, 56), (206, 160, 112)
STRAW, STRAW_D, STRAW_L = (230, 198, 116), (196, 160, 88), (248, 226, 156)
METAL, METAL_D, METAL_L = (150, 156, 166), (112, 116, 130), (196, 200, 210)
LAMP_GLOW = (255, 196, 120)
AMBER, AMBER_L, AMBER_D = (250, 176, 80), (255, 232, 160), (206, 124, 60)
WHITE, WHITE_D = (246, 244, 238), (214, 210, 204)
BLUE, BLUE_D, BLUE_L = (96, 140, 196), (70, 106, 160), (140, 180, 226)
YELLOW, YELLOW_D = (244, 204, 84), (212, 164, 60)
CRATE_G, CRATE_G_D = (110, 176, 110), (80, 140, 88)
CONC, CONC_D, CONC_L = (186, 182, 176), (150, 146, 142), (210, 206, 200)
MESH, MESH_D = (170, 176, 184), (120, 126, 138)
WARN, WARN_D = (246, 206, 70), (60, 52, 50)
FOREST, FOREST_D = (70, 100, 84), (48, 72, 66)


class C:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.w, self.h = w, h

    def rect(self, x0, y0, x1, y1, c):
        self.d.rectangle((x0, y0, x1, y1), fill=c)

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), (*c, 255))

    def ell(self, x0, y0, x1, y1, c):
        self.d.ellipse((x0, y0, x1, y1), fill=c)

    def line(self, x0, y0, x1, y1, c, w=1):
        self.d.line((x0, y0, x1, y1), fill=c, width=w)

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)


def egg(c, cx, cy, rx=3, ry=4):
    c.ell(cx - rx, cy - ry, cx + rx, cy + ry, EGG)
    c.px(cx - rx + 1, cy - ry + 2, (255, 250, 232))
    c.px(cx + rx - 1, cy + 1, EGG_D)
    c.px(cx + rx - 1, cy + 2, EGG_D)
    c.px(cx, cy - 1, EGG_SPOT)
    c.px(cx - 1, cy + 2, EGG_SPOT)


def incubator_b():
    """짚 둥지 나무 상자 + 빨간 보온등 (2x2칸). 시골 병아리 키우는 방식."""
    c = C(48, 48)
    # 나무 상자 (윗면 안쪽이 보임)
    c.rect(3, 26, 42, 30, WOOD_DD)  # 상자 안 뒷벽 그늘
    c.rect(3, 22, 42, 25, WOOD_L)  # 뒷벽 윗단
    c.rect(5, 27, 40, 32, STRAW)
    for x in range(6, 40, 3):
        c.px(x, 28, STRAW_L)
        c.px(x + 1, 30, STRAW_D)
    egg(c, 15, 28, 3, 4)
    egg(c, 23, 29, 3, 3)
    egg(c, 30, 28, 3, 4)
    # 앞판 널빤지
    c.rect(2, 32, 43, 47, WOOD)
    for y in (37, 42):
        c.hline(2, 43, y, WOOD_D)
    c.hline(2, 43, 32, WOOD_L)
    c.vline(43, 32, 47, WOOD_D)
    c.vline(2, 22, 47, WOOD_L)
    c.vline(43, 22, 31, WOOD_D)
    for (x, y) in ((5, 34), (40, 34), (5, 44), (40, 44)):
        c.px(x, y, METAL_D)
    # 보온등: 오른쪽 뒤 기둥 → 팔 → 갓
    c.rect(38, 2, 39, 24, METAL)
    c.vline(39, 2, 24, METAL_D)
    c.rect(24, 2, 39, 3, METAL)
    c.hline(24, 39, 3, METAL_D)
    c.vline(27, 4, 7, METAL_D)
    # 갓 (아래로 벌어진 원뿔)
    c.rect(24, 8, 30, 9, RED)
    c.rect(22, 10, 32, 12, RED)
    c.rect(21, 13, 33, 14, RED_D)
    c.px(24, 10, RED_L)
    c.px(23, 11, RED_L)
    # 전구 불빛
    c.rect(25, 15, 29, 16, LAMP_GLOW)
    c.hline(26, 28, 17, AMBER_L)
    return c.img


def supply_b():
    """무인 판매대 모양 공동 선반 (2x1칸). 양철 지붕, 농산물 상자."""
    c = C(48, 44)
    # 기둥
    c.rect(3, 10, 5, 43, WOOD)
    c.rect(42, 10, 44, 43, WOOD)
    c.vline(5, 10, 43, WOOD_D)
    c.vline(44, 10, 43, WOOD_D)
    # 양철 지붕 (파란 골함석)
    c.rect(0, 2, 47, 9, BLUE)
    for x in range(0, 48, 3):
        c.vline(x, 2, 9, BLUE_L)
        c.vline(x + 2, 2, 9, BLUE_D)
    c.hline(0, 47, 10, BLUE_D)
    c.hline(0, 47, 1, BLUE_L)
    # 뒤판
    c.rect(6, 11, 41, 26, WOOD_DD)
    # 손글씨 칠판
    c.rect(28, 13, 39, 19, (70, 84, 76))
    c.hline(30, 36, 15, WHITE)
    c.hline(30, 34, 17, WHITE)
    # 노란 상자 (알)
    c.rect(8, 19, 22, 26, YELLOW)
    c.hline(8, 22, 19, (252, 226, 130))
    for x in (10, 14, 18):
        c.rect(x, 23, x + 1, 24, YELLOW_D)
    egg(c, 12, 18, 2, 3)
    egg(c, 17, 18, 2, 3)
    # 초록 상자 (무)
    c.rect(25, 21, 38, 26, CRATE_G)
    c.hline(25, 38, 21, (150, 206, 140))
    c.rect(28, 18, 31, 20, WHITE)
    c.rect(33, 18, 36, 20, WHITE)
    c.px(29, 17, (120, 190, 90))
    c.px(34, 17, (120, 190, 90))
    # 판매대 앞판
    c.rect(2, 27, 45, 29, WOOD_L)
    c.rect(3, 30, 44, 41, WOOD)
    c.hline(3, 44, 35, WOOD_D)
    c.hline(3, 44, 41, WOOD_D)
    # 알 상자 표시 스티커
    c.rect(20, 32, 27, 38, CREAM_L)
    c.ell(22, 33, 25, 37, EGG_D)
    return c.img


def gate_b():
    """철망 울타리 문 + 경고판 (3x2칸). 산 밑 밭에 흔한 멧돼지 울타리."""
    c = C(72, 56)
    # 뒤 숲 그늘
    c.ell(4, 2, 30, 30, FOREST)
    c.ell(24, 0, 52, 28, FOREST_D)
    c.ell(44, 4, 70, 30, FOREST)
    c.rect(4, 16, 68, 40, FOREST_D)
    # 콘크리트 기둥
    for x in (2, 32, 64):
        c.rect(x, 18, x + 5, 55, CONC)
        c.hline(x, x + 5, 18, CONC_L)
        c.vline(x + 5, 18, 55, CONC_D)
    # 철망 (양옆 울타리 + 가운데 문)
    for (x0, x1) in ((8, 31), (38, 63)):
        c.hline(x0, x1, 22, METAL)
        c.hline(x0, x1, 52, METAL)
        for x in range(x0, x1 + 1):
            for y in range(23, 52):
                if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                    c.px(x, y, MESH)
    # 가운데 문은 살짝 열려 있음 (문틀 밝게)
    c.rect(38, 22, 39, 52, METAL_L)
    c.rect(62, 22, 63, 52, METAL_L)
    c.hline(38, 63, 37, METAL_L)
    # 노란 경고판
    c.rect(14, 28, 25, 37, WARN)
    c.hline(14, 25, 37, (212, 170, 50))
    c.rect(19, 29, 20, 33, WARN_D)
    c.rect(19, 35, 20, 35, WARN_D)
    # 빨간 표시 리본
    c.rect(66, 24, 68, 27, RED)
    return c.img


def stash():
    """공용 창고: 뚜껑 달린 나무 궤짝 (1x1칸). 농부·사냥꾼이 함께 쓴다."""
    c = C(24, 28)
    # 뚜껑 (윗면이 조금 보임)
    c.rect(1, 6, 22, 11, WOOD_L)
    c.hline(1, 22, 6, CREAM_L)
    c.rect(1, 12, 22, 13, WOOD_D)
    # 몸통 널빤지
    c.rect(2, 14, 21, 27, WOOD)
    for y in (18, 23):
        c.hline(2, 21, y, WOOD_D)
    c.vline(21, 14, 27, WOOD_DD)
    c.vline(2, 14, 27, WOOD_L)
    # 쇠 띠와 자물쇠
    for x in (5, 18):
        c.rect(x, 6, x + 1, 27, METAL_D)
        c.vline(x, 6, 27, METAL)
    c.rect(10, 12, 13, 17, YELLOW)
    c.hline(10, 13, 12, (252, 226, 130))
    c.px(11, 15, WOOD_DD)
    c.px(12, 15, WOOD_DD)
    return c.img


# ---------- 대장간 (2026-09-29 사용자 선택 A: 한 번에 복구 + 사람 장비 제작) ----------
BRICK, BRICK_D, BRICK_L = (186, 104, 84), (146, 78, 66), (214, 138, 112)
TIN, TIN_D, TIN_L = (120, 150, 170), (90, 116, 138), (160, 188, 204)
RUST, RUST_D = (170, 104, 70), (126, 76, 56)
WEED, WEED_D = (104, 160, 88), (76, 124, 70)
IRON, IRON_D, IRON_L = (84, 88, 100), (58, 60, 72), (130, 136, 150)
SOOT = (70, 62, 66)


def bricks(c, x0, y0, x1, y1):
    c.rect(x0, y0, x1, y1, BRICK)
    for y in range(y0, y1 + 1, 4):
        c.hline(x0, x1, y, BRICK_D)
        off = 0 if (y - y0) // 4 % 2 == 0 else 4
        for x in range(x0 + off, x1 + 1, 8):
            c.vline(x, y, min(y + 3, y1), BRICK_D)
    c.hline(x0, x1, y0, BRICK_L)


def anvil(c, x, y):
    """y = 바닥"""
    c.rect(x + 3, y - 4, x + 9, y, IRON_D)
    c.rect(x + 5, y - 8, x + 7, y - 4, IRON)
    c.rect(x, y - 11, x + 12, y - 8, IRON)
    c.rect(x - 3, y - 11, x, y - 9, IRON)
    c.hline(x - 2, x + 12, y - 11, IRON_L)


def forge():
    """대장간 (3x2칸, 2026-09-29 복구 A): 벽돌 벽 + 함석지붕 + 쇠 연통, 앞이 열려 화덕과 걸린 연장이 보임, 앞에 모루."""
    c = C(72, 76)
    # 함석 지붕 (골 무늬)
    c.rect(2, 14, 69, 30, TIN)
    for x in range(3, 69, 4):
        c.vline(x, 14, 30, TIN_D)
        c.vline(x + 1, 14, 30, TIN_L)
    c.hline(2, 69, 30, TIN_D)
    c.hline(0, 71, 31, IRON_D)
    # 굴뚝 (쇠 연통) + 연기
    c.rect(52, 0, 57, 16, IRON)
    c.vline(52, 0, 16, IRON_L)
    for (x, y, r) in ((58, 2, 3), (63, 0, 2)):
        c.ell(x - r, y - r + 3, x + r, y + r + 3, (220, 214, 214))
    # 벽 (벽돌) + 열린 앞 (화덕이 보임)
    bricks(c, 4, 32, 67, 75)
    c.rect(12, 42, 42, 75, SOOT)
    # 화덕
    bricks(c, 16, 58, 38, 75)
    c.rect(21, 62, 33, 70, (60, 40, 40))
    c.rect(22, 64, 32, 70, AMBER_D)
    c.rect(24, 66, 30, 70, AMBER)
    c.rect(26, 67, 28, 69, AMBER_L)
    # 걸린 연장 (현대풍: 스패너 · 삽 · 망치)
    c.rect(16, 45, 17, 54, METAL_L); c.rect(15, 44, 18, 46, METAL_L)
    c.rect(24, 45, 25, 55, WOOD); c.rect(22, 52, 27, 56, METAL)
    c.rect(33, 46, 34, 55, WOOD); c.rect(31, 44, 36, 47, IRON)
    # 간판
    c.rect(44, 36, 64, 46, CREAM_L)
    c.rect(44, 36, 64, 36, WOOD_D)
    for i, x in enumerate(range(47, 62, 5)):
        c.rect(x, 39, x + 3, 43, RED_D)
    # 모루 (앞)
    anvil(c, 50, 74)
    return c.img


def forge_ruin():
    """무너진 대장간 터 (3x2칸): 벽돌 밑동 · 쓰러진 함석판 · 반쯤 묻힌 녹슨 모루 · 푯말. 1막 대장을 잡으면 나타남."""
    c = C(72, 56)
    # 무너진 벽돌 밑동
    bricks(c, 4, 38, 14, 55)
    bricks(c, 4, 46, 30, 55)
    bricks(c, 56, 42, 67, 55)
    bricks(c, 44, 50, 67, 55)
    # 쓰러진 함석판 (녹)
    c.line(20, 40, 44, 48, TIN_D, 3)
    c.line(20, 38, 44, 46, RUST, 2)
    c.line(34, 30, 58, 38, TIN, 3)
    c.line(34, 28, 58, 36, RUST_D, 1)
    # 반쯤 묻힌 녹슨 모루
    c.rect(28, 50, 40, 53, RUST_D)
    c.rect(30, 47, 38, 50, RUST)
    # 잡초
    for x in (2, 16, 26, 42, 52, 69):
        c.vline(x, 49, 55, WEED); c.px(x - 1, 51, WEED_D); c.px(x + 1, 50, WEED)
    # 푯말
    c.rect(46, 14, 47, 40, WOOD_D)
    c.rect(38, 12, 66, 24, WOOD_L)
    c.hline(38, 66, 24, WOOD_D)
    for x in range(41, 64, 5):
        c.rect(x, 16, x + 3, 20, WOOD_DD)
    return c.img


def scrap_pile():
    """고철 더미 (1x1~2x1): 녹슨 경운기 바퀴 · 삽날 · 파이프"""
    c = C(40, 26)
    c.ell(2, 8, 20, 25, RUST_D); c.ell(6, 12, 16, 21, (0, 0, 0, 0)); c.ell(8, 14, 14, 19, IRON)
    c.line(14, 24, 38, 14, IRON_L, 2)
    c.line(18, 25, 36, 22, RUST, 3)
    c.rect(24, 10, 33, 18, METAL); c.rect(26, 4, 27, 10, WOOD)
    c.rect(30, 20, 38, 25, RUST_D)
    return c.img


PROPS = {
    "incubator": incubator_b,
    "supply_box": supply_b,
    "hunt_gate": gate_b,
    "stash": stash,
    "forge_ruin": forge_ruin,
    "forge": forge,
    "scrap_pile": scrap_pile,
}


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, draw in PROPS.items():
        img = draw()
        outline(img, cell=max(img.size) + 2)
        grade_p1(img)
        img.save(os.path.join(OUT_DIR, f"{name}.png"))
