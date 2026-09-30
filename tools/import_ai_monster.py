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

실행: python3 tools/import_ai_monster.py 그림.png --kind crab|boss|baby [--width 24] [--colors 20] [--preview 미리보기.png]
      (--sand 숨은그림.png: 모래에 파묻힌 게 그림이 따로 있으면 숨기 칸에 그걸 쓴다)
"""
import argparse
import os

from PIL import Image

from import_ai_character import pixelize, white_to_alpha
from import_ai_slime import draw_face, find_face, inpaint, largest_blob, peel_halo, soften_edges
from make_character_sheet import grade_p1, outline
from make_gold_toad_sheet import GOLD, GOLD_L, TONGUE, TONGUE_D, TONGUE_L
from make_slime_sheet import CELL, Layer
from make_wild_sheets import GOLD as SAND_GOLD, SAND, SAND_D, SAND_L, ellipse

ROOT = os.path.join(os.path.dirname(__file__), "..")
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
}


def load_figure(src):
    fig = peel_halo(largest_blob(white_to_alpha(Image.open(src))))
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


def build(src, kind, width=None, colors=20, redraw_eyes=False, sand_src=None, mouth=(0.5, 0.62)):
    spec = KINDS[kind]
    width = width or spec["width"]
    fig = load_figure(src)
    eyes = None
    if redraw_eyes:
        eyes, found_mouth, erase = find_face(fig)
        inpaint(fig, erase)
        mouth = found_mouth or mouth
    pal_img = fig.convert("RGB").quantize(colors, method=Image.Quantize.FASTOCTREE)
    pal = pal_img.getpalette()
    base_h = round(width * fig.height / fig.width)
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
        W = max(8, round(width * f["sx"]))
        H = max(8, min(CELL - f["lift"], round(base_h * f["sy"])))
        body = pixelize(fig, pal_img, pal, W, H)
        had_line = soften_edges(body) and had_line
        if f.get("step"):
            body = shove_legs(body, f["step"])
        if stalks is None and kind == "crab":
            stalks = eye_stalks(body)
        left = CELL // 2 - W // 2 + f.get("dx", 0)
        top = CELL - f["lift"] - H
        bodies.alpha_composite(body, (i * CELL + left, top))
        placed.append((left, top, W, H))
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
            peek = f["sand"]
            # 눈자루를 모래 더미 뒤에 먼저 놓고, 그 위에 모래를 덮는다
            if stalks:
                sheet.alpha_composite(stalks, (i * CELL + CELL // 2 - stalks.width // 2, 28 - 2 * peek - stalks.height))
            sand_mound(l, peek)
            mound = l.img
            outline(mound, CELL)
            grade_p1(mound)
            sheet.alpha_composite(mound, (i * CELL, 0))
            continue
        left, top, W, H = p
        if eyes:
            draw_face(l, left, top, W, H, eyes, mouth)
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
    ap.add_argument("--sand", help="모래에 파묻힌 게 그림 (crab 숨기 칸)")
    ap.add_argument("--out", help="기본: assets/creatures/<규격 이름>.png")
    ap.add_argument("--preview", help="4배 확대 미리보기 PNG")
    a = ap.parse_args()
    mouth = tuple(float(v) for v in a.mouth.split(","))
    sheet = build(a.src, a.kind, a.width, a.colors, a.redraw_eyes, a.sand, mouth)
    out = a.out or os.path.join(ROOT, "assets", "creatures", KINDS[a.kind]["out"] + ".png")
    sheet.save(out)
    print(out)
    if a.preview:
        bg = Image.new("RGBA", sheet.size, (236, 222, 190, 255))
        bg.alpha_composite(sheet)
        bg.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(a.preview)


if __name__ == "__main__":
    main()
