"""축사(닭장) 임시 그림 생성기 (2026-09-30 사용자 선택 A 닭장).

코드로 그린 임시 그림이다.
  ../assets/props/barn_ruin.png (96 x 64): 무너진 축사 터 (4칸 x 2칸 자리)
  ../assets/props/barn.png (96 x 64): 고친 축사 (왼쪽 함석지붕 닭장 · 오른쪽 울타리 우리)
  ../assets/props/hen.png (16 x 16) · chick.png (10 x 10): 닭장 앞에 게임이 수만큼 세움
  ../assets/props/hen_egg.png (16 x 16): 달걀 아이콘
소 · 흑염소 · 도시락 그림 후보는 프로젝트 파일 design/act3/barn/ 에만 남김.

실행: python3 tools/make_barn_sheets.py  (Pillow 필요)
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from make_character_sheet import outline

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "props")
def R(d,x0,y0,x1,y1,c): d.rectangle([x0,y0,x1-1,y1-1],fill=c)
TIN=(176,70,60); TIN_D=(130,50,46); TIN_L=(210,110,90)
WOOD=(160,112,74); WOOD_D=(116,80,54); WOOD_L=(190,146,104)
STRAW=(226,196,116); STRAW_D=(190,156,84); INK=(40,30,34); WHITE=(246,242,232)
def barn(ruin):
    img=Image.new('RGBA',(96,64),(0,0,0,0)); d=ImageDraw.Draw(img)
    R(d,2,60,94,64,(0,0,0,50))
    if not ruin:
        R(d,8,26,64,60,WOOD)
        for x in range(8,64,6): R(d,x,26,x+1,60,WOOD_D)
        R(d,26,36,46,60,WOOD_D); R(d,27,37,36,59,WOOD_L); R(d,37,37,45,59,WOOD_L)
        d.line([(27,37),(35,58)],fill=WOOD_D); d.line([(37,37),(45,58)],fill=WOOD_D)
        d.polygon([(2,28),(70,28),(58,8),(14,8)],fill=TIN)
        for x in range(4,70,5): R(d,x,10,x+2,28,TIN_D)
        R(d,2,26,70,29,TIN_D); R(d,14,7,58,10,TIN_L)
        R(d,28,14,44,22,(250,240,210)); R(d,31,16,41,21,(170,110,60)); R(d,32,14,33,16,INK); R(d,39,14,40,16,INK)
        R(d,10,40,22,52,STRAW); R(d,10,40,22,42,STRAW_D)
        # 울타리 우리
        for x in range(66,94,6): R(d,x,40,x+2,60,WOOD_L)
        R(d,64,44,94,46,WOOD_D); R(d,64,52,94,54,WOOD_D)
        R(d,72,55,86,59,(120,150,190))  # 물통
    else:
        R(d,8,40,64,60,(120,96,70))
        d.polygon([(0,44),(30,24),(52,30),(72,46)],fill=TIN_D)
        for x in range(6,66,7): R(d,x,38,x+3,44,TIN)
        for (x,y) in ((10,56),(24,58),(46,57),(58,55),(70,58),(82,56)): R(d,x,y,x+6,y+3,WOOD_D)
        for x in range(4,92,6): R(d,x,57,x+1,62,(96,150,84))
        for x in (68,80): R(d,x,46,x+2,60,WOOD_D)
        d.line([(66,48),(90,56)],fill=WOOD_D,width=2)
        R(d,74,40,88,47,(210,190,150)); R(d,77,42,85,45,(140,110,80))
    outline(img,96); return img
def hen():
    img=Image.new('RGBA',(16,16),(0,0,0,0)); d=ImageDraw.Draw(img)
    d.ellipse([3,6,13,14],fill=WHITE); d.ellipse([8,3,13,9],fill=WHITE)
    R(d,10,1,13,4,(210,50,50)); R(d,13,5,15,7,(230,170,60)); R(d,10,5,11,6,INK)
    R(d,2,6,5,10,(230,226,214)); R(d,6,14,7,16,(230,170,60)); R(d,10,14,11,16,(230,170,60))
    outline(img,16); return img
def chick():
    img=Image.new('RGBA',(10,10),(0,0,0,0)); d=ImageDraw.Draw(img)
    d.ellipse([1,3,8,9],fill=(250,220,90)); d.ellipse([4,1,8,5],fill=(250,220,90)); d.point((6,3),fill=INK); R(d,8,3,10,4,(230,150,50))
    outline(img,10); return img
def icon(k):
    img=Image.new('RGBA',(16,16),(0,0,0,0)); d=ImageDraw.Draw(img)
    if k=='egg': d.ellipse([4,2,12,14],fill=(246,236,214)); d.ellipse([6,4,8,7],fill=(255,255,255))
    elif k=='milk': R(d,5,4,11,15,(245,245,250)); R(d,6,1,10,4,(90,140,200)); R(d,5,8,11,11,(90,140,200))
    elif k=='dung': d.ellipse([3,7,13,14],fill=(110,80,50)); d.ellipse([5,4,11,10],fill=(130,96,60)); R(d,9,2,11,5,(120,180,90))
    elif k=='lunch': R(d,2,5,14,13,(200,60,60)); R(d,3,6,13,12,(250,246,236)); R(d,4,7,8,11,(250,210,90)); R(d,9,7,12,9,(120,170,90))
    elif k=='goatjuice': R(d,4,6,12,15,(90,60,50)); R(d,6,2,10,6,(160,160,170)); R(d,5,9,11,12,(230,200,90))
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    barn(True).save(os.path.join(OUT, "barn_ruin.png"))
    barn(False).save(os.path.join(OUT, "barn.png"))
    hen().save(os.path.join(OUT, "hen.png"))
    chick().save(os.path.join(OUT, "chick.png"))
    icon("egg").save(os.path.join(OUT, "hen_egg.png"))
    print("barn_ruin barn hen chick hen_egg")
