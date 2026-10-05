"""PixelLab 이 게임 크기 그대로 뽑은 몬스터 한 장 → 8칸 시트 (늘이거나 줄이지 않는다).

import_ai_monster.py 는 큰 AI 그림을 줄여서 픽셀로 만든다. PixelLab 그림은 이미 칸 크기 픽셀 그림이라
다시 줄이면 망가지므로, 픽셀을 그대로 두고 줄을 1px 씩 밀어서 칸을 만든다.

귀여리 방패 도마뱀 (2026-10-05, PixelLab generate-image-v2 64x64, 사용자가 16장 중 8번 · 13번 둘 다 고름):
  0-1 대기 (윗몸 숨쉬기 1px), 2-5 걷기 (몸 들썩 + 발 줄 번갈아 밀기), 6 창 당김 예고 (윗몸 뒤로 젖힘),
  7 방패 내림 = 칠 틈 (방패를 아래로 내리고 윗몸 앞으로 숙임, 방패가 비킨 자리는 왼쪽 몸 색으로 채움)

실행 (방패 원은 그림마다 다르다: 가운데 x,y 와 반지름):
  python3 tools/import_pixellab_monster.py shield_07.png --out wild_shield_lizard --shield 47,35,12.4
  python3 tools/import_pixellab_monster.py shield_12.png --out wild_shield_lizard_b --shield 46,35,12.6
그림 원본: /mnt/project-files/design/guiyeo-tall/pixellab/shield_*.png
  (2026-10-05 SpriteCook animate_game_art pixel-engine-v1.5 창 찌르기 8칸을 6 · 7 칸에 쓰려고 80칸으로 키움:
   python3 tools/import_pixellab_monster.py shield_07_onetail.png --out wild_shield_lizard --shield 47,35,12.4
       --cell 80 --thrust spritecook/thrust_v3.webp   (13번은 thrust_b.webp, 칸 속 자리 --thrust-at 은 그림마다 확인))
  (2026-10-05 원본은 꼬리가 몸 앞뒤로 두 개라서 앞 꼬리를 지운 shield_*_onetail.png 를 쓴다)
  python3 tools/import_pixellab_monster.py shield_07_onetail.png --out wild_shield_lizard --shield 47,35,12.4
  python3 tools/import_pixellab_monster.py shield_12_onetail.png --out wild_shield_lizard_b --shield 46,35,12.6

도마뱀 족장 (2026-10-05, SpriteCook generate_game_art 124칸 4장 중 사용자가 2번 = chief_01 을 고름):
  124px 그림을 키 80px 로 줄인다 (--height: BOX 로 줄이고 원본 색에 다시 맞춘다), 96칸 가운데 아래에 놓는다.
  방패를 내리는 칸이 없으므로 7 은 숨 고름 (윗몸을 2px 눌러 앞으로 숙임).
  python3 tools/import_pixellab_monster.py chief_01.png --out wild_lizard_chief --height 80 --cell 96
  그림 원본: /mnt/project-files/design/guiyeo-tall/spritecook/chief_*.png

아기 도마뱀 (2026-10-05, SpriteCook generate_game_art 4장 중 사용자가 3번 = baby_02 를 고름, 족장 그림을 화풍 참고로):
  python3 tools/import_pixellab_monster.py baby_02.png --out baby_lizard --height 20 --cell 32 --baby
  그림 원본: /mnt/project-files/design/guiyeo-tall/spritecook/baby_*.png

소내섬 용 · 독꼬리 와이번 (2026-10-05, SpriteCook generate_game_art 2장씩, 기본값 1번):
  python3 tools/import_pixellab_monster.py dragon_00.png --out wild_dragon --height 90 --cell 96
  python3 tools/import_pixellab_monster.py wyvern_00.png --out wild_wyvern --wyvern --width 46 --cell 64
  그림 원본: /mnt/project-files/design/sonae-tall/spritecook/
"""
import argparse
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def shear(img, shifts):
    """줄마다 x 로 민다. shifts(y) -> int."""
    w, h = img.size
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for y in range(h):
        d = shifts(y)
        row = img.crop((0, y, w, y + 1))
        out.alpha_composite(row, (d, y)) if d >= 0 else out.alpha_composite(row.crop((-d, 0, w, 1)), (0, y))
    return out


def vshift(img, cut, d):
    """cut 줄 위쪽을 d px 위(-)/아래(+)로 민다 (발은 그대로)."""
    w, h = img.size
    out = img.copy()
    top = img.crop((0, 0, w, cut))
    out.paste((0, 0, 0, 0), (0, 0, w, cut + max(d, 0)))
    if d > 0:
        # 아래로 누르면 cut 줄 바로 아래를 덮는다: 맨 아랫줄 하나를 버린다
        out.paste(img.crop((0, cut, w, h - 0)), (0, cut))
        out.alpha_composite(top.crop((0, 0, w, cut - d)), (0, d))
        out.alpha_composite(img.crop((0, cut - 1, w, cut)), (0, cut - 1)) if False else None
    else:
        out.alpha_composite(top, (0, d))
        # 비는 줄은 cut 바로 위 줄을 늘여 메운다
        for k in range(-d):
            out.alpha_composite(img.crop((0, cut - 1, w, cut)), (0, cut - 1 - k))
    return out


def stride(img, foot, d):
    """foot 줄 아래 (발) 의 왼쪽 반은 -d, 오른쪽 반은 +d 로 민다."""
    w, h = img.size
    out = img.copy()
    out.paste((0, 0, 0, 0), (0, foot, w, h))
    xs = [x for y in range(foot, h) for x in range(w) if img.getpixel((x, y))[3]]
    mid = (min(xs) + max(xs)) // 2 if xs else w // 2
    left = img.crop((0, foot, mid, h))
    right = img.crop((mid, foot, w, h))
    out.alpha_composite(left, (max(0, -d), foot)) if -d >= 0 else out.alpha_composite(left.crop((d, 0, mid, h - foot)), (0, foot))
    out.alpha_composite(right, (mid + d, foot)) if d >= 0 else out.alpha_composite(right, (mid + d, foot))
    return out


def disk_mask(size, cx, cy, r):
    m = Image.new("L", size, 0)
    px = m.load()
    for y in range(size[1]):
        for x in range(size[0]):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                px[x, y] = 255
    return m


def shield_down(img, cx, cy, r, dy=5, dx=-1):
    """방패를 내린다: 방패 원을 떼서 dy 아래로, 비킨 자리는 같은 줄 왼쪽 몸 색으로 채운다."""
    w, h = img.size
    m = disk_mask(img.size, cx, cy, r)
    shield = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shield.paste(img, (0, 0), m)
    body = img.copy()
    body.paste((0, 0, 0, 0), (0, 0), m)
    bp = body.load()
    mp = m.load()
    lit = lambda c: c[3] and sum(c[:3]) > 210
    filled = []
    # 위에서부터: 바로 위 몸 색을 끌어내리고, 없으면 왼쪽 색. 방패 위로 삐져나온 빈 공간은 그대로 둔다
    for y in range(1, h):
        for x in range(w):
            if not mp[x, y] or x > cx - 1:
                continue
            up, left = bp[x, y - 1], bp[x - 1, y]
            if lit(up):
                bp[x, y] = up
            elif lit(left):
                bp[x, y] = left
            else:
                continue
            filled.append((x, y))
    # 채운 몸의 오른쪽 끝에 윤곽선
    for x, y in filled:
        if x + 1 < w and not bp[x + 1, y][3]:
            bp[x + 1, y] = (24, 30, 22, 255)
    body.alpha_composite(shield, (dx, dy))
    return body


def shrink(img, height, colors=256):
    """BOX 로 줄이고, 원본 색 몇 가지에 다시 맞춰 흐려진 색을 픽셀 색으로 돌린다."""
    img = img.crop(img.getbbox())
    w = round(img.width * height / img.height)
    pal = img.convert("RGB").quantize(colors, method=Image.Quantize.MEDIANCUT)
    small = img.resize((w, height), Image.BOX)
    rgb = small.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
    out = Image.new("RGBA", small.size, (0, 0, 0, 0))
    a = small.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    out.paste(rgb, (0, 0), a)
    return out


def place(img, cell):
    """cell 칸 가운데 아래에 놓는다."""
    out = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    out.alpha_composite(img, ((cell - img.width) // 2, cell - img.height))
    return out


def build(img, cx, cy, r):
    h = img.size[1]
    ys = [y for y in range(h) for x in range(img.size[0]) if img.getpixel((x, y))[3]]
    top, bottom = min(ys), max(ys)
    hip = top + int((bottom - top) * 0.62)
    foot = top + int((bottom - top) * 0.86)
    lean_back = lambda y: -2 if y < top + (bottom - top) * 0.3 else (-1 if y < hip else 0)
    lean_fwd = lambda y: 2 if y < top + (bottom - top) * 0.3 else (1 if y < hip else 0)
    frames = [
        img,
        vshift(img, hip, 1),
        stride(vshift(img, foot, -1), foot, 1),
        stride(img, foot, -1),
        stride(vshift(img, foot, -1), foot, -1),
        stride(img, foot, 1),
        shear(img, lean_back),
        shear(shield_down(img, cx, cy, r), lean_fwd) if r else shear(vshift(img, hip, 2), lean_fwd),
    ]
    return frames


def lift(img, d):
    """통째로 d px 위로 (깡충)."""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(img.crop((0, d, img.width, img.height)), (0, 0))
    return out


def build_baby(img):
    """아기 네발 10칸: 0-1 대기, 2-5 걷기, 6-9 일 (냄비뚜껑 들고 장보기: 깡충 · 고개 들기)."""
    frames = build(img, 0, 0, 0)[:6]
    h = img.size[1]
    ys = [y for y in range(h) for x in range(img.size[0]) if img.getpixel((x, y))[3]]
    top, bottom = min(ys), max(ys)
    head_up = lambda y: -1 if y < top + (bottom - top) * 0.45 else 0
    frames += [lift(shear(img, head_up), 2), frames[3], lift(shear(img, head_up), 2), img]
    return frames


def fold(img, cut, k):
    """cut 줄 위 (날개) 를 k 배 높이로 눌러 cut 에 붙인다 (날갯짓 · 날개 접기)."""
    w, h = img.size
    top = img.crop((0, 0, w, cut))
    nh = max(1, round(cut * k))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(img.crop((0, cut, w, h)), (0, cut))
    out.alpha_composite(top.resize((w, nh), Image.NEAREST), (0, cut - nh))
    return out


def build_wyvern(img, cell, air=8):
    """나는 와이번 8칸 (make_act5_sheets.wyvern 과 같은 뜻):
    0-1 맴돌기, 2-5 날기 (날개를 눌렀다 폈다 + 몸 1px 들썩), 6 내려꽂기 예고 (날개 접고 머리 숙임),
    7 내려앉아 숨 고름 (날개 반쯤 접고 칸 바닥에 섬). 나는 칸은 바닥에서 air px 띄운다."""
    ys = [y for y in range(img.height) for x in range(img.width) if img.getpixel((x, y))[3]]
    cut = min(ys) + int((max(ys) - min(ys)) * 0.5)

    def put(f, up, dx=0):
        o = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        o.alpha_composite(f, ((cell - f.width) // 2 + dx, cell - f.height - up))
        return o

    flap = [1.0, 0.86, 0.7, 0.86]
    frames = [put(img, air), put(img, air - 1)]
    frames += [put(fold(img, cut, flap[i]), air - (i % 2)) for i in range(4)]
    dive = fold(img, cut, 0.6).rotate(-22, Image.NEAREST, expand=True)
    frames.append(put(dive.crop(dive.getbbox()), air, 1))
    frames.append(put(fold(img, cut, 0.55), 0))
    return frames


def with_thrust(img, frames, path, cell, which, at):
    """원본 칸을 cell 칸 가운데 아래에 놓고, 6 · 7 칸은 SpriteCook 움직임 칸으로 바꾼다.
    움직임은 원본보다 6px 큰 칸 (가장자리 여백) 이라 창이 앞으로 길게 나간다: 그래서 칸을 키운다 (늘이지 않음).
    색은 원본 색에 다시 맞춘다 (움직임 칸은 조금 바랜 색으로 나온다)."""
    from PIL import ImageSequence
    w, h = img.size
    ox, oy = (cell - w) // 2, cell - h
    dx, dy = (int(v) for v in at.split(","))
    pal = img.convert("RGB").quantize(256, method=Image.Quantize.MEDIANCUT)
    moves = [f.convert("RGBA").copy() for f in ImageSequence.Iterator(Image.open(path))]
    out = []
    for f in frames:
        o = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        o.alpha_composite(f, (ox, oy))
        out.append(o)
    for col, k in zip((6, 7), (int(v) for v in which.split(","))):
        m = moves[k]
        rgb = m.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
        snap = Image.new("RGBA", m.size, (0, 0, 0, 0))
        snap.paste(rgb, (0, 0), m.getchannel("A").point(lambda v: 255 if v > 110 else 0))
        o = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        o.alpha_composite(snap, (ox - dx, oy - dy))
        out[col] = o
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--out", required=True)
    ap.add_argument("--shield", help="방패 원: 가운데 x,y,반지름 (없으면 7 칸은 숨 고름)")
    ap.add_argument("--height", type=int, help="이 키로 줄인다 (큰 그림일 때)")
    ap.add_argument("--cell", type=int, help="칸 크기 (없으면 그림 높이)")
    ap.add_argument("--thrust", help="SpriteCook 창 찌르기 움직임 (webp 8칸): 6 · 7 칸을 이걸로 바꾼다")
    ap.add_argument("--thrust-frames", default="3,5", help="6 칸 (창 당김) · 7 칸 (찌른 채 방패 비킴) 에 쓸 움직임 칸 번호")
    ap.add_argument("--thrust-at", default="5,6", help="움직임 칸 속에서 원본 그림 왼쪽 위 자리 x,y")
    ap.add_argument("--baby", action="store_true", help="아기 네발 10칸 (대기 2 · 걷기 4 · 일 4)")
    ap.add_argument("--wyvern", action="store_true", help="나는 와이번 8칸 (--width 날개 폭, --cell 칸)")
    ap.add_argument("--width", type=int, help="이 폭으로 줄인다 (날개 편 그림일 때)")
    ap.add_argument("--flip", action="store_true")
    ap.add_argument("--preview")
    a = ap.parse_args()
    img = Image.open(a.src).convert("RGBA")
    if a.flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    if a.width:
        bb = img.crop(img.getbbox())
        img = shrink(bb, round(bb.height * a.width / bb.width))
    if a.height:
        img = shrink(img, a.height)
    if a.wyvern:
        frames = build_wyvern(img, a.cell)
    elif a.cell and not a.thrust:
        img = place(img, a.cell)
    cx, cy, r = (float(v) for v in a.shield.split(",")) if a.shield else (0, 0, 0)
    if not a.wyvern:
        frames = build_baby(img) if a.baby else build(img, int(cx), int(cy), r)
    if a.thrust:
        frames = with_thrust(img, frames, a.thrust, a.cell, a.thrust_frames, a.thrust_at)
    c = frames[0].size[1]
    sheet = Image.new("RGBA", (c * len(frames), c), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * c, 0))
    dst = ROOT / "assets" / "creatures" / (a.out + ".png")
    sheet.save(dst)
    print("saved", dst.relative_to(ROOT), sheet.size)
    if a.preview:
        k = 6
        big = Image.new("RGBA", (sheet.width * k, sheet.height * k), (52, 48, 40, 255))
        big.alpha_composite(sheet.resize((sheet.width * k, sheet.height * k), Image.NEAREST))
        big.save(a.preview)


if __name__ == "__main__":
    main()
