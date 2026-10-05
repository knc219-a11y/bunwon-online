"""SpriteCook 으로 뽑은 주인공 (앞 · 뒤 · 옆 한 장 + 방향마다 걷기 8칸) → 몸 시트 + 부위 지도.

2026-10-05 사용자 "주인공 남자도 다시 뽑아서 연결동작까지 부드럽게". 돌아온 젊은이 (A) 를 SpriteCook
generate_game_art 로 앞 · 뒤 · 옆 4장 뽑아 사용자가 2번을 고르고, 방향마다 animate_game_art (pixel-engine-v1.1,
8칸) 로 걷기를 만들었다. 그림 원본: /mnt/project-files/design/protagonist/spritecook/
  hero_a_{down,up,side}.png = 고른 그림을 방향마다 자른 것 (대기 칸), walk_{down,up,side}_url.webp = 걷기 8칸.

시트 (20칸 x 3줄, 칸 48): 0-1 대기 (1 은 윗몸 1px 내려 숨쉬기), 2-5 · 16-19 걷기 8칸, 6-15 는 공격 칸 자리
(tools/make_attack_frames.py 가 채운다). 걷기 순서는 Character.WALK8_COLUMNS = [2, 16, 3, 17, 4, 18, 5, 19].
옆모습 걷기는 움직임 2칸 (다리를 벌린 칸) 부터 시작해서 2 열이 디딤 칸이 된다 (내려베기 바탕 칸, make_attack_frames).

줄이기: 걷기 칸을 키 46px 로 BOX 로 줄이고 모든 칸을 한 팔레트에 맞춘다 (칸마다 색이 흔들리지 않게).
  앞 · 뒤 걷기는 다가오며 커지므로 칸마다 키 46 으로 맞추고, 옆 걷기는 한 배율이라 걸음 따라 몸이 오르내린다.
  머리 가운데를 칸 가운데에, 발끝을 칸 바닥에 놓는다 (움직임 칸은 몸이 옆으로 떠다니므로).
부위 지도는 import_ai_character.part_map 을 칸마다 돌린다 (--tall 부위 높이, 머리카락 0.2).

칼 공격 (2026-10-05 사용자 "칼만 먼저"): 방향마다 animate_game_art 8칸 (melee_{down,up,side}.webp, 칼을 뽑아 한 번 벤다).
  움직임 2-7 칸 (뽑기 · 치켜들기 · 베기 · 마무리 · 거두기) 을 근거리 열 6-9 · 20-21 에 넣는다 (Character.MELEE6_COLUMNS).
  칼 · 팔이 48 칸 밖으로 나가므로 나눈다: 대기 몸 윤곽 (2px 넓힘) 안 = 몸 칸 (장비가 맞춰진다),
  밖 = assets/weapons/protagonist_melee.png (80칸, 무기 덧그림 자리, 장비 위에 그린다). 둘을 겹치면 원래 칸 그대로다.

실행 (순서 중요):
  python3 tools/import_spritecook_hero.py            (대기 · 걷기 → 20칸 시트)
  python3 tools/make_attack_frames.py                (활 · 지팡이 칸, 무기 그림)
  python3 tools/import_spritecook_hero.py --melee    (칼 칸을 SpriteCook 움직임으로 바꿈 → 22칸)
  python3 tools/make_wear_sheets.py
"""
import argparse
import os
import sys

from PIL import Image, ImageSequence

sys.path.insert(0, os.path.dirname(__file__))
import import_ai_character as iac  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
CELL, ROWS, COLS = 48, 3, 20
HEIGHT = 46
DIRS = ("down", "up", "side")
# 걷기 칸 k (움직임 칸 번호, 옆모습은 2 부터 돌린 순서) 가 들어갈 열
WALK8_COLUMNS = [2, 16, 3, 17, 4, 18, 5, 19]
WALK_START = {"down": 0, "up": 0, "side": 2}


def walk_frames(src, d):
    im = Image.open(os.path.join(src, f"walk_{d}_url.webp"))
    fr = [f.convert("RGBA").copy() for f in ImageSequence.Iterator(im)]
    s = WALK_START[d]
    return fr[s:] + fr[:s]


def solid(img):
    a = img.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), a)
    return out


def shrink(img, k, pal):
    img = solid(img)
    img = img.crop(img.getbbox())
    w, h = max(1, round(img.width * k)), max(1, round(img.height * k))
    small = img.resize((w, h), Image.BOX)
    rgb = small.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
    out = Image.new("RGBA", small.size, (0, 0, 0, 0))
    out.paste(rgb, (0, 0), small.getchannel("A").point(lambda v: 255 if v > 110 else 0))
    return out.crop(out.getbbox())


def head_x(img):
    a = img.getchannel("A")
    xs = [x for y in range(max(1, int(img.height * 0.12))) for x in range(img.width) if a.getpixel((x, y))]
    return (min(xs) + max(xs)) // 2 if xs else img.width // 2


def place(img):
    c = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    c.alpha_composite(img, (CELL // 2 - head_x(img), CELL - img.height))
    return c


def edges(img):
    """바깥 테두리 픽셀 (부위 지도에서 알파 254: make_wear_sheets 가 장비 윤곽에 쓴다)."""
    a = img.getchannel("A").load()
    w, h = img.size
    out = []
    for y in range(h):
        for x in range(w):
            if a[x, y] and any(not (0 <= x + dx < w and 0 <= y + dy < h) or not a[x + dx, y + dy]
                               for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.append((x, y))
    return out


def breathe(img):
    """윗몸 (허리 위) 을 1px 내린다."""
    box = img.getbbox()
    hip = box[1] + round((box[3] - box[1]) * 0.55)
    out = img.copy()
    top = img.crop((0, 0, CELL, hip))
    out.paste((0, 0, 0, 0), (0, 0, CELL, hip + 1))
    out.alpha_composite(top, (0, 1))
    return out


MELEE_FRAMES = [2, 3, 4, 5, 6, 7]
MELEE6_COLUMNS = [6, 7, 8, 9, 20, 21]
WCELL = 80
# 공격 종류마다: 움직임 파일 이름, 쓸 움직임 칸, 넣을 열 (Character.MELEE6 · BOW6 · STAFF6_COLUMNS)
ATTACKS = {
    "melee": ("melee_{d}.webp", MELEE_FRAMES, MELEE6_COLUMNS),
    "bow": ("bowstaff/bow_{d}.webp", [2, 3, 4, 5, 6, 7], [10, 11, 12, 22, 23, 24]),
    "staff": ("bowstaff/staff_{d}.webp", [2, 3, 4, 5, 6, 7], [13, 14, 15, 25, 26, 27]),
}
SHEET_COLS = 28


def dilate(mask, n):
    m = set(mask)
    for _ in range(n):
        m |= {(x + dx, y + dy) for x, y in m for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))}
    return m


def attack(a, kind):
    pattern, frames_used, columns = ATTACKS[kind]
    sheet_path = os.path.join(ROOT, "assets", "characters", f"{a.name}.png")
    parts_path = os.path.join(iac.PARTS_DIR, f"{a.name}.png")
    sheet = Image.open(sheet_path).convert("RGBA")
    parts = Image.open(parts_path).convert("RGBA")
    if sheet.width < CELL * SHEET_COLS:
        wide = Image.new("RGBA", (CELL * SHEET_COLS, CELL * ROWS), (0, 0, 0, 0))
        wp = wide.copy()
        wide.paste(sheet, (0, 0))
        wp.paste(parts, (0, 0))
        sheet, parts = wide, wp
    stills = {d: solid(Image.open(os.path.join(a.src, f"hero_a_{d}.png")).convert("RGBA")) for d in DIRS}
    strip = Image.new("RGBA", (sum(s.width for s in stills.values()), max(s.height for s in stills.values())))
    x = 0
    for s in stills.values():
        strip.alpha_composite(s, (x, 0))
        x += s.width
    pal = strip.convert("RGB").quantize(a.colors, method=Image.Quantize.MEDIANCUT)
    iac.PROBES.clear()
    iac.PROBES.update(iac.TALL_PROBES)
    iac.SPAN.update(iac.TALL_SPAN)
    iac.SPAN["hair"] = (0, 0.2)
    front = sheet.crop((0, 0, CELL, CELL))
    refs = iac.part_refs(front.crop(front.getbbox()))
    over = Image.new("RGBA", (WCELL * SHEET_COLS, WCELL * ROWS), (0, 0, 0, 0))
    over_path = os.path.join(ROOT, "assets", "weapons", f"{a.name}_{kind}.png")
    if os.path.exists(over_path):
        # 다른 종류 · 아직 안 만든 방향의 칸은 그대로 둔다
        old = Image.open(over_path).convert("RGBA")
        over.paste(old.crop((0, 0, min(old.width, over.width), old.height)), (0, 0))
    pad = (WCELL - CELL) // 2
    for r, d in enumerate(DIRS):
        path = os.path.join(a.src, pattern.format(d=d))
        if not os.path.exists(path):
            continue
        for col in columns:
            over.paste((0, 0, 0, 0), (col * WCELL, r * WCELL, col * WCELL + WCELL, r * WCELL + WCELL))
        fr = [f.convert("RGBA").copy() for f in ImageSequence.Iterator(Image.open(path))]
        bb0 = solid(fr[0]).getbbox()
        k = HEIGHT / (bb0[3] - bb0[1])
        w, h = round(fr[0].width * k), round(fr[0].height * k)
        small = []
        for f in fr:
            sm = f.resize((w, h), Image.BOX)
            rgb = sm.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
            o = Image.new("RGBA", sm.size, (0, 0, 0, 0))
            # 가는 칼날은 줄이면 옅어지므로 문턱을 낮춘다
            o.paste(rgb, (0, 0), sm.getchannel("A").point(lambda v: 255 if v > 70 else 0))
            small.append(o)
        b0 = small[0].getbbox()
        f0 = small[0].crop(b0)
        dx, dy = CELL // 2 - head_x(f0) - b0[0], CELL - b0[3]
        idle = sheet.crop((0, r * CELL, CELL, r * CELL + CELL)).getchannel("A").load()
        body = dilate({(x, y) for y in range(CELL) for x in range(CELL) if idle[x, y]}, 2)
        for col, i in zip(columns, frames_used):
            full = Image.new("RGBA", (WCELL, WCELL), (0, 0, 0, 0))
            full.alpha_composite(small[i], (dx + pad, dy + pad)) if dx + pad >= 0 and dy + pad >= 0 else None
            fp = full.load()
            inside = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            outside = Image.new("RGBA", (WCELL, WCELL), (0, 0, 0, 0))
            ip, op = inside.load(), outside.load()
            for y in range(WCELL):
                for x in range(WCELL):
                    p = fp[x, y]
                    if not p[3]:
                        continue
                    if (x - pad, y - pad) in body:
                        ip[x - pad, y - pad] = p
                    else:
                        op[x, y] = p
            box = inside.getbbox()
            at = (col * CELL, r * CELL)
            sheet.paste((0, 0, 0, 0), (at[0], at[1], at[0] + CELL, at[1] + CELL))
            parts.paste((0, 0, 0, 0), (at[0], at[1], at[0] + CELL, at[1] + CELL))
            sheet.alpha_composite(inside, at)
            if box:
                fig = inside.crop(box)
                pm = iac.part_map(fig, refs)
                for x, y in edges(fig):
                    pm.putpixel((x, y), (*pm.getpixel((x, y))[:3], 254))
                parts.alpha_composite(pm, (at[0] + box[0], at[1] + box[1]))
            over.alpha_composite(outside, (col * WCELL, r * WCELL))
    sheet.save(sheet_path)
    parts.save(parts_path)
    over.save(over_path)
    print(kind, sheet.size, "overlay", over.size)
    if a.preview:
        k = 4
        pv = Image.new("RGBA", (WCELL * 6 * k, WCELL * ROWS * k), (92, 98, 84, 255))
        for r in range(ROWS):
            for j, col in enumerate(columns):
                c = Image.new("RGBA", (WCELL, WCELL), (0, 0, 0, 0))
                c.alpha_composite(sheet.crop((col * CELL, r * CELL, col * CELL + CELL, r * CELL + CELL)), (pad, pad))
                c.alpha_composite(over.crop((col * WCELL, r * WCELL, col * WCELL + WCELL, r * WCELL + WCELL)))
                pv.alpha_composite(c.resize((WCELL * k, WCELL * k), Image.NEAREST), (j * WCELL * k, r * WCELL * k))
        pv.save(a.preview)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="/mnt/project-files/design/protagonist/spritecook")
    ap.add_argument("--name", default="protagonist")
    ap.add_argument("--colors", type=int, default=32)
    ap.add_argument("--preview")
    ap.add_argument("--melee", action="store_true", help="칼 공격 칸을 SpriteCook 움직임으로 (make_attack_frames.py 뒤에)")
    ap.add_argument("--attack", choices=sorted(ATTACKS), action="append",
                    help="이 공격 칸을 SpriteCook 움직임으로 (여러 번 줄 수 있다, make_attack_frames.py 뒤에)")
    a = ap.parse_args()
    kinds = (a.attack or []) + (["melee"] if a.melee else [])
    if kinds:
        for kind in kinds:
            attack(a, kind)
        return

    stills = {d: solid(Image.open(os.path.join(a.src, f"hero_a_{d}.png")).convert("RGBA")) for d in DIRS}
    walks = {d: walk_frames(a.src, d) for d in DIRS}
    # 한 팔레트: 고른 그림 셋 (움직임 칸은 색이 조금 바래므로 원본 색에 맞춘다)
    strip = Image.new("RGBA", (sum(s.width for s in stills.values()), max(s.height for s in stills.values())))
    x = 0
    for s in stills.values():
        strip.alpha_composite(s, (x, 0))
        x += s.width
    pal = strip.convert("RGB").quantize(a.colors, method=Image.Quantize.MEDIANCUT)

    cells = {}
    for d in DIRS:
        idle = place(shrink(stills[d], HEIGHT / stills[d].getbbox()[3], pal))
        cells[d, 0], cells[d, 1] = idle, breathe(idle)
        side_k = HEIGHT / max(f.getbbox()[3] - f.getbbox()[1] for f in walks[d])
        for i, f in enumerate(walks[d]):
            bb = solid(f).getbbox()
            k = side_k if d == "side" else HEIGHT / (bb[3] - bb[1])
            cells[d, WALK8_COLUMNS[i]] = place(shrink(f, k, pal))

    # 부위 지도: 정면 대기 칸에서 부위 색을 뽑고 칸마다 나눈다 (import_ai_character --tall --hair-span 0.2 --front-hair 0.2)
    iac.PROBES.clear()
    iac.PROBES.update(iac.TALL_PROBES)
    iac.SPAN.update(iac.TALL_SPAN)
    iac.SPAN["hair"] = (0, 0.2)
    front = cells["down", 0].crop(cells["down", 0].getbbox())
    refs = iac.part_refs(front)
    print("부위 색", refs)

    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    parts = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for r, d in enumerate(DIRS):
        for (dd, col), img in cells.items():
            if dd != d:
                continue
            box = img.getbbox()
            fig = img.crop(box)
            pm = iac.part_map(fig, refs)
            for x, y in edges(fig):
                p = pm.getpixel((x, y))
                pm.putpixel((x, y), (*p[:3], 254))
            at = (col * CELL, r * CELL)
            sheet.alpha_composite(img, at)
            parts.alpha_composite(pm, (at[0] + box[0], at[1] + box[1]))
    out = os.path.join(ROOT, "assets", "characters", f"{a.name}.png")
    sheet.save(out)
    parts.save(os.path.join(iac.PARTS_DIR, f"{a.name}.png"))
    print("sheet", out, sheet.size)
    if a.preview:
        bg = Image.new("RGBA", (sheet.width, sheet.height * 2), (112, 160, 96, 255))
        bg.alpha_composite(sheet)
        bg.alpha_composite(parts, (0, sheet.height))
        bg.resize((bg.width * 3, bg.height * 3), Image.NEAREST).save(a.preview)


if __name__ == "__main__":
    main()
