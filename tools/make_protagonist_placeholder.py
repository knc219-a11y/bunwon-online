"""주인공 임시 그림 (2026-10-03 주인공 하나).

사용자 AI 그림 (/mnt/project-files/design/protagonist/prompt.md) 이 올 때까지 사냥꾼 몸을 빌려 쓰되,
마을 사람 사냥꾼 NPC 와 헷갈리지 않게 옷 색만 바꾼다: 빨간 체크 셔츠 → 청록 셔츠, 멜빵 청바지 → 황토 바지.
부위 지도 (tools/char_parts/hunter.png) 를 그대로 복사해 make_wear_sheets.py 가 장비를 이 몸에 맞춘다.

그림이 오면 이 스크립트 대신:
  python3 tools/import_ai_character.py 그림.png --name protagonist [옵션] 후 python3 tools/make_wear_sheets.py

실행: python3 tools/make_protagonist_placeholder.py
"""
import colorsys
import os
import shutil

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "assets", "characters", "hunter.png")
OUT = os.path.join(ROOT, "assets", "characters", "protagonist.png")
PARTS = os.path.join(os.path.dirname(__file__), "char_parts")

# 부위 지도 색 (import_ai_character.py PART_COLORS)
TOP, PANTS = (160, 160, 160), (70, 100, 200)
# 부위 → (새 색상 0~1, 채도 배율)
SHIFT = {TOP: (0.47, 0.85), PANTS: (0.11, 0.7)}


def main():
    img = Image.open(SRC).convert("RGBA")
    parts = Image.open(os.path.join(PARTS, "hunter.png")).convert("RGBA")
    px, pp = img.load(), parts.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            shift = SHIFT.get(pp[x, y][:3]) if a and pp[x, y][3] else None
            if not shift:
                continue
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            # 체크 무늬의 흰 줄 · 그림자 단계는 밝기로 남는다 (색상만 바꿈)
            nr, ng, nb = colorsys.hls_to_rgb(shift[0], l, min(1.0, s * shift[1]))
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    img.save(OUT)
    shutil.copy(os.path.join(PARTS, "hunter.png"), os.path.join(PARTS, "protagonist.png"))
    print(OUT)


if __name__ == "__main__":
    main()
