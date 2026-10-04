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

도마리 세트 (2026-09-30): 프롬프트는 /mnt/project-files/design/doma-ai/prompt.md.
  stump        → assets/creatures/wild_old_stump.png (256x32): 0-1 깨어 있음, 2-5 뿌리 다리로 걷기, 6 그루터기인 척, 7 숨은 채 눈 번쩍
  cheonha      → assets/creatures/wild_cheonha.png (256x32): 0-1 노려봄, 2-5 깡충, 6-7 성남 (흔들림 + 불꽃). 게임에서 1.8배
  jiha         → assets/creatures/wild_jiha.png (256x32): 천하대장군과 같음
  tree_spirit  → assets/creatures/baby_tree_spirit_earth.png (320x32): 0-1 대기, 2-5 깡충, 6-9 일 (새싹 흔들기 + 물방울)
  그루터기 숨기 칸: --hide 잠든 그루터기 그림이 있으면 그걸 쓰고 7칸에 --hide-eyes 자리에 붉은 눈을 찍는다.
  없으면 make_doma_sheets 의 코드 그루터기 (납작한 나이테 윗면)를 쓴다.

번천 세트 (2026-10-01): 프롬프트는 /mnt/project-files/design/bunjeon-ai/prompt.md.
  will_o       → assets/creatures/wild_will_o.png (256x32): 0-1 대기 (일렁임), 2-5 떠다님, 6 부풂 (불똥 예고), 7 쪼그라듦 (칠 틈, 어두워짐)
  will_o_baby  → assets/creatures/baby_will_o_fire.png (320x32): 0-1 대기, 2-5 이동, 6-9 일 (불똥 튀김)
  bus          → assets/creatures/ghost_bus.png (96x48 한 장): 옆모습, 앞이 오른쪽 (왼쪽을 보고 나왔으면 --flip).
                 바퀴 밑 = y 46, 반쯤 비치게 --alpha (기본 225). 전조등 빛 · 문 · 승객 도깨비불은 게임이 그린다.
  도깨비불 일렁임: 위쪽 40% 줄을 1px 씩 옆으로 밀어 (sway) 불꽃 꼬리가 흔들려 보이게.

밀목 세트 (2026-10-04, 새 크기 "섞어서"): 프롬프트는 /mnt/project-files/design/new-art-ai/milmok.md.
  사람 (주인공 · 마을 사람) 키 46px 에 맞춘 첫 몬스터 묶음. 모두 옆모습, 앞이 오른쪽 (왼쪽을 보고 나왔으면 --flip).
  wolf             → assets/creatures/wild_shadow_wolf.png (384x48, 48칸): 몸 길이 약 40px · 키 약 24px (사람 허리께)
  tiger            → assets/creatures/wild_white_tiger.png (768x96, 96칸): 몸 길이 약 84px · 키 약 46px (사람 키만 함). 게임은 늘리지 않고 1:1
  baby_tiger       → assets/creatures/baby_tiger.png (320x32): 몸 길이 약 26px
  baby_white_tiger → assets/creatures/baby_white_tiger.png (같음)
  백호 둘은 몸이 희어서 흰 바탕을 지우면 몸까지 지워진다: 초록 바탕으로 뽑고 --backdrop.
  늑대 · 백호 칸: 0-1 대기, 2-5 달리기 (stride: 앞뒤 다리를 반대로 밀기), 6 웅크림 예고, 7 지침. 아기: 0-1 대기, 2-5 걷기, 6-9 고개 들어 어흥.

실행: python3 tools/import_ai_monster.py 그림.png --kind crab|boss|baby|wolf|tiger|baby_tiger|baby_white_tiger|sparrow|scarecrow|baby_sparrow|stump|cheonha|jiha|tree_spirit|will_o|will_o_baby|bus [--width 24] [--colors 20] [--preview 미리보기.png]
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
도마리 (그림 원본: /mnt/project-files/design/doma-ai/ai_*.png, 사용자 AI 그림 2026-10-01, 보기 A 붉은 눈 나무 요괴)
  ai_stump.png --kind stump --width 31 --hide ai_stump_sleep.png --hide-eyes 0.42,0.5,0.6,0.5 --colors 28 --eyes 0.398,0.469,0.602,0.469 --eye-color 255,56,40 --angry
  ai_cheonha.png --kind cheonha --colors 28 --eyes 0.325,0.379,0.662,0.379 --eye-size 1 --eye-ring --eye-color 220,30,30
  ai_jiha.png --kind jiha --colors 28 --eyes 0.273,0.329,0.71,0.329 --eye-size 1 --eye-ring --eye-color 220,30,30
  ai_baby.png --kind tree_spirit --colors 24 --eyes 0.2,0.63,0.6,0.645 --cheeks 0.14,0.73,0.66,0.76
번천 (그림 원본: /mnt/project-files/design/bunjeon-ai/ai_*.png, 사용자 AI 그림 2026-10-01, 보기 B 저승길 막차)
  ai_will_o.png --kind will_o --colors 28 --skull 0.49,0.72   (불꽃 속 해골은 뭉개져서 7x7 해골을 다시 찍음)
  ai_bus.png --kind bus --flip --colors 32                    (AI 그림이 앞-왼쪽이라 뒤집음)
  ai_baby.png --kind will_o_baby --colors 24 --eyes 0.33,0.58,0.67,0.58 --cheeks 0.25,0.68,0.75,0.68
밀목 (그림 원본: /mnt/project-files/design/milmok-tall/ai/ai_*.png, 사용자 AI 그림 2026-10-04, 새 크기)
  ai_white_tiger.png --kind tiger --backdrop --smooth --colors 32 --eyes 0.938,0.398 --eye-color 150,235,255
  ai_shadow_wolf.png --kind wolf --width 42 --colors 24 --eyes 0.916,0.369 --eye-size 1 --eye-color 120,240,255
  ai_baby_tiger.png --kind baby_tiger --colors 24 --smooth --width 28
    (초록 바탕. 줄무늬가 칸마다 고르면 점으로 깨져서 --smooth, 빛나는 눈은 줄이면 사라져서 다시 찍음)
"""
import argparse
import os

import make_slime_sheet

from PIL import Image

from import_ai_character import pixelize, white_to_alpha
from import_ai_slime import draw_face, find_face, inpaint, largest_blob, peel_halo, soften_edges
from make_character_sheet import grade_p1, outline
from make_doma_sheets import FIRE, stump as code_stump
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
    # 도마리 세트 (2026-09-30). 모두 정면. hide: 그루터기인 척 (0 잠듦 · 1 눈 번쩍), fury: 성난 불꽃, water: 물방울 단계
    "stump": dict(out="wild_old_stump", width=26, max_h=26, frames=[
        dict(sx=1.0, sy=1.0, lift=0), dict(sx=1.02, sy=0.97, lift=0),
        dict(sx=1.0, sy=1.0, lift=1, step=1, dx=-1), dict(sx=1.0, sy=0.97, lift=0, step=-1, dx=0),
        dict(sx=1.0, sy=1.0, lift=1, step=1, dx=1), dict(sx=1.0, sy=0.97, lift=0, step=-1, dx=0),
        dict(hide=0), dict(hide=1),
    ]),
    "cheonha": dict(out="wild_cheonha", width=17, max_h=31, frames=[
        dict(sx=1.0, sy=1.0, lift=0), dict(sx=1.03, sy=0.98, lift=0),
        dict(sx=1.06, sy=0.92, lift=0, dx=-1), dict(sx=0.95, sy=1.0, lift=2),
        dict(sx=0.97, sy=0.98, lift=1, dx=1), dict(sx=1.06, sy=0.93, lift=0),
        dict(sx=1.0, sy=1.0, lift=0, dx=-1, fury=1), dict(sx=1.04, sy=0.98, lift=1, dx=1, fury=2),
    ]),
    "tree_spirit": dict(out="baby_tree_spirit_earth", width=15, frames=[
        dict(sx=1.0, sy=1.0, lift=0), dict(sx=1.04, sy=0.96, lift=0),
        dict(sx=1.08, sy=0.9, lift=0), dict(sx=0.93, sy=1.06, lift=3),
        dict(sx=0.96, sy=1.03, lift=4), dict(sx=1.08, sy=0.9, lift=0),
        dict(sx=1.0, sy=1.0, lift=0, rot=-6, water=1), dict(sx=1.0, sy=1.0, lift=0, rot=6, water=2),
        dict(sx=1.0, sy=1.0, lift=0, rot=-6, water=1), dict(sx=1.03, sy=0.97, lift=0),
    ]),
}
KINDS["jiha"] = dict(KINDS["cheonha"], out="wild_jiha")
# 번천 세트 (2026-10-01). 정면. sway: 불꽃 윗부분 흔들기 (-1/1), burst: 부풂 불똥, dim: 쪼그라들어 어두움, ember: 아기 일 칸 불똥 단계
KINDS["will_o"] = dict(out="wild_will_o", width=22, max_h=27, parts=0.01, frames=[
    dict(sx=1.0, sy=1.0, lift=2), dict(sx=1.03, sy=0.97, lift=2, sway=1),
    dict(sx=1.0, sy=1.0, lift=3, sway=-1), dict(sx=0.97, sy=1.03, lift=4, sway=1),
    dict(sx=1.0, sy=1.0, lift=3, sway=-1), dict(sx=1.03, sy=0.97, lift=2),
    dict(sx=1.3, sy=1.18, lift=1, sway=1, burst=1), dict(sx=0.78, sy=0.75, lift=1, dim=1),
])
KINDS["will_o_baby"] = dict(out="baby_will_o_fire", width=15, max_h=19, parts=0.01, frames=[
    dict(sx=1.0, sy=1.0, lift=0), dict(sx=1.03, sy=0.97, lift=0, sway=1),
    dict(sx=1.06, sy=0.92, lift=0, sway=-1), dict(sx=0.95, sy=1.06, lift=3, sway=1),
    dict(sx=0.97, sy=1.03, lift=2, sway=-1), dict(sx=1.06, sy=0.92, lift=0),
    dict(sx=1.0, sy=1.0, lift=0, sway=1, ember=1), dict(sx=1.05, sy=1.04, lift=1, sway=-1, ember=2),
    dict(sx=1.0, sy=1.0, lift=0, sway=1, ember=1), dict(sx=1.0, sy=1.0, lift=0),
])
# 밀목 세트 (2026-10-04, 새 크기 "섞어서": 사람 키 46px 에 맞춤). 모두 옆모습, 앞이 오른쪽 (왼쪽을 보고 나왔으면 --flip).
#   cell: 칸 크기 (게임은 32칸이 아닌 시트를 늘리지 않고 1:1 로 그린다. 대장은 노드 배율 1.8 을 되돌려 1:1)
#   stride: 네발 달리기. 아래 다리 줄의 뒷다리 (왼쪽 반) 와 앞다리 (오른쪽 반) 를 반대로 민다 (-1/1 = 다리 벌림 · 모음)
#   rot: 발밑 가운데 축 기울임 (- 는 머리가 아래로 = 웅크림 · 지침, + 는 머리가 위로 = 포효)
#   늑대 · 백호: 0-1 대기, 2-5 달리기, 6 웅크림 (달려들기 · 도약 예고), 7 공격 뒤 지침 (때릴 틈)
#   아기: 0-1 대기, 2-5 걷기, 6-9 일 (고개 들어 어흥)
QUAD = [
    dict(sx=1.0, sy=1.0, lift=0), dict(sx=1.01, sy=0.97, lift=0),
    dict(sx=1.04, sy=0.95, lift=0, stride=1), dict(sx=1.0, sy=1.0, lift=1, stride=-1),
    dict(sx=1.04, sy=0.95, lift=0, stride=1), dict(sx=1.0, sy=1.0, lift=1, stride=-1),
    dict(sx=1.06, sy=0.84, lift=0, rot=-5, dx=-1), dict(sx=1.02, sy=0.9, lift=0, rot=-4),
]
KINDS["wolf"] = dict(out="wild_shadow_wolf", cell=48, width=40, max_h=30, work_w=320, frames=QUAD)
KINDS["tiger"] = dict(out="wild_white_tiger", cell=96, width=84, max_h=62, work_w=480, frames=QUAD)
KINDS["baby_tiger"] = dict(out="baby_tiger", cell=32, width=26, max_h=22, frames=[
    dict(sx=1.0, sy=1.0, lift=0), dict(sx=1.02, sy=0.96, lift=0),
    dict(sx=1.0, sy=1.0, lift=1, stride=1), dict(sx=1.02, sy=0.96, lift=0, stride=-1),
    dict(sx=1.0, sy=1.0, lift=1, stride=1), dict(sx=1.02, sy=0.96, lift=0, stride=-1),
    dict(sx=1.0, sy=1.0, lift=0, rot=5), dict(sx=0.98, sy=1.04, lift=0, rot=9),
    dict(sx=1.0, sy=1.0, lift=0, rot=5), dict(sx=1.02, sy=0.97, lift=0),
])
KINDS["baby_white_tiger"] = dict(KINDS["baby_tiger"], out="baby_white_tiger")
BUS_W, BUS_H, BUS_FLOOR = 96, 48, 46
DROP = (150, 200, 240)
BLUE_L, FIRE_C, FIRE_L = (210, 236, 255), (250, 150, 60), (255, 230, 130)


def sway(img, d):
    """위 40% 줄을 d px 옆으로 민다 (가운데 줄은 반만): 불꽃 꼬리가 일렁여 보이게."""
    w, h = img.size
    out = img.copy()
    cut = round(h * 0.4)
    out.paste((0, 0, 0, 0), (0, 0, w, cut))
    for y in range(cut):
        k = d if y < cut // 2 else (d if y % 2 else 0)
        row = img.crop((0, y, w, y + 1))
        out.alpha_composite(row, (max(0, k), y)) if k >= 0 else out.alpha_composite(row.crop((-k, 0, w, 1)), (0, y))
    return out


def dim(img):
    """쪼그라든 도깨비불: 밝기를 낮추고 푸르게 (칠 틈)."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r * 0.5), int(g * 0.55), int(b * 0.75 + 20), a)
    return img


def burst_sparks(l, left, top, W, H):
    """부풂 칸: 몸 둘레에 튀는 푸른 불똥 (코드 그림과 같은 자리 감각)."""
    cx, cy = left + W / 2, top + H * 0.6
    for dx, dy in ((-W / 2 - 3, -2), (W / 2 + 2, -3), (-W / 2 - 1, 5), (W / 2 + 1, 6)):
        l.px(cx + dx, cy + dy, BLUE_L)


def embers(l, cx, base, stage):
    """아기 도깨비불 일 칸: 양옆으로 올라가는 불똥."""
    for i in range(stage + 1):
        l.px(cx + 7 + i, base - 10 - i * 3, FIRE_L)
        l.px(cx - 7 - i, base - 8 - i * 3, FIRE_C)


SKULL = (".SSSSS.", "SSSSSSS", "SDDSDDS", "SDRSRDS", "SSSDSSS", ".SSSSS.", ".S.S.S.")


def draw_skull(l, cx, cy, dim_=False):
    """도깨비불 속 작은 해골 (7x7). 22px 로 줄이면 AI 해골이 뭉개져서 새로 찍는다. D 눈구멍 · R 붉은 눈."""
    col = {"S": (150, 170, 190) if dim_ else (232, 246, 240), "D": (34, 30, 48), "R": (255, 60, 50)}
    # 밝은 불꽃 속에서도 보이게 해골 둘레에 푸른 테두리
    cell = lambda x, y: 0 <= y < 7 and 0 <= x < 7 and SKULL[y][x] != "."
    for y in range(-1, 8):
        for x in range(-1, 8):
            if not cell(x, y) and any(cell(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                l.px(cx - 3 + x, cy - 3 + y, (54, 84, 120))
    for y, row in enumerate(SKULL):
        for x, c in enumerate(row):
            if c != ".":
                l.px(cx - 3 + x, cy - 3 + y, col[c])


def build_bus(src, width=86, colors=32, alpha=225, flip=False):
    """유령 막차 옆모습 한 장 → 96x48. 바퀴 밑을 BUS_FLOOR 에 맞추고 가운데 정렬, 반쯤 비치게."""
    fig = load_figure(src, flip)
    # 깨진 앞유리 사이로 보이던 흰 바탕 (안쪽에 갇힌 흰색) 은 캄캄한 창 안으로 칠한다. 전조등은 노란 기가 있어 남는다
    px = fig.load()
    for y in range(fig.height):
        for x in range(fig.width):
            r, g, b, al = px[x, y]
            if al and min(r, g, b) > 215 and max(r, g, b) - min(r, g, b) < 18:
                px[x, y] = (30, 30, 42, 255)
    pal_img = fig.convert("RGB").quantize(colors, method=Image.Quantize.FASTOCTREE)
    h = round(width * fig.height / fig.width)
    if h > BUS_FLOOR - 1:
        width, h = round(width * (BUS_FLOOR - 1) / h), BUS_FLOOR - 1
    # 잔무늬 (부적 · 녹)가 많아 칸마다 고르는 pixelize 는 얼룩덜룩해진다: 부드럽게 줄인 뒤 팔레트로
    small = fig.resize((width, h), Image.LANCZOS)
    body = small.convert("RGB").quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGBA")
    body.putalpha(small.getchannel("A").point(lambda v: 255 if v > 128 else 0))
    if not soften_edges(body):
        outline(body, max(width, h))
    grade_p1(body)
    a = body.getchannel("A").point(lambda v: alpha if v else 0)
    body.putalpha(a)
    sheet = Image.new("RGBA", (BUS_W, BUS_H), (0, 0, 0, 0))
    sheet.alpha_composite(body, (BUS_W // 2 - width // 2, BUS_FLOOR - h))
    return sheet


def fury_sparks(l, left, top, W, stage):
    """장승이 성날 때 머리 둘레에 튀는 불꽃 (코드 그림과 같은 자리 감각)."""
    for i, (fx, dy) in enumerate(((-0.25, 1), (1.2, 2), (-0.35, 7), (1.3, 8))):
        if i < 2 or stage == 2:
            x, y = int(round(left + fx * W)), top + dy - (stage == 2)
            l.px(x, y, FIRE)
            l.px(x, y - 1, (255, 244, 190))


def water_drops(l, cx, top, stage):
    """아기 나무 정령 일 칸: 새싹을 흔들면 양옆으로 물방울."""
    for i in range(stage + 1):
        l.px(cx + 7 + i, top + 2 + i * 3, DROP)
        l.px(cx - 8 - i, top + 3 + i * 3, DROP)


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


def big_blobs(im, frac):
    """largest_blob 과 같지만, 가장 큰 덩어리의 frac 배 이상인 떨어진 덩어리도 남긴다 (도깨비불 떨어진 불꽃 혀)."""
    a = im.getchannel("A").load()
    w, h = im.size
    seen, blobs = set(), []
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
                blobs.append(blob)
    top = max(len(b) for b in blobs)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    po, pi = out.load(), im.load()
    for b in blobs:
        if len(b) >= top * frac:
            for x, y in b:
                po[x, y] = pi[x, y][:3] + (255,)
    return out.crop(out.getbbox())


def clear_backdrop(im, tol=48):
    """흰 몸 (산군 백호 · 아기 백호) 은 흰 바탕에서 몸까지 지워져서 초록 바탕으로 뽑는다 (--backdrop).
    네 귀퉁이 색과 비슷한 색을 가장자리에서부터 이어진 만큼 투명으로. 바탕이 흰색이면 흰 바탕 지우기와 같다."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bg = tuple(sorted(c[i] for c in corners)[1] for i in range(3))
    near = lambda c: sum(abs(c[i] - bg[i]) for i in range(3)) <= tol
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for x in (0, w - 1) for y in range(h)]
    seen = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        if not near(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    # 초록 바탕이 털 가장자리에 번진 픽셀 (초록 기가 센 반투명 테두리)은 지운다
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and g > r + 40 and g > b + 40 and bg[1] > bg[0] + 60:
                px[x, y] = (0, 0, 0, 0)
    return im


BACKDROP = False
SMOOTH = 0


def smooth_pixelize(fig, pal_img, w, h):
    """잔무늬 (백호 줄무늬)가 많은 큰 그림은 칸마다 고르는 pixelize 가 얼룩덜룩한 점이 된다 (--smooth).
    부드럽게 줄인 뒤 그 작은 그림에서 고른 색으로 맞춰 무늬가 색 덩어리로 남게. 큰 그림에서 고른 팔레트는
    까만 줄 · 테두리 색이 많아서 작은 아기가 거무튀튀해진다 (아기 호랑이)."""
    small = fig.resize((w, h), Image.LANCZOS)
    pal_img = small.convert("RGB").quantize(SMOOTH, method=Image.Quantize.FASTOCTREE)
    body = small.convert("RGB").quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGBA")
    body.putalpha(small.getchannel("A").point(lambda v: 255 if v > 128 else 0))
    return body


def load_figure(src, flip=False, mist=False, parts=0.0, work_w=None):
    im = clear_backdrop(Image.open(src)) if BACKDROP else white_to_alpha(Image.open(src))
    im = clear_mist(im) if mist else im
    # parts: 떨어진 조각을 남기려고 peel_halo (끝에 가장 큰 덩어리만 남김) 는 건너뛴다
    fig = big_blobs(im, parts) if parts else peel_halo(largest_blob(im))
    if flip:
        fig = fig.transpose(Image.FLIP_LEFT_RIGHT)
    work_w = work_w or WORK_W
    fig = fig.resize((work_w, round(work_w * fig.height / fig.width)), Image.LANCZOS)
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


def stride(img, d):
    """옆모습 네발 짐승: 아래 30% 줄 (다리) 의 뒷다리 (왼쪽 반) 는 -d, 앞다리 (오른쪽 반) 는 +d 만큼 민다.
    번갈아 쓰면 다리가 벌어졌다 모였다 해서 달려 보인다. 큰 칸은 2px 씩."""
    w, h = img.size
    top = h - max(2, round(h * 0.3))
    k = d * (2 if w >= 48 else 1)
    out = img.copy()
    out.paste((0, 0, 0, 0), (0, top, w, h))
    mid = w // 2
    for x0, x1, dx in ((0, mid, -k), (mid, w, k)):
        part = img.crop((x0, top, x1, h))
        out.alpha_composite(part, (max(0, min(w - part.width, x0 + dx)), top))
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
          fly_eyes=None, eye_color=EYE, peek=None, angry=False, hide_src=None, hide_eyes=None, skull=None):
    spec = KINDS[kind]
    width = width or spec["width"]
    fig = load_figure(src, flip, spec.get("mist", False), spec.get("parts", 0.0), spec.get("work_w"))
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
        if "sand" in f or "hide" in f:
            placed.append(None)
            continue
        use_fly = f.get("fly") and fly is not None
        src_fig, src_pal, bw, bh = (fly, fly_pal, spec["fw"], fly_h) if use_fly else (fig, pal_img, width, base_h)
        if f.get("fly") and fly is None:
            # 날개 편 그림이 없으면 앉은 그림을 위아래로만 흔든다
            f = dict(f, sx=1.0, sy=1.0 if f["sy"] >= 1.0 else 0.94)
        W = max(8, round(bw * f["sx"]))
        H = max(8, min(CELL - f["lift"], round(bh * f["sy"])))
        body = smooth_pixelize(src_fig, src_pal, W, H) if SMOOTH else pixelize(src_fig, src_pal, src_pal.getpalette(), W, H)
        had_line = soften_edges(body) and had_line
        if f.get("step"):
            body = shove_legs(body, f["step"])
        if f.get("stride"):
            body = stride(body, f["stride"])
        if f.get("sway"):
            body = sway(body, f["sway"])
        if f.get("dim"):
            body = dim(body)
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
        if "hide" in f:
            if hide_src:
                # 잠든 그루터기 그림: 깨어난 몸과 같은 가로로, 7칸은 --hide-eyes 자리에 붉은 눈이 번쩍
                hid = load_figure(hide_src)
                hp = hid.convert("RGB").quantize(colors, method=Image.Quantize.FASTOCTREE)
                hw = width
                hh = min(CELL, round(hw * hid.height / hid.width))
                img = pixelize(hid, hp, hp.getpalette(), hw, hh)
                if not soften_edges(img):
                    outline(img, max(hw, hh))
                grade_p1(img)
                hl, ht = CELL // 2 - hw // 2, CELL - hh
                sheet.alpha_composite(img, (i * CELL + hl, ht))
                if f["hide"] and hide_eyes:
                    spot_face(l, hl, ht, hw, hh, hide_eyes, eye_size, False, (), False, eye_color, True)
                    sheet.alpha_composite(l.img, (i * CELL, 0))
                continue
            code_stump(l, hide=2, axe=0, glow=bool(f["hide"]))
            mound = l.img
            outline(mound, CELL)
            grade_p1(mound)
            sheet.alpha_composite(mound, (i * CELL, 0))
            continue
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
        if f.get("fury"):
            fury_sparks(l, left, top, W, f["fury"])
        if f.get("water"):
            water_drops(l, left + W // 2, top, f["water"])
        if skull:
            draw_skull(l, int(round(left + skull[0] * W)), int(round(top + skull[1] * H)), f.get("dim"))
        if f.get("burst"):
            burst_sparks(l, left, top, W, H)
        if f.get("ember"):
            embers(l, left + W // 2, top + H, f["ember"])
        if "work" in f:
            draw_tongue(l, int(round(left + mouth[0] * W)), int(round(top + mouth[1] * H)), f["work"])
        sheet.alpha_composite(l.img, (i * CELL, 0))
    return sheet


# 대장 고해상 시트 (2026-10-01 사용자: "보스몬스터의 도트가 너무 깨져보이는 현상"): 게임이 32칸 시트를 1.8배로 키우면
# 원본 1px 이 화면 1px · 2px 로 들쭉날쭉 늘어 깨져 보인다. --hd 는 같은 AI 그림을 1.8배 크기 (58칸) 로 바로 픽셀화해서
# 게임이 늘리지 않고 1:1 로 그리게 한다 (<이름>_hd.png). 몸 가로 · 키 · 뜬 높이 · 옆 밀기 · 눈 크기를 같은 배율로.
# --mini 는 반대로 대장이 불러내는 새끼 (게임에서 0.65배) 용 21칸 시트 <이름>_mini.png.
HD = 1.8
HD_CELL = 58
MINI = 0.65
MINI_CELL = 21


def use_scale(kind, k, cell, suffix):
    global CELL
    CELL = cell
    make_slime_sheet.CELL = cell
    spec = dict(KINDS[kind])
    spec["width"] = round(spec["width"] * k)
    if spec.get("max_h"):
        spec["max_h"] = round(spec["max_h"] * k)
    spec["frames"] = [dict(f, lift=round(f.get("lift", 0) * k), dx=round(f.get("dx", 0) * k)) for f in spec["frames"]]
    spec["out"] = spec["out"] + suffix
    KINDS[kind] = spec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--kind", required=True, choices=sorted(KINDS) + ["bus"])
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
    ap.add_argument("--hide", help="잠든 그루터기 그림 (stump 숨기 칸)")
    ap.add_argument("--hide-eyes", help="잠든 그루터기 그림에서 눈이 번쩍일 자리 (몸 비율 x1,y1,x2,y2)")
    ap.add_argument("--skull", help="will_o: 작은 해골을 찍을 자리 (몸 비율 x,y)")
    ap.add_argument("--alpha", type=int, default=225, help="bus: 반쯤 비치는 정도 (0-255)")
    ap.add_argument("--out", help="기본: assets/creatures/<규격 이름>.png")
    ap.add_argument("--preview", help="4배 확대 미리보기 PNG")
    ap.add_argument("--hd", action="store_true", help="대장용 1.8배 (58칸) 시트 <이름>_hd.png. 게임은 늘리지 않고 그린다")
    ap.add_argument("--mini", action="store_true", help="새끼용 0.65배 (21칸) 시트 <이름>_mini.png. 게임은 줄이지 않고 그린다")
    ap.add_argument("--smooth", action="store_true", help="부드럽게 줄인 뒤 팔레트로 (잔무늬가 점으로 깨질 때)")
    ap.add_argument("--backdrop", action="store_true", help="흰 바탕 대신 귀퉁이 색 (초록 바탕 등) 을 지운다. 흰 몸 (백호) 용")
    a = ap.parse_args()
    global BACKDROP, SMOOTH
    BACKDROP = a.backdrop
    SMOOTH = a.colors if a.smooth else 0
    if KINDS.get(a.kind, {}).get("cell"):
        # 밀목부터는 종류마다 칸 크기가 다르다 (늑대 48 · 백호 96 · 아기 32)
        global CELL
        CELL = make_slime_sheet.CELL = KINDS[a.kind]["cell"]
    if a.hd:
        use_scale(a.kind, HD, HD_CELL, "_hd")
        a.width = round(a.width * HD) if a.width else None
        a.eye_size = max(a.eye_size + 1, round(a.eye_size * HD))
    elif a.mini:
        use_scale(a.kind, MINI, MINI_CELL, "_mini")
        a.width = round(a.width * MINI) if a.width else None
        a.eye_size = max(1, round(a.eye_size * MINI))
    mouth = tuple(float(v) for v in a.mouth.split(","))
    pairs = lambda t: [tuple(v) for v in zip(*[iter(float(x) for x in t.split(","))] * 2)] if t else []
    if a.kind == "bus":
        sheet = build_bus(a.src, a.width or 86, a.colors if a.colors != 20 else 32, a.alpha, a.flip)
        out = a.out or os.path.join(ROOT, "assets", "creatures", "ghost_bus.png")
        sheet.save(out)
        print(out)
        if a.preview:
            bg = Image.new("RGBA", sheet.size, (40, 46, 60, 255))
            bg.alpha_composite(sheet)
            bg.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(a.preview)
        return
    sheet = build(a.src, a.kind, a.width, a.colors, a.redraw_eyes, a.sand, mouth,
                  pairs(a.eyes), a.eye_size, a.eye_ring, pairs(a.cheeks), a.eye_lid, a.fly, a.flip, pairs(a.fly_eyes),
                  tuple(int(v) for v in a.eye_color.split(",")) if a.eye_color else EYE, a.peek, a.angry, a.hide, pairs(a.hide_eyes),
                  (pairs(a.skull) or [None])[0])
    out = a.out or os.path.join(ROOT, "assets", "creatures", KINDS[a.kind]["out"] + ".png")
    sheet.save(out)
    print(out)
    if a.preview:
        bg = Image.new("RGBA", sheet.size, (236, 222, 190, 255))
        bg.alpha_composite(sheet)
        bg.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(a.preview)


if __name__ == "__main__":
    main()
