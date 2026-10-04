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
      6~7등신 실제 비율 그림 (2026-10-04 그림 방향 "섞어서") 은 --tall, 검은 바지면 --dark-pants.

주인공 (2026-10-04, 사용자 AI 그림 A 돌아온 젊은이: /mnt/project-files/design/protagonist/ai/ai_a.png)
  python3 tools/import_ai_character.py ai_a.png --name protagonist --height 46 --width 18 --tall --hair-span 0.2 --front-hair 0.2
  python3 tools/make_wear_sheets.py   (장비를 새 몸에 맞춤. 모자는 머리 폭에 맞춰 줄어든다)
  B 개척단 단원 (ai_b.png) 은 같은 옵션 + --dark-pants
"""
import argparse
import colorsys
import json
import os
import sys
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
# --tall: 6~7등신 실제 비율 그림 (2026-10-04 그림 방향 "섞어서", 주인공 돌아온 젊은이). 머리가 작아 부위 높이가 다르다
TALL_PROBES = {
    "hair": [(0.3, 0.7, 0.01, 0.05)],
    "skin": [(0.42, 0.62, 0.13, 0.17)],
    "top": [(0.25, 0.75, 0.22, 0.42)],
    "pants": [(0.25, 0.45, 0.6, 0.75), (0.55, 0.75, 0.6, 0.75)],
    "shoes": [(0.1, 0.9, 0.95, 1.0)],
}
TALL_SPAN = {"hair": (0, 0.2), "skin": (0, 1), "top": (0.14, 0.56), "pants": (0.48, 0.95), "shoes": (0.9, 1)}


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
                    if p[3] and (part in DARK_PARTS or lum(p) >= 60):
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
    if lum(c) < 60 and (best not in DARK_PARTS or (best == "hair" and yf > DARK_HAIR_MAX)):
        return None
    return best


# 이 높이 아래의 어두운 선은 머리카락으로 치지 않는다 (체크무늬 셔츠 선이 머리카락이 되지 않게). --dark-hair
DARK_HAIR_MAX = 1.0
# 어두워도 선이 아니라 그 부위로 치는 곳. --dark-pants 면 검은 바지도 (개척단 단원)
DARK_PARTS = ["hair", "shoes"]


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
    """patch: {"neutral_purple": true (선택), "hue_shift": [[h0, h1, dh, sat]] (선택), "colors": {"r": [r,g,b], ...}, "down": [{"at": [x, y], "rows": ["..rr..", ...]}], "up": [...], "side": [...]}
    rows 의 글자 하나가 픽셀 하나, '.' 는 그대로 둔다."""
    cols = {k: tuple(v) + (255,) for k, v in patch.get("colors", {}).items()}
    for view, img in views.items():
        for h0, h1, dh, smul in patch.get("hue_shift", []):
            # [시작 색상각, 끝 색상각, 옮길 각도, 채도 배율]: P1 보정에서 누렇게 뜬 옷 색을 제 색으로 (예: 쑥색 두루마기)
            px = img.load()
            for y in range(img.height):
                for x in range(img.width):
                    r, g, b, a = px[x, y]
                    hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                    if a and ss > 0.12 and h0 <= hh * 360 <= h1:
                        nr, ng, nb = colorsys.hsv_to_rgb((hh + dh / 360) % 1, min(1, ss * smul), vv)
                        px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
        if patch.get("neutral_purple"):
            # 회색 · 흰 머리의 짙은 그늘이 P1 보정에서 보랏빛이 되는 것을 같은 밝기의 따뜻한 회색으로 되돌린다
            px = img.load()
            for y in range(img.height):
                for x in range(img.width):
                    r, g, b, a = px[x, y]
                    if a and b > r + 8 and b > g + 20:
                        l = int(lum((r, g, b)))
                        px[x, y] = (min(255, l + 10), l, max(0, l - 4), a)
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


def move_px(img, pts, dx, dy, fill=None):
    """pts 자리 픽셀을 (dx, dy) 옮긴다. 빈 자리는 fill(x, y) 색.
    fill 이 없으면 빈 자리 뒤쪽 (옮긴 반대 방향) 이웃이 몸이면 원래 색을 남기고 (팔이 1px 늘어남, 어깨에 틈 없음), 끝이면 투명."""
    out = img.copy()
    src, dst = img.load(), out.load()
    w, h = img.size
    inside = set(pts)
    for x, y in pts:
        if fill:
            dst[x, y] = fill(x, y)
            continue
        bx, by = x - dx, y - dy
        keep = 0 <= bx < w and 0 <= by < h and (bx, by) not in inside and src[bx, by][3]
        dst[x, y] = src[x, y] if keep else (0, 0, 0, 0)
    for x, y in pts:
        if 0 <= x + dx < w and 0 <= y + dy < h:
            dst[x + dx, y + dy] = src[x, y]
    return out


def arm_points(part, hip, side_view):
    """부위 지도에서 팔(살 · 윗도리 소매) 아랫부분 픽셀. 앞 · 뒤는 바지 폭 바깥, 옆은 몸통 위 살색."""
    w, h = part.size
    pm = part.load()
    is_ = lambda x, y, *names: pm[x, y][3] and pm[x, y][:3] in [PART_COLORS[n] for n in names]
    if side_view:
        # 옆모습 팔: 어깨 아래 ~ 엉덩이 사이 살색 (얼굴은 어깨 위라 빠진다)
        return [(x, y) for y in range(round(h * 0.5), hip + 2) for x in range(w) if is_(x, y, "skin")]
    pants = [x for x in range(w) if is_(x, hip + 1, "pants", "top")]
    if not pants:
        return []
    lo, hi = min(pants), max(pants)
    # 팔 아랫부분 (아래팔 · 손)만: 어깨까지 옮기면 어깨에 틈이 생긴다
    return [(x, y) for y in range(round(h * 0.5), hip + 3) for x in range(w)
            if (x < lo or x > hi) and is_(x, y, "skin", "top")]


def frames(fig, side_view, hip, part):
    """[대기0, 대기1, 걷기 contact_a, pass_a, contact_b, pass_b]

    2026-10-01 사용자 "캐릭터 걷는 모션이 너무 어색": 예전엔 앞 · 뒤는 엉덩이 아래 반쪽을 통째로 2px 올리고,
    옆은 다리를 1px 씩만 벌려 미끄러지듯 보였다. 이제
      - 내딛는 칸(contact)에서 몸이 1px 내려앉고, 지나가는 칸(pass)에서 1px 올라간다 (반대였음)
      - 앞 · 뒤: 무릎 아래만 들고 (반바지가 찢어지지 않게), 반대쪽 팔 아랫부분이 1px 흔들린다
      - 옆: 다리를 엉덩이에서 발끝으로 갈수록 벌린다 (뒷다리는 어둡게), 팔이 앞뒤로 1px 흔들린다
    부위 지도(part)로 팔을 찾고, 같은 옮김을 부위 지도에도 해야 장비 덧그림이 맞는다 → frames 는 (그림, 부위 지도) 둘 다 돌려준다.
    """
    w, h = fig.size
    mid = w // 2
    knee = hip + (h - hip) // 2
    both = lambda f: (f(fig), f(part))
    idle1 = both(lambda im: shift(im, (0, 0, w, hip - 2), 0, 1))  # 숨쉬기: 윗몸 1px 내려감
    arms = arm_points(part, hip, side_view)
    left_arm = [(x, y) for x, y in arms if x < mid]
    right_arm = [(x, y) for x, y in arms if x >= mid]
    if not side_view:
        def step(lift_left):
            def f(im):
                # 무릎 아래 한쪽 발 들기 + 반대쪽 팔 앞으로 (1px 위) · 같은 쪽 팔 뒤로 (1px 아래) + 몸 1px 내려앉기
                box = (0, knee, mid, h) if lift_left else (mid, knee, w, h)
                out = shift(im, box, 0, -2)
                fwd, back = (right_arm, left_arm) if lift_left else (left_arm, right_arm)
                out = move_px(out, fwd, 0, -1)
                out = move_px(out, [(x, y) for x, y in back], 0, 1)
                return shift(out, (0, 0, w, knee), 0, 1)
            return f
        ca, cb = both(step(True)), both(step(False))
        pa = both(lambda im: shift(im, (0, 0, w, h), 0, -1))
        pb = pa
    else:
        def stride(d, dark_back):
            def f(im):
                # 엉덩이 아래를 앞다리(+) · 뒷다리(-) 둘로: 아래로 갈수록 벌어진다. 뒷다리는 조금 어둡게.
                src = im.load()
                legs_front = Image.new("RGBA", (w, h), (0, 0, 0, 0))
                legs_back = Image.new("RGBA", (w, h), (0, 0, 0, 0))
                lf, lb = legs_front.load(), legs_back.load()
                for y in range(hip, h):
                    off = round(d * (y - hip + 1) / (h - hip))
                    for x in range(w):
                        c = src[x, y]
                        if not c[3]:
                            continue
                        if 0 <= x + off < w:
                            lf[x + off, y] = c
                        if 0 <= x - off < w:
                            k = 0.82 if dark_back and im is fig else 1.0
                            lb[x - off, y] = (int(c[0] * k), int(c[1] * k), int(c[2] * k), c[3])
                out = im.copy()
                out.paste((0, 0, 0, 0), (0, hip, w, h))
                out.alpha_composite(legs_back)
                out.alpha_composite(legs_front)
                # 팔은 뒷다리 쪽으로 (다리와 반대로) 1px, 비운 자리는 바로 옆 몸통 색
                o = out.load()
                out = move_px(out, arms, -1 if d > 0 else 1, 0,
                              lambda x, y: o[x + (1 if d > 0 else -1), y] if 0 <= x + (1 if d > 0 else -1) < w and (x + (1 if d > 0 else -1), y) not in arms else o[x, y])
                return shift(out, (0, 0, w, hip), 0, 1)
            return f
        ca, cb = both(stride(3, True)), both(stride(-3, True))
        def passing(im):
            # 지나가는 칸: 다리 모으고 몸 1px 들썩, 뒷발 1px 들기
            out = shift(im, (0, 0, w, h), 0, -1)
            return shift(out, (0, h - 3, mid, h), 0, -1)
        pa = both(passing)
        pb = pa
    return [(fig, part), idle1, ca, pa, cb, pb]


def build_sheet(views, parts, hip):
    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    parts_sheet = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for r, (key, sv) in enumerate([("down", False), ("up", False), ("side", True)]):
        for c, (fr, pt) in enumerate(frames(views[key], sv, hip, parts[key])):
            pos = (c * CELL + (CELL - fr.width) // 2, r * CELL + CELL - fr.height)
            sheet.alpha_composite(fr, pos)
            parts_sheet.alpha_composite(pt, pos)
    return sheet, parts_sheet


def rewalk(name):
    """이미 만든 시트의 대기 0칸(손대지 않은 몸)에서 숨쉬기 · 걷기 칸만 다시 만든다. 원본 그림 · 옵션 없이도 된다.
    (2026-10-01 걷기 모션 고칠 때 다섯 캐릭터에 썼다. 그 뒤엔 make_wear_sheets.py 를 다시 돌린다.)"""
    sheet_path = os.path.join(ROOT, "assets", "characters", f"{name}.png")
    parts_path = os.path.join(PARTS_DIR, f"{name}.png")
    sheet, parts = Image.open(sheet_path).convert("RGBA"), Image.open(parts_path).convert("RGBA")
    new_sheet = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    new_parts = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for r, sv in enumerate((False, False, True)):
        cell = (0, r * CELL, CELL, r * CELL + CELL)
        fig, part = sheet.crop(cell), parts.crop(cell)
        box = fig.getbbox()
        fig, part = fig.crop(box), part.crop(box)
        hip = round(fig.height * 0.68)
        for c, (fr, pt) in enumerate(frames(fig, sv, hip, part)):
            pos = (c * CELL + box[0], r * CELL + box[1])
            new_sheet.alpha_composite(fr, pos)
            new_parts.alpha_composite(pt, pos)
    new_sheet.save(sheet_path)
    new_parts.save(parts_path)
    print("rewalk", name)


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--rewalk":
        for name in sys.argv[2:]:
            rewalk(name)
        return
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
    ap.add_argument("--tall", action="store_true", help="6~7등신 실제 비율 그림 (부위 높이를 작은 머리에 맞춤). --hair-span 은 0.2 쯤")
    ap.add_argument("--dark-pants", action="store_true", help="검은 바지: 어두운 색도 바지로 친다")
    ap.add_argument("--order", default="down,up,side", help="그림 속 왼쪽부터 순서 (정면 down · 뒷모습 up · 옆 side). 예: down,side,up")
    a = ap.parse_args()

    global DARK_HAIR_MAX
    DARK_HAIR_MAX = a.dark_hair
    if a.dark_pants:
        DARK_PARTS.append("pants")
    if a.tall:
        PROBES.clear()
        PROBES.update(TALL_PROBES)
        SPAN.update(TALL_SPAN)
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
    sheet, parts_sheet = build_sheet(views, parts, hip)
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
