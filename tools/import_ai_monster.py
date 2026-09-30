"""AI가 그린 몬스터 · 크리처 정면 그림 한 장 → 32x32 칸 시트 (import_ai_slime.py 와 같은 방식).

금사리 세트 (2026-09-30): 프롬프트는 /mnt/project-files/design/gumsa-ai/prompt.md.
  crab  → assets/creatures/wild_sand_crab.png (256x32): 0-1 대기, 2-5 옆걸음, 6-7 모래에 숨음 (눈만 빼꼼)
  boss  → assets/creatures/wild_gold_toad.png (192x32): 0-1 대기 (목 부풀기), 2-5 깡충. 게임에서 1.8배로 키운다
  baby  → assets/creatures/gold_toad_earth.png (320x32): 0-1 대기, 2-5 깡충, 6-9 일 (혀 쭉 + 발밑 사금 반짝)
규격은 tools/make_wild_sheets.py · make_gold_toad_sheet.py 의 코드 그림과 같다. 발바닥은 칸 맨 아래, 몸 중심 x=16.

하는 일
  1. 흰 바탕을 지우고 몸만 잘라 작업 크기로 줄인다 (import_ai_slime 의 halo 벗기기 그대로).
  2. 프레임마다 가로 · 세로 늘임과 뜬 높이대로 픽셀화한다. 옆걸음은 아래쪽 다리 줄을 1px 씩 번갈아 민다.
  3. 까만 선은 이웃 색을 어둡게 한 보랏빛 선으로 누그러뜨리고 P1 파스텔 보정.
  4. 모래 더미 (게 숨기) · 혀 · 사금 반짝은 코드로 그린다. --redraw-eyes 면 눈 · 입을 지우고 둥근 눈 + 반짝으로 다시 그린다.

광동리 세트 (2026-09-30, 참새 → 요괴 까마귀로 바뀜): 프롬프트는 /mnt/project-files/design/gwangdong-ai/prompt.md.
  sparrow      → assets/creatures/wild_sparrow.png (256x32): 0-1 앉아 쪼기, 2-5 날갯짓, 6-7 낟알 쪼기 (요괴 까마귀)
  scarecrow    → assets/creatures/wild_scarecrow.png (256x32): 0-1 흔들, 2-5 깡충, 6-7 짚단 던지기. 게임에서 1.8배
  baby_sparrow → assets/creatures/baby_sparrow_flying.png (320x32): 0-1 대기, 2-5 날기, 6-9 쪼기 (아기 까마귀)
  까마귀 둘은 왼쪽을 보는 옆모습: 앉은 그림 + --fly 날개 편 그림 (없으면 앉은 그림만 흔든다). 오른쪽을 보면 --flip.
  발밑 보라 안개 · 다리 사이 흰 바탕은 지운다 (clear_mist). 붉은 눈은 --eyes/--fly-eyes + --eye-color 로 다시 찍는다.

실행: python3 tools/import_ai_monster.py 그림.png --kind crab|boss|baby|sparrow|scarecrow|baby_sparrow [--width 24] [--colors 20] [--preview 미리보기.png]
      (--sand 숨은그림.png: 모래에 파묻힌 게 그림이 따로 있으면 숨기 칸에 그걸 쓴다)

지금 시트를 만든 명령 (그림 원본: /mnt/project-files/design/gumsa-ai/ai_*.png, 사용자 AI 그림 2026-09-30)
  (옛 주황 모래게: --kind crab --width 28 --colors 24 --eyes 0.402,0.283,0.594,0.283 --eye-ring)
  ai_crab_demon.png --kind crab --width 30 --colors 32 --eyes 0.43,0.51,0.58,0.51 --eye-color 255,56,40 --angry --peek 0.6
    (2026-09-30 요괴 모래게: 사용자 "금사리 게도 너무 약해 보여". 프롬프트 design/gumsa-ai/crab2-prompt.md A.
     숨기 칸은 대기 칸의 뿔 · 빨간 눈을 잘라 모래 더미 위로 빼꼼)
  --kind boss --colors 24 --eyes 0.545,0.17,0.849,0.16 --eye-lid
  --kind baby --colors 24 --eyes 0.518,0.181,0.882,0.159 --cheeks 0.465,0.353,0.934,0.345 --mouth 0.75,0.40
광동리 (그림 원본: /mnt/project-files/design/gwangdong-ai/ai_*.png, 사용자 AI 그림 2026-09-30)
  ai_crow.png --kind sparrow --fly ai_crow_fly.png --flip --colors 24 --eyes 0.2,0.31 --fly-eyes 0.2,0.53 --eye-color 230,50,60
  ai_scarecrow.png --kind scarecrow --colors 28   (눈은 AI 그림 그대로: 다시 찍은 빨간 눈은 사용자가 이상하다고 함)
  ai_baby.png --kind baby_sparrow --fly ai_baby_fly.png --flip --colors 24 --eyes 0.37,0.4 --fly-eyes 0.41,0.4 --eye-color 200,40,56
"""
import argparse
import os

from PIL import Image

from import_ai_character import pixelize, white_to_alpha
from import_ai_slime import draw_face, find_face, inpaint, largest_blob, peel_halo, soften_edges
from make_character_sheet import grade_p1, outline
from make_gold_toad_sheet import GOLD, GOLD_L, TONGUE, TONGUE_D, TONGUE_L
from make_slime_sheet import CELL, Layer
from make_wild_sheets import GOLD as SAND_GOLD, SAND, SAND_D, SAND_L, crab_buried, ellipse

ROOT = os.path.join(os.path.dirname(__file__), "..")
EYE, GLINT, RING = (58, 38, 50), (255, 248, 240), (250, 240, 226)
CHEEK = (244, 164, 150)
WORK_W = 192

# 프레임: 가로 늘임, 세로 늘임, 뜬 높이, 그 밖의 표시
#   step: 옆걸음 다리 밀기 (-1/1), sand: 숨기 (빼꼼 정도 0/1), work: 혀 단계 (1 내밂 · 2 쭉 · 3 거둠)
KINDS = {
    "crab": dict(out="wild_sand_crab", width=24, frames=[
        dict(sx=1.0, sy=1.0, lift=0), dict(sx=1.02, sy=0.96, lift=0),
        dict(sx=1.0, sy=1.0, lift=1, step=1, dx=-1), dict(sx=1.0, sy=0.97, lift=0, step=-1, dx=0),
        dict(sx=1.0, sy=1.0, lift=1, step=1, dx=1), dict(sx=1.0, sy=0.97, lift=0, step=-1, dx=0),
        dict(sand=0), dict(sand=1),
    ]),
    # 예전 코드 그림 24x15 기준: 대기 목 부풀기, 깡충 26x12 → 20x17 (5 뜸) → 22x16 (9 뜸) → 26x12
    "boss": dict(out="wild_gold_toad", width=26, frames=[
        dict(sx=1.0, sy=1.0, lift=0), dict(sx=1.04, sy=0.97, lift=0),
        dict(sx=1.08, sy=0.8, lift=0), dict(sx=0.83, sy=1.13, lift=5),
        dict(sx=0.92, sy=1.07, lift=9), dict(sx=1.08, sy=0.8, lift=0),
    ]),
    # make_gold_toad_sheet 의 IDLE · HOP · WORK 를 첫 대기 칸 (0.85, 0.9) 기준으로
    "baby": dict(out="gold_toad_earth", width=22, frames=[
        dict(sx=1.0, sy=1.0, lift=0), dict(sx=1.035, sy=0.955, lift=0),
        dict(sx=1.12, sy=0.86, lift=0), dict(sx=0.91, sy=1.1, lift=3),
        dict(sx=0.95, sy=1.06, lift=6), dict(sx=1.12, sy=0.86, lift=0),
        dict(sx=1.1, sy=0.9, lift=0, work=0), dict(sx=0.95, sy=1.06, lift=0, work=1),
        dict(sx=1.0, sy=1.0, lift=0, work=2), dict(sx=1.035, sy=0.955, lift=0, work=3),
    ]),
    # 광동리 세트 (2026-09-30). 참새 둘은 왼쪽을 보는 옆모습, 앉은 그림 + 날개 편 그림 (--fly) 두 장.
    #   rot: 발밑 가운데를 축으로 기울임 (도, + 는 머리가 왼쪽 아래로 = 쪼기), fly: 날개 편 그림을 쓴다
    #   fw: 날개 편 그림의 가로 px (날개 폭이 넓어서 따로)
    "sparrow": dict(out="wild_sparrow", width=26, fw=28, mist=True, frames=[
        dict(sx=1.0, sy=1.0, lift=0), dict(sx=1.0, sy=1.0, lift=0, rot=22),
        dict(fly=True, sx=1.0, sy=1.0, lift=2), dict(fly=True, sx=1.04, sy=0.72, lift=3),
        dict(fly=True, sx=1.0, sy=1.0, lift=3), dict(fly=True, sx=1.04, sy=0.72, lift=2),
        dict(sx=1.0, sy=1.0, lift=0, rot=22), dict(sx=1.03, sy=0.96, lift=0),
    ]),
    # 정면. 게임에서 1.8배. 짚단 · 떨어질 자리 원은 게임이 그린다
    "scarecrow": dict(out="wild_scarecrow", width=28, max_h=30, frames=[
        dict(sx=1.0, sy=1.0, lift=0), dict(sx=1.0, sy=1.0, lift=0, rot=-4, dx=1),
        dict(sx=1.03, sy=0.94, lift=1), dict(sx=0.97, sy=1.0, lift=2),
        dict(sx=1.0, sy=0.97, lift=1), dict(sx=1.03, sy=0.95, lift=0),
        dict(sx=1.0, sy=1.0, lift=0, rot=9, dx=-1), dict(sx=1.0, sy=1.0, lift=0),
    ]),
    "baby_sparrow": dict(out="baby_sparrow_flying", width=16, fw=21, mist=True, frames=[
        dict(sx=1.0, sy=1.0, lift=0), dict(sx=1.04, sy=0.95, lift=0),
        dict(fly=True, sx=1.0, sy=1.0, lift=6), dict(fly=True, sx=1.04, sy=0.72, lift=9),
        dict(fly=True, sx=1.0, sy=1.0, lift=9), dict(fly=True, sx=1.04, sy=0.72, lift=6),
        dict(sx=1.0, sy=1.0, lift=0, rot=22), dict(sx=1.0, sy=1.0, lift=0),
        dict(sx=1.0, sy=1.0, lift=0, rot=22), dict(sx=1.03, sy=0.96, lift=0),
    ]),
}


def clear_mist(im):
    """발밑 보라 안개 · 다리 사이에 갇힌 흰 바탕을 지운다 (요괴 까마귀). 밝고 푸른 기가 도는 연한 색만."""
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and (min(r, g, b) > 225 or ((r + g + b) / 3 > 165 and b >= r - 10 and b > g + 10)):
                px[x, y] = (0, 0, 0, 0)
    return im


def load_figure(src, flip=False, mist=False):
    im = white_to_alpha(Image.open(src))
    fig = peel_halo(largest_blob(clear_mist(im) if mist else im))
    if flip:
        fig = fig.transpose(Image.FLIP_LEFT_RIGHT)
    fig = fig.resize((WORK_W, round(WORK_W * fig.height / fig.width)), Image.LANCZOS)
    fig.putalpha(fig.getchannel("A").point(lambda v: 255 if v > 128 else 0))
    return fig


def shove_legs(img, step):
    """아래 1/4 줄 (다리)을 step 만큼 옆으로 민다. 옆걸음에서 다리가 번갈아 움직여 보이게."""
    w, h = img.size
    top = h - max(2, h // 4)
    legs = img.crop((0, top, w, h))
    out = img.copy()
    out.paste((0, 0, 0, 0), (0, top, w, h))
    out.alpha_composite(legs, (step, top)) if step > 0 else out.alpha_composite(legs.crop((-step, 0, w, h - top)), (0, top))
    return out


def eye_stalks(body):
    """게 그림의 가운데 위 30% (눈자루)만 잘라 낸다. 집게는 양옆이라 가운데 45% 만 본다."""
    w, h = body.size
    x0, x1 = round(w * 0.275), round(w * 0.725)
    part = body.crop((x0, 0, x1, max(3, round(h * 0.3))))
    box = part.getbbox()
    return part.crop(box) if box else part


def sand_mound(l, peek):
    cx = 15.5
    ellipse(l, cx, 30, 12, 4 + peek, SAND, SAND_D, 0.3)
    l.rect(cx - 6, 27 - peek, cx - 3, 27 - peek, SAND_L)
    l.px(cx + 5, 28, SAND_GOLD)
    l.px(cx - 8, 30, SAND_GOLD)


def draw_tongue(l, mx, my, stage):
    """아기 금두꺼비 일 칸: 혀를 앞으로 쭉, 발밑에서 사금이 반짝 (make_gold_toad_sheet 와 같은 그림)."""
    if stage:
        n = {1: 2, 2: 6, 3: 3}[stage]
        l.rect(mx - 1, my, mx, my + 1, TONGUE_D)
        for i in range(n):
            l.rect(mx - 1, my + 1 + i, mx, my + 1 + i, TONGUE)
        if stage == 2:
            l.rect(mx - 2, my + n, mx + 1, my + n + 1, TONGUE)
            l.px(mx - 1, my + n, TONGUE_L)
    if stage >= 2:
        for x, y in ((6, 29), (25, 28), (9, 24), (23, 23)) if stage == 3 else ((8, 28), (24, 27)):
            l.px(x, y, GOLD)
            l.px(x, y - 1, GOLD_L)
            l.px(x - 1, y, GOLD_L)


LID = (150, 96, 40)


BROW = (70, 24, 34)


def spot_face(l, left, top, W, H, eyes, size, ring, cheeks, lid=False, eye=EYE, angry=False):
    """정해 준 자리 (몸 비율)에 둥근 눈 + 반짝을 새로 찍는다. 22~30px 로 줄이면 AI 눈이 뭉개져서."""
    for fx, fy in cheeks:
        cx, cy = int(round(left + fx * W)), int(round(top + fy * H))
        l.rect(cx - 1, cy, cx, cy, CHEEK)
    for fx, fy in eyes:
        ex = int(round(left + fx * W - size / 2))
        ey = int(round(top + fy * H - (size + 1) / 2))
        if ring:
            l.rect(ex - 1, ey - 1, ex + size, ey + size + 1, RING)
        l.rect(ex, ey, ex + size - 1, ey + size, eye)
        if angry:
            # 요괴 모래게: 반짝 대신 밝은 눈동자 한 점 + 가운데로 내려오는 성난 눈썹
            inner = 1 if fx < 0.5 else -1
            l.px(ex + (size - 1 if inner > 0 else 0), ey + 1, (255, 200, 120))
            for k in range(size + 1):
                bx = ex - 1 + k if inner > 0 else ex + size - k
                l.px(bx, ey - 1 + (k * 2) // (size + 1), BROW)
            continue
        l.px(ex, ey, GLINT)
        if size >= 3:
            l.px(ex + 1, ey, GLINT)
        if lid:
            # 반쯤 감은 무거운 눈꺼풀 (금두꺼비 대장): 윗줄을 눈꺼풀로 덮고 반짝은 한 줄 아래로
            l.rect(ex - 1, ey - 1, ex + size, ey, LID)
            l.px(ex, ey + 1, GLINT)


def tilt(body, deg):
    """발밑 가운데를 축으로 기울인다 (쪼기 · 짚단 던지기). 칸 크기는 그대로, 넘치면 잘린다."""
    w, h = body.size
    big = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    big.alpha_composite(body, (w // 2, h - 1))
    big = big.rotate(deg, resample=Image.NEAREST, center=(w, h * 2 - 1))
    box = big.getbbox() or (0, 0, big.width, big.height)

    def move(x, y):
        """기울이기 전 몸 안 자리 → 기울인 뒤 자리 (눈을 따라 옮길 때)."""
        import math
        a = math.radians(deg)
        dx, dy = x + w // 2 - w, y + h - 1 - (h * 2 - 1)
        return (w + dx * math.cos(a) + dy * math.sin(a) - box[0], h * 2 - 1 - dx * math.sin(a) + dy * math.cos(a) - box[1])
    return big.crop(box), move


def build(src, kind, width=None, colors=20, redraw_eyes=False, sand_src=None, mouth=(0.5, 0.62),
          spot_eyes=None, eye_size=2, eye_ring=False, cheeks=(), eye_lid=False, fly_src=None, flip=False,
          fly_eyes=None, eye_color=EYE, peek=None, angry=False):
    spec = KINDS[kind]
    width = width or spec["width"]
    fig = load_figure(src, flip, spec.get("mist", False))
    fly = None
    if fly_src:
        fly = load_figure(fly_src, flip, spec.get("mist", False))
        fly_pal = fly.convert("RGB").quantize(colors, method=Image.Quantize.FASTOCTREE)
        fly_h = round(spec["fw"] * fly.height / fly.width)
    eyes = None
    if redraw_eyes:
        eyes, found_mouth, erase = find_face(fig)
        inpaint(fig, erase)
        mouth = found_mouth or mouth
    pal_img = fig.convert("RGB").quantize(colors, method=Image.Quantize.FASTOCTREE)
    pal = pal_img.getpalette()
    base_h = round(width * fig.height / fig.width)
    if spec.get("max_h") and base_h > spec["max_h"]:
        width, base_h = round(width * spec["max_h"] / base_h), spec["max_h"]
    frames = spec["frames"]
    bodies = Image.new("RGBA", (CELL * len(frames), CELL), (0, 0, 0, 0))
    over = Image.new("RGBA", bodies.size, (0, 0, 0, 0))
    placed = []
    had_line = True
    stalks = None
    for i, f in enumerate(frames):
        if "sand" in f:
            placed.append(None)
            continue
        use_fly = f.get("fly") and fly is not None
        src_fig, src_pal, bw, bh = (fly, fly_pal, spec["fw"], fly_h) if use_fly else (fig, pal_img, width, base_h)
        if f.get("fly") and fly is None:
            # 날개 편 그림이 없으면 앉은 그림을 위아래로만 흔든다
            f = dict(f, sx=1.0, sy=1.0 if f["sy"] >= 1.0 else 0.94)
        W = max(8, round(bw * f["sx"]))
        H = max(8, min(CELL - f["lift"], round(bh * f["sy"])))
        body = pixelize(src_fig, src_pal, src_pal.getpalette(), W, H)
        had_line = soften_edges(body) and had_line
        if f.get("step"):
            body = shove_legs(body, f["step"])
        move = None
        if f.get("rot"):
            W0, H0 = W, H
            body, mv = tilt(body, f["rot"])
            W, H = body.size
            H = min(H, CELL - f["lift"])
            move = lambda fx, fy, mv=mv, W0=W0, H0=H0, W=W, H=H: tuple(v / d for v, d in zip(mv(fx * W0, fy * H0), (W, H)))
        if stalks is None and kind == "crab":
            stalks = eye_stalks(body)
        left = CELL // 2 - W // 2 + f.get("dx", 0)
        top = CELL - f["lift"] - H
        bodies.alpha_composite(body, (i * CELL + left, top))
        placed.append((left, top, W, H, move))
    if not had_line:
        outline(bodies, CELL)
    grade_p1(bodies)
    sheet = Image.new("RGBA", bodies.size, (0, 0, 0, 0))
    sheet.alpha_composite(bodies)
    for i, (f, p) in enumerate(zip(frames, placed)):
        l = Layer()
        if "sand" in f:
            if sand_src:
                sand = load_figure(sand_src)
                sp = sand.convert("RGB").quantize(colors, method=Image.Quantize.FASTOCTREE)
                sw = round(width * 1.05)
                sh = min(CELL, round(sw * sand.height / sand.width) + f["sand"])
                img = pixelize(sand, sp, sp.getpalette(), sw, sh)
                soften_edges(img)
                grade_p1(img)
                sheet.alpha_composite(img, (i * CELL + CELL // 2 - sw // 2, CELL - sh))
                continue
            if peek:
                # 요괴 모래게: 눈을 새로 찍은 대기 칸에서 가운데 윗부분 (뿔 · 빨간 눈)을 잘라 모래 더미 뒤에서 빼꼼
                left0, top0, W0, H0, _ = placed[0]
                x0, x1 = left0 + round(W0 * 0.3), left0 + round(W0 * 0.7)
                head = sheet.crop((x0, top0, x1, top0 + round(H0 * peek)))
                sheet.alpha_composite(head, (i * CELL + x0, 27 - f["sand"] - head.height))
                sand_mound(l, f["sand"])
                mound = l.img
                outline(mound, CELL)
                grade_p1(mound)
                sheet.alpha_composite(mound, (i * CELL, 0))
                continue
            peek = f["sand"]
            if spot_eyes:
                # 모래 더미 + 빼꼼 나온 눈자루는 코드 그림 그대로 (눈은 위에서 새로 찍은 것과 같은 모양)
                crab_buried(l, peek)
                mound = l.img
                outline(mound, CELL)
                grade_p1(mound)
                sheet.alpha_composite(mound, (i * CELL, 0))
                continue
            # 눈자루를 모래 더미 뒤에 먼저 놓고, 그 위에 모래를 덮는다
            if stalks:
                sheet.alpha_composite(stalks, (i * CELL + CELL // 2 - stalks.width // 2, 28 - 2 * peek - stalks.height))
            sand_mound(l, peek)
            mound = l.img
            outline(mound, CELL)
            grade_p1(mound)
            sheet.alpha_composite(mound, (i * CELL, 0))
            continue
        left, top, W, H, move = p
        if eyes:
            draw_face(l, left, top, W, H, eyes, mouth)
        use_eyes = fly_eyes if f.get("fly") and fly is not None else spot_eyes
        if use_eyes and move:
            use_eyes = [move(fx, fy) for fx, fy in use_eyes]
        if use_eyes:
            spot_face(l, left, top, W, H, use_eyes, eye_size, eye_ring, cheeks if not f.get("fly") else (), eye_lid, eye_color, angry)
        if "work" in f:
            draw_tongue(l, int(round(left + mouth[0] * W)), int(round(top + mouth[1] * H)), f["work"])
        sheet.alpha_composite(l.img, (i * CELL, 0))
    return sheet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--kind", required=True, choices=sorted(KINDS))
    ap.add_argument("--width", type=int, help="기본 몸 가로 px (crab 24 · boss 26 · baby 22)")
    ap.add_argument("--colors", type=int, default=20)
    ap.add_argument("--redraw-eyes", action="store_true", help="AI 눈 · 입을 지우고 둥근 눈 + 반짝으로 다시 그린다")
    ap.add_argument("--mouth", default="0.5,0.62", help="혀가 나올 입 자리 (몸 비율 x,y)")
    ap.add_argument("--eyes", help="눈 자리를 몸 비율로 직접: x1,y1,x2,y2 (둥근 눈 + 반짝을 새로 찍는다)")
    ap.add_argument("--eye-size", type=int, default=2)
    ap.add_argument("--eye-ring", action="store_true", help="눈 둘레에 밝은 흰자 (게 눈자루)")
    ap.add_argument("--eye-lid", action="store_true", help="반쯤 감은 눈꺼풀 (금두꺼비 대장)")
    ap.add_argument("--cheeks", help="볼 자리 몸 비율 x1,y1,x2,y2")
    ap.add_argument("--sand", help="모래에 파묻힌 게 그림 (crab 숨기 칸)")
    ap.add_argument("--angry", action="store_true", help="반짝 대신 밝은 눈동자 + 성난 눈썹 (요괴 모래게)")
    ap.add_argument("--peek", type=float, help="crab 숨기 칸: 대기 칸 가운데 위에서 이 비율만큼 (뿔 · 눈) 잘라 모래 위로 빼꼼 (요괴 모래게)")
    ap.add_argument("--fly", help="날개 편 그림 (sparrow · baby_sparrow 날갯짓 칸)")
    ap.add_argument("--fly-eyes", help="날개 편 그림의 눈 자리 (몸 비율 x,y, 옆모습이라 하나)")
    ap.add_argument("--eye-color", help="눈 색 r,g,b (요괴 까마귀 붉은 눈)")
    ap.add_argument("--flip", action="store_true", help="그림을 좌우로 뒤집는다 (참새가 오른쪽을 보고 나왔을 때)")
    ap.add_argument("--out", help="기본: assets/creatures/<규격 이름>.png")
    ap.add_argument("--preview", help="4배 확대 미리보기 PNG")
    a = ap.parse_args()
    mouth = tuple(float(v) for v in a.mouth.split(","))
    pairs = lambda t: [tuple(v) for v in zip(*[iter(float(x) for x in t.split(","))] * 2)] if t else []
    sheet = build(a.src, a.kind, a.width, a.colors, a.redraw_eyes, a.sand, mouth,
                  pairs(a.eyes), a.eye_size, a.eye_ring, pairs(a.cheeks), a.eye_lid, a.fly, a.flip, pairs(a.fly_eyes),
                  tuple(int(v) for v in a.eye_color.split(",")) if a.eye_color else EYE, a.peek, a.angry)
    out = a.out or os.path.join(ROOT, "assets", "creatures", KINDS[a.kind]["out"] + ".png")
    sheet.save(out)
    print(out)
    if a.preview:
        bg = Image.new("RGBA", sheet.size, (236, 222, 190, 255))
        bg.alpha_composite(sheet)
        bg.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(a.preview)


if __name__ == "__main__":
    main()
