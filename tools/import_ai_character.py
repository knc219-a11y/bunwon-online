"""AI가 그린 3방향 캐릭터 그림 → 48x48 도트 캐릭터 시트 + 부위 지도.

입력: 정면 · 뒷모습 · 오른쪽 옆모습이 가로로 나란히 선 그림 한 장 (투명 바탕, 흰 바탕 모두 됨).
      프롬프트는 /mnt/project-files/design/graphics-slice/character-prompt.md.
출력: assets/characters/<name>.png  (288x144, 행 0 아래 · 1 위 · 2 옆, 열 0-1 대기 · 2-5 걷기. docs/sprites.md 규격)
      tools/char_parts/<name>.png    (같은 크기의 부위 지도. 입는 장비를 새 몸에 맞출 때 쓴다: make_wear_sheets.py)

하는 일
  1. 그림 셋을 잘라 공통 색 24개로 줄인다 (AI 그림의 번짐 · 잡티 제거).
  2. 한 칸에서 가장 많은 색을 골라 --height 높이로 줄인다. 가로는 --width 로 따로 정해 몸을 통통하게 만든다
     (AI 그림은 48px 로 줄이면 몸이 20px 로 가늘어진다. 원래 캐릭터는 30px).
  3. 대비를 누그러뜨린다: 까만 머리 · 선을 따뜻한 짙은 색으로 올리고, 바깥 테두리는 안쪽 색을 어둡게 한 보랏빛 선으로 바꾼다.
     그 다음 P1 따뜻한 파스텔 보정 (make_character_sheet.grade_p1).
  4. --patch JSON 이 있으면 픽셀을 손질한다 (48px 에서 뭉개지는 안경 · 눈 등, 예: tools/char_parts/player_patch.json).
  5. 걷기 4 · 숨쉬기 2 프레임을 다리 · 윗몸을 옮겨 만든다.

실행: python3 tools/import_ai_character.py 그림.png --name player [--width 30] [--height 46] [--patch tools/char_parts/player_patch.json]
      그림 순서가 정면 · 옆 · 뒤면 --order down,side,up
      --preview 파일.png 를 주면 4배 확대 미리보기도 저장한다.
"""
import argparse
import colorsys
import json
import os
from collections import Counter

from PIL import Image

from make_character_sheet import CELL, COLS, ROWS, grade_p1

ROOT = os.path.join(os.path.dirname(__file__), "..")
PARTS_DIR = os.path.join(os.path.dirname(__file__), "char_parts")

# 부위 지도 색 (make_wear_sheets.py 와 같이 쓴다)
PART_COLORS = {
    "hair": (40, 40, 40), "skin": (250, 200, 160), "top": (160, 160, 160), "pants": (70, 100, 200),
    "shoes": (120, 60, 20),
}
PART_OF = {v: k for k, v in PART_COLORS.items()}


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def split_figures(im):
    a = im.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    w, h = im.size
    cols = [any(a.getpixel((x, y)) for y in range(h)) for x in range(w)]
    runs, s = [], None
    for x, c in enumerate(cols + [False]):
        if c and s is None:
            s = x
        if not c and s is not None:
            if x - s > 8:
                runs.append((s, x))
            s = None
    figs = []
    for s, e in runs:
        f = im.crop((s, 0, e, h))
        figs.append(f.crop(f.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox()))
    if len(figs) != 3:
        raise SystemExit(f"그림이 {len(figs)}개로 잘렸다. 정면 · 뒷모습 · 옆모습 셋이 떨어져 서 있어야 한다.")
    return figs


def white_to_alpha(im):
    """흰 바탕이면 가장자리에서 이어진 흰색을 투명으로."""
    im = im.convert("RGBA")
    if im.getchannel("A").getextrema()[0] > 0:
        px = im.load()
        w, h = im.size
        stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for x in (0, w - 1) for y in range(h)]
        seen = set()
        while stack:
            x, y = stack.pop()
            if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
                continue
            seen.add((x, y))
            r, g, b, _ = px[x, y]
            if min(r, g, b) < 235:
                continue
            px[x, y] = (0, 0, 0, 0)
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im


# 부위별 색을 뽑는 정면 그림 속 자리 (가로 x0, x1, 세로 y0, y1 비율). 어떤 옷이든 색으로 나눈다.
PROBES = {
    "hair": [(0.3, 0.7, 0.02, 0.12)],
    "skin": [(0.4, 0.6, 0.36, 0.41)],
    "top": [(0.35, 0.65, 0.52, 0.6), (0.4, 0.6, 0.64, 0.68)],
    "pants": [(0.2, 0.4, 0.72, 0.8), (0.6, 0.8, 0.72, 0.8)],
    "shoes": [(0.1, 0.9, 0.95, 1.0)],
}
# 부위가 나올 수 있는 높이 (0 머리끝 ~ 1 발끝)
SPAN = {"hair": (0, 0.5), "skin": (0, 1), "top": (0.3, 0.85), "pants": (0.55, 1), "shoes": (0.85, 1)}


def part_refs(front):
    """정면 그림에서 부위마다 대표 색 (가장 많은 색 3개). 한 색은 가장 많이 나온 부위 하나에만."""
    w, h = front.size
    px = front.load()
    count = {}
    for part, boxes in PROBES.items():
        c = Counter()
        for x0, x1, y0, y1 in boxes:
            for y in range(int(y0 * h), max(int(y0 * h) + 1, int(y1 * h))):
                for x in range(int(x0 * w), max(int(x0 * w) + 1, int(x1 * w))):
                    p = px[x, min(y, h - 1)]
                    if p[3] and (part in ("hair", "shoes") or lum(p) >= 60):
                        c[p[:3]] += 1
        count[part] = c
    refs = {}
    for part, c in count.items():
        refs[part] = [col for col, n in c.most_common(3) if all(n >= count[o][col] for o in count if o != part)]
    return refs


def classify(c, yf, refs):
    """가장 가까운 부위 대표 색으로 고른다. 어두운 선은 None (이웃 부위를 따른다)."""
    best, bd = None, 1e9
    for part, cols in refs.items():
        if not SPAN[part][0] <= yf <= SPAN[part][1]:
            continue
        for r in cols:
            d = sum((a - b) ** 2 for a, b in zip(c, r))
            if d < bd:
                best, bd = part, d
    if lum(c) < 60 and (best not in ("hair", "shoes") or (best == "hair" and yf > DARK_HAIR_MAX)):
        return None
    return best


# 이 높이 아래의 어두운 선은 머리카락으로 치지 않는다 (체크무늬 셔츠 선이 머리카락이 되지 않게). --dark-hair
DARK_HAIR_MAX = 1.0


def soften(c, lift, sat):
    """어두운 색을 끌어올리고 채도를 살짝 내린다 (대비 누그러뜨리기)."""
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in c))
    l2 = lift + l * (1 - lift)
    s2 = s * sat
    if l < 0.25:  # 까만색은 살짝 보랏빛 도는 짙은 회색으로 (원래 캐릭터 머리색 50,48,56 근처)
        h, s2 = 0.75, max(s2, 0.1)
    r, g, b = colorsys.hls_to_rgb(h, l2, s2)
    return (round(r * 255), round(g * 255), round(b * 255))


def pixelize(f, pal_img, pal, w, h):
    q = f.convert("RGB").quantize(palette=pal_img, dither=Image.Dither.NONE)
    fa = f.getchannel("A")
    sx, sy = w / f.width, h / f.height
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    po, pq, pa = out.load(), q.load(), fa.load()
    col = lambda i: tuple(pal[i * 3:i * 3 + 3])
    for y in range(h):
        for x in range(w):
            x0, x1 = int(x / sx), max(int(x / sx) + 1, int((x + 1) / sx))
            y0, y1 = int(y / sy), max(int(y / sy) + 1, int((y + 1) / sy))
            cs = [pq[i, j] for i in range(x0, min(x1, f.width)) for j in range(y0, min(y1, f.height)) if pa[i, j] > 128]
            if len(cs) * 2 < (x1 - x0) * (y1 - y0):
                continue
            dark = [c for c in cs if lum(col(c)) < 60]
            pick = Counter(dark).most_common(1)[0][0] if len(dark) >= len(cs) * 0.34 else Counter(cs).most_common(1)[0][0]
            po[x, y] = (*col(pick), 255)
    return out


def fill_holes(img):
    """가로로 늘리며 생긴 1px 빈틈을 이웃 색으로 메운다."""
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(1, w - 1):
            if px[x, y][3] == 0 and px[x - 1, y][3] and px[x + 1, y][3]:
                px[x, y] = px[x - 1, y]


def part_map(img, refs):
    """부위 지도. 어두운 선은 가장 많은 이웃 부위를 따른다."""
    w, h = img.size
    src = img.load()
    lab = {}
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                lab[x, y] = classify(src[x, y][:3], y / (h - 1), refs)
    for _ in range(4):
        for (x, y), v in list(lab.items()):
            if v is None:
                ns = Counter(lab.get((x + dx, y + dy)) for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                ns.pop(None, None)
                if y / (h - 1) > DARK_HAIR_MAX:
                    ns.pop("hair", None)
                if ns:
                    lab[x, y] = ns.most_common(1)[0][0]
    # 윗도리 색과 비슷한 볼 · 입 같은 작은 조각 (3픽셀 이하 덩어리) 은 이웃 부위로. --dark-hair 아래 머리카락 부스러기도
    for part in ("top", "hair"):
        seen = set()
        for start in [k for k, v in lab.items() if v == part]:
            if start in seen:
                continue
            comp, stack = [], [start]
            seen.add(start)
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if n not in seen and lab.get(n) == part:
                        seen.add(n)
                        stack.append(n)
            if len(comp) <= 3 and (part == "top" or min(y for _, y in comp) / (h - 1) > DARK_HAIR_MAX):
                for x, y in comp:
                    ns = Counter(lab.get((x + dx, y + dy)) for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                    ns.pop(None, None)
                    ns.pop(part, None)
                    if ns:
                        lab[x, y] = ns.most_common(1)[0][0]
    # 바지 윗줄 아래로 내려온 윗도리 색 (다리 사이 선 등) 은 바지로
    rows = [Counter(v for (x, yy), v in lab.items() if yy == y) for y in range(h)]
    pants_top = next((y for y in range(h) if rows[y]["pants"] > max(2, rows[y]["top"])), h)
    for (x, y), v in lab.items():
        if v == "top" and y > pants_top + 1:
            lab[x, y] = "pants"
    parts = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = parts.load()
    for (x, y), v in lab.items():
        dst[x, y] = (*PART_COLORS[v or "top"], 255)
    return parts


def recolor_body(img, parts, lift, sat):
    """대비 누그러뜨리기. 머리카락 밖의 까만 선과 바깥 테두리는 이웃 색을 어둡게 한 보랏빛 선으로 바꾼다
    (make_character_sheet.outline 과 같은 부드러운 선). 테두리 픽셀을 알려 준다."""
    w, h = img.size
    px, pp = img.load(), parts.load()
    dark = {(x, y) for y in range(h) for x in range(w)
            if px[x, y][3] and lum(px[x, y]) < 60 and PART_OF.get(pp[x, y][:3]) != "hair"}
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                px[x, y] = (*soften(px[x, y][:3], lift, sat), 255)
    edge = set()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] and any(not (0 <= x + dx < w and 0 <= y + dy < h) or not px[x + dx, y + dy][3]
                                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge.add((x, y))
    src = img.copy().load()
    for x, y in edge | dark:
        inner = [src[x + dx, y + dy][:3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1))
                 if 0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3] and (x + dx, y + dy) not in edge | dark]
        base = max(inner, key=lum) if inner else src[x, y][:3]
        px[x, y] = outline_color(base)
    return edge


def outline_color(c):
    """make_character_sheet.outline 과 같은 식 (이웃 색을 어둡고 보랏빛으로)."""
    r, g, b = c[:3]
    return (int(r * 0.35 + 40 * 0.65 * 0.6), int(g * 0.35 + 24 * 0.6), int(b * 0.35 + 48 * 0.6), 255)


def apply_patch(views, patch):
    """patch: {"colors": {"r": [r,g,b], ...}, "down": [{"at": [x, y], "rows": ["..rr..", ...]}], "up": [...], "side": [...]}
    rows 의 글자 하나가 픽셀 하나, '.' 는 그대로 둔다."""
    cols = {k: tuple(v) + (255,) for k, v in patch.get("colors", {}).items()}
    for view, img in views.items():
        for block in patch.get(view, []):
            x0, y0 = block["at"]
            for j, row in enumerate(block["rows"]):
                for i, ch in enumerate(row):
                    if ch != ".":
                        img.putpixel((x0 + i, y0 + j), cols[ch])


# ---------- 프레임 ----------
def shift(img, box, dx, dy):
    out = img.copy()
    part = img.crop(box)
    out.paste(Image.new("RGBA", part.size, (0, 0, 0, 0)), box[:2])
    out.alpha_composite(part, (box[0] + dx, box[1] + dy))
    return out


def frames(fig, side_view, hip):
    """[대기0, 대기1, 걷기 contact_a, pass_a, contact_b, pass_b]"""
    w, h = fig.size
    mid = w // 2
    idle1 = shift(fig, (0, 0, w, hip - 2), 0, 1)  # 숨쉬기: 윗몸 1px 내려감
    up = shift(fig, (0, 0, w, h), 0, -1)  # 걸음 사이 몸이 1px 들썩
    if not side_view:
        ca = shift(fig, (0, hip, mid, h), 0, -2)  # 왼발 들기
        cb = shift(fig, (mid, hip, w, h), 0, -2)  # 오른발 들기
    else:
        def stride(d):
            # 엉덩이 아래 줄마다 뒤쪽 반은 -d, 앞쪽 반은 +d 로 벌리고 가운데 빈틈은 가운데 색으로 메운다
            out = fig.copy()
            src, dst = fig.load(), out.load()
            for y in range(hip, h):
                row = [src[x, y] for x in range(w)]
                for x in range(w):
                    sx_ = x + d if x < mid - d else (x - d if x >= mid + d else mid - (1 if x < mid else 0))
                    dst[x, y] = row[sx_] if 0 <= sx_ < w else (0, 0, 0, 0)
            return out
        ca, cb = stride(1), stride(-1)
    return [fig, idle1, ca, up, cb, up]


def build_sheet(views, hip):
    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for r, (fig, sv) in enumerate([(views["down"], False), (views["up"], False), (views["side"], True)]):
        for c, fr in enumerate(frames(fig, sv, hip)):
            sheet.alpha_composite(fr, (c * CELL + (CELL - fr.width) // 2, r * CELL + CELL - fr.height))
    return sheet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--name", default="player")
    ap.add_argument("--height", type=int, default=46)
    ap.add_argument("--width", type=int, default=30, help="정면 그림 가로 픽셀 (몸 두께)")
    ap.add_argument("--colors", type=int, default=24)
    ap.add_argument("--lift", type=float, default=0.1, help="어두운 색을 얼마나 올릴지 (0 그대로)")
    ap.add_argument("--sat", type=float, default=0.85, help="채도 배율")
    ap.add_argument("--patch")
    ap.add_argument("--preview")
    ap.add_argument("--out")
    ap.add_argument("--hair-span", type=float, default=0.5, help="뒷모습 · 옆모습에서 머리카락이 내려올 수 있는 높이 (0 머리끝 ~ 1 발끝). 포니테일이면 0.75")
    ap.add_argument("--front-hair", type=float, default=0.5, help="정면에서 머리카락이 내려올 수 있는 높이 (포니테일은 앞에서 안 보여 0.4 쯤)")
    ap.add_argument("--dark-hair", type=float, default=1.0, help="이 높이 아래 어두운 선은 머리카락이 아니다 (체크무늬 셔츠면 0.42 쯤)")
    ap.add_argument("--sleeves", action="store_true", help="윗도리 색을 소매(팔 윗쪽)에서도 뽑는다. 멜빵바지처럼 가슴을 다른 옷이 덮을 때")
    ap.add_argument("--order", default="down,up,side", help="그림 속 왼쪽부터 순서 (정면 down · 뒷모습 up · 옆 side). 예: down,side,up")
    a = ap.parse_args()

    global DARK_HAIR_MAX
    DARK_HAIR_MAX = a.dark_hair
    if a.sleeves:
        PROBES["top"] = PROBES["top"] + [(0.08, 0.22, 0.44, 0.54), (0.78, 0.92, 0.44, 0.54)]
    figs = split_figures(white_to_alpha(Image.open(a.src)))
    order = a.order.split(",")
    figs = [figs[order.index(k)] for k in ("down", "up", "side")]
    strip = Image.new("RGBA", (sum(f.width for f in figs), max(f.height for f in figs)))
    x = 0
    for f in figs:
        strip.alpha_composite(f, (x, 0))
        x += f.width
    pal_img = strip.convert("RGB").quantize(a.colors, method=Image.Quantize.MEDIANCUT)
    pal = pal_img.getpalette()
    sx = a.width / figs[0].width
    views = {}
    for key, f in zip(("down", "up", "side"), figs):
        views[key] = pixelize(f, pal_img, pal, max(1, round(f.width * sx)), a.height)
        fill_holes(views[key])
    refs = part_refs(views["down"])
    # 옆모습은 오른쪽을 봐야 한다. 얼굴(살색)이 머리카락보다 왼쪽이면 뒤집는다.
    SPAN["hair"] = (0, a.hair_span)
    pm = part_map(views["side"], refs).load()
    sw = views["side"].width
    cx = lambda part: sum(x for x in range(sw) for y in range(a.height // 2) if pm[x, y][:3] == PART_COLORS[part]) / max(1, sum(
        1 for x in range(sw) for y in range(a.height // 2) if pm[x, y][:3] == PART_COLORS[part]))
    if cx("skin") < cx("hair"):
        views["side"] = views["side"].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        print("옆모습이 왼쪽을 봐서 뒤집음")
    print("부위 색", refs)
    parts = {}
    for k, v in views.items():
        SPAN["hair"] = (0, a.front_hair if k == "down" else a.hair_span)
        parts[k] = part_map(v, refs)
    for k, v in views.items():
        for x, y in recolor_body(v, parts[k], a.lift, a.sat):
            p = parts[k].getpixel((x, y))
            parts[k].putpixel((x, y), (*p[:3], 254))
        grade_p1(v)
    if a.patch:
        with open(a.patch, encoding="utf-8") as fp:
            apply_patch(views, json.load(fp))
    hip = round(a.height * 0.68)
    sheet = build_sheet(views, hip)
    parts_sheet = build_sheet(parts, hip)
    out = a.out or os.path.join(ROOT, "assets", "characters", f"{a.name}.png")
    sheet.save(out)
    os.makedirs(PARTS_DIR, exist_ok=True)
    parts_sheet.save(os.path.join(PARTS_DIR, f"{a.name}.png"))
    print("sheet", out, "figures", [views[k].size for k in ("down", "up", "side")])
    if a.preview:
        bg = Image.new("RGBA", sheet.size, (112, 160, 96, 255))
        bg.alpha_composite(sheet)
        pv = Image.new("RGBA", (sheet.width, sheet.height * 2), (0, 0, 0, 255))
        pv.paste(bg, (0, 0))
        pv.paste(parts_sheet, (0, sheet.height))
        pv.resize((pv.width * 4, pv.height * 4), Image.NEAREST).save(a.preview)


if __name__ == "__main__":
    main()
