"""AI가 그린 슬라임 정면 그림 한 장 → 슬라임 시트 (32x32 칸 10개, make_slime_sheet.py 와 같은 규격).

입력: 흰 바탕(또는 투명 바탕)에 슬라임 하나가 정면으로 앉은 그림. 프롬프트는 /mnt/project-files/design/slime-ai/prompt.md.
출력: assets/creatures/slime_<속성>.png (320x32, 0-1 대기 · 2-5 깡충 · 6-9 물뿜기)

하는 일
  1. 흰 바탕을 지우고 슬라임만 잘라 작업 크기(가로 176px)로 줄인다.
  2. 눈 · 입 · 볼을 찾아 지운다 (22px 로 줄이면 뭉개지므로 나중에 사람들과 같은 둥근 눈 + 반짝으로 다시 그린다).
  3. 프레임마다 make_slime_sheet 의 IDLE · HOP · WATER 몸 크기(가로 w, 높이 h, 뜬 높이 lift)로 눌렀다 늘여 줄인다.
     기본 몸 가로 22px (2026-09-27 결정 M 크기).
  4. 까만 선은 이웃 색을 어둡게 한 보랏빛 선으로 누그러뜨리고 P1 파스텔 보정. 물뿜기 물줄기는 make_slime_sheet 와 같이 코드로 그린다.
  5. 찾은 자리에 얼굴을 다시 그린다.

실행: python3 tools/import_ai_slime.py 그림.png --element water [--width 22] [--colors 20] [--preview 미리보기.png]
"""
import argparse
import os
from collections import Counter

from PIL import Image

from import_ai_character import lum, outline_color, pixelize, soften, white_to_alpha
from make_character_sheet import grade_p1, outline
from make_slime_sheet import CELL, HOP, IDLE, WATER, Layer, draw_spout

ROOT = os.path.join(os.path.dirname(__file__), "..")
WORK_W = 176

# 얼굴 색 (사람들 얼굴 손질과 같은 색: tools/char_parts/*_patch.json)
EYE, GLINT = (58, 38, 50), (255, 248, 240)
MOUTH, CHEEK = (176, 96, 92), (244, 164, 150)


def largest_blob(im):
    """알파가 있는 가장 큰 덩어리만 남기고 잘라낸다 (흰 바탕 잡티 · 따로 떨어진 물방울 제거)."""
    a = im.getchannel("A").load()
    w, h = im.size
    seen, best = set(), []
    for y in range(h):
        for x in range(w):
            if a[x, y] > 128 and (x, y) not in seen:
                blob, stack = [], [(x, y)]
                seen.add((x, y))
                while stack:
                    cx, cy = stack.pop()
                    blob.append((cx, cy))
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and a[nx, ny] > 128:
                            seen.add((nx, ny))
                            stack.append((nx, ny))
                if len(blob) > len(best):
                    best = blob
    keep = set(best)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    po, pi = out.load(), im.load()
    for x, y in keep:
        po[x, y] = pi[x, y][:3] + (255,)
    return out.crop(out.getbbox())


def components(mask, w, h):
    seen, out = set(), []
    for p in mask:
        if p in seen:
            continue
        comp, stack = [], [p]
        seen.add(p)
        while stack:
            x, y = stack.pop()
            comp.append((x, y))
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if q in mask and q not in seen:
                    seen.add(q)
                    stack.append(q)
        out.append(comp)
    return out


def find_face(fig):
    """눈 둘 · 입 · 볼 자리 (그림 크기 비율)와 지울 픽셀 집합."""
    w, h = fig.size
    px = fig.load()
    solid = lambda x, y: 0 <= x < w and 0 <= y < h and px[x, y][3]
    # 바깥 테두리에 닿지 않은 안쪽 어두운 덩어리 = 눈 · 입 후보
    dark = {(x, y) for y in range(h) for x in range(w) if px[x, y][3] and lum(px[x, y]) < 85}
    edge_near = lambda comp: any(not solid(x + dx, y + dy) for x, y in comp for dx in (-3, 0, 3) for dy in (-3, 0, 3))
    blobs = [c for c in components(dark, w, h) if len(c) >= w * h * 0.0008 and not edge_near(c)]
    blobs.sort(key=len, reverse=True)
    if len(blobs) < 2:
        raise SystemExit("눈을 찾지 못했다. 몸 안에 까만 눈 두 개가 또렷한 그림이어야 한다.")
    box = lambda c: (min(x for x, _ in c), min(y for _, y in c), max(x for x, _ in c), max(y for _, y in c))
    center = lambda c: (sum(x for x, _ in c) / len(c) / w, sum(y for _, y in c) / len(c) / h)
    # 가장 큰 둘 중 비슷한 높이 · 크기인 쌍을 눈으로
    eyes = sorted(blobs[:2], key=lambda c: center(c)[0])
    erase = set()
    for c in eyes:
        x0, y0, x1, y1 = box(c)
        # 눈 속 반짝(흰 점)까지 같이 지운다
        erase |= {(x, y) for x in range(x0 - 2, x1 + 3) for y in range(y0 - 2, y1 + 3) if solid(x, y)}
    ey = max(center(c)[1] for c in eyes)
    ex0, ex1 = center(eyes[0])[0], center(eyes[1])[0]
    mouth = None
    for c in blobs[2:]:
        cx, cy = center(c)
        if cy > ey and ex0 < cx < ex1:
            mouth = (cx, cy)
            x0, y0, x1, y1 = box(c)
            erase |= {(x, y) for x in range(x0 - 2, x1 + 3) for y in range(y0 - 2, y1 + 3) if solid(x, y)}
            break
    # 볼: 분홍 (빨강이 초록보다 훨씬 크고 파랑이 초록 이상). 황토 몸은 파랑 < 초록이라 섞이지 않는다
    pink = {(x, y) for y in range(h) for x in range(w)
            if px[x, y][3] and px[x, y][0] > px[x, y][1] + 35 and px[x, y][2] >= px[x, y][1] - 5 and lum(px[x, y]) > 90}
    cheeks = [c for c in components(pink, w, h) if len(c) >= w * h * 0.001]
    for c in cheeks:
        x0, y0, x1, y1 = box(c)
        erase |= {(x, y) for x in range(x0 - 1, x1 + 2) for y in range(y0 - 1, y1 + 2) if solid(x, y)}
    return [center(c) for c in eyes], mouth, erase


def inpaint(fig, erase):
    """지운 자리를 바깥 이웃 색으로 차례차례 메운다."""
    px = fig.load()
    w, h = fig.size
    todo = set(erase)
    while todo:
        done = {}
        for x, y in todo:
            ns = [px[x + dx, y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if 0 <= x + dx < w and 0 <= y + dy < h and (x + dx, y + dy) not in todo and px[x + dx, y + dy][3]]
            if ns:
                done[x, y] = tuple(sum(n[i] for n in ns) // len(ns) for i in range(3)) + (255,)
        if not done:
            break
        for p, c in done.items():
            px[p] = c
        todo -= set(done)


def soften_edges(img):
    """까만 테두리 · 선을 이웃 색을 어둡게 한 보랏빛 선으로. 원래 테두리가 거의 없으면 새로 두른다."""
    w, h = img.size
    px = img.load()
    edge = {(x, y) for y in range(h) for x in range(w) if px[x, y][3] and any(
        not (0 <= x + dx < w and 0 <= y + dy < h) or not px[x + dx, y + dy][3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
    dark = {(x, y) for y in range(h) for x in range(w) if px[x, y][3] and lum(px[x, y]) < 70}
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                px[x, y] = (*soften(px[x, y][:3], 0.08, 0.95), 255)
    src = img.copy().load()
    fix = (edge & dark) | dark
    for x, y in fix:
        inner = [src[x + dx, y + dy][:3] for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2)
                 if 0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3] and (x + dx, y + dy) not in fix]
        base = Counter(inner).most_common(1)[0][0] if inner else src[x, y][:3]
        px[x, y] = outline_color(base)
    return len(edge & dark) >= len(edge) * 0.5


def draw_face(l, left, top, W, H, eyes, mouth):
    eye_h = 3 if H >= 14 else 2
    pos = []
    for fx, fy in eyes:
        ex = int(round(left + fx * W - 1))
        ey = int(round(top + fy * H - eye_h / 2))
        pos.append((ex, ey))
        l.rect(ex, ey, ex + 1, ey + eye_h - 1, EYE)
        l.px(ex, ey, GLINT)
    (lx, ly), (rx, _) = pos
    if mouth:
        mx = int(round(left + mouth[0] * W))
        my = max(ly + eye_h, int(round(top + mouth[1] * H)))
    else:
        mx, my = (lx + rx + 2) // 2, ly + eye_h + 1
    l.rect(mx - 1, my, mx, my, MOUTH)
    l.px(lx - 2, ly + eye_h, CHEEK)
    l.px(rx + 3, ly + eye_h, CHEEK)


def build(src, element, width=22, colors=20):
    fig = largest_blob(white_to_alpha(Image.open(src)))
    fig = fig.resize((WORK_W, round(WORK_W * fig.height / fig.width)), Image.LANCZOS)
    a = fig.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    fig.putalpha(a)
    eyes, mouth, erase = find_face(fig)
    inpaint(fig, erase)
    pal_img = fig.convert("RGB").quantize(colors, method=Image.Quantize.MEDIANCUT)
    pal = pal_img.getpalette()
    base_h = round(width * fig.height / fig.width)
    bodies, faces = Image.new("RGBA", (CELL * 10, CELL), (0, 0, 0, 0)), []
    frames = IDLE + HOP + WATER
    had_line = True
    for i, f in enumerate(frames):
        W = max(8, round(f["w"] / 22 * width))
        H = max(8, round(base_h * f["h"] / 16))
        body = pixelize(fig, pal_img, pal, W, H)
        had_line = soften_edges(body) and had_line
        left = CELL // 2 - W // 2
        top = CELL - f["lift"] - H
        bodies.alpha_composite(body, (i * CELL + left, max(0, top)))
        faces.append((left, top, W, H))
    if not had_line:
        outline(bodies, CELL)
    grade_p1(bodies)
    sheet = Image.new("RGBA", bodies.size, (0, 0, 0, 0))
    sheet.alpha_composite(bodies)
    for i, (f, (left, top, W, H)) in enumerate(zip(frames, faces)):
        l = Layer()
        draw_face(l, left, top, W, H, eyes, mouth)
        if f.get("spout"):
            draw_spout(l, f["spout"], top)
        sheet.alpha_composite(l.img, (i * CELL, 0))
    return sheet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--element", required=True, help="water / earth (시트 이름 slime_<element>.png)")
    ap.add_argument("--width", type=int, default=22, help="기본 몸 가로 px")
    ap.add_argument("--colors", type=int, default=20)
    ap.add_argument("--out", help="기본: assets/creatures/slime_<element>.png")
    ap.add_argument("--preview", help="4배 확대 미리보기 PNG")
    a = ap.parse_args()
    sheet = build(a.src, a.element, a.width, a.colors)
    out = a.out or os.path.join(ROOT, "assets", "creatures", f"slime_{a.element}.png")
    sheet.save(out)
    print(out)
    if a.preview:
        bg = Image.new("RGBA", sheet.size, (236, 222, 190, 255))
        bg.alpha_composite(sheet)
        bg.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(a.preview)


if __name__ == "__main__":
    main()
