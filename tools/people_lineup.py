"""사람 시트를 한 줄로 세운 확대 그림 (마을 사람 다시 그리기 때 키 · 등신 비교용).

실행: python3 tools/people_lineup.py 나갈그림.png [--scale 4] [--row 0]
      --row 0 앞 · 1 뒤 · 2 옆. 각 시트의 대기 첫 칸 (열 0) 을 바닥선을 맞춰 나란히 놓고 이름표를 단다.
"""
import argparse
import os

from PIL import Image, ImageDraw

from make_character_sheet import CELL

ROOT = os.path.join(os.path.dirname(__file__), "..")
PEOPLE = [
    ("protagonist", "주인공 A"), ("protagonist_b", "주인공 B"), ("player", "농부"), ("hunter", "사냥꾼"),
    ("smith", "대장장이"), ("alchemist", "연금술사"), ("rancher", "목축인"), ("ferryman", "뱃사공"), ("chief", "이장"),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--scale", type=int, default=4)
    ap.add_argument("--row", type=int, default=0)
    a = ap.parse_args()
    pad = 16
    img = Image.new("RGBA", (len(PEOPLE) * CELL, CELL + pad), (236, 226, 204, 255))
    d = ImageDraw.Draw(img)
    for i, (name, _) in enumerate(PEOPLE):
        sheet = Image.open(os.path.join(ROOT, "assets", "characters", f"{name}.png")).convert("RGBA")
        cell = sheet.crop((0, a.row * CELL, CELL, (a.row + 1) * CELL))
        img.alpha_composite(cell, (i * CELL, 0))
        box = cell.getbbox()
        d.text((i * CELL + 2, CELL + 2), f"{box[3] - box[1] if box else 0}px", fill=(90, 70, 60, 255))
    d.line([(0, CELL - 1), (img.width, CELL - 1)], fill=(200, 180, 150, 255))
    img = img.resize((img.width * a.scale, img.height * a.scale), Image.Resampling.NEAREST)
    img.save(a.out)
    print(a.out, " · ".join(n for _, n in PEOPLE))


if __name__ == "__main__":
    main()
