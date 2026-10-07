"""Build the reviewed pixel-art design drawings and their transparent source sprites.

Run from any directory: python3 docs/art/design/build_designs.py
Only Pillow is required. Sheets are review drawings; source PNGs are visual assets,
not wired into the Godot project yet.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

ROOT = Path(__file__).parent
SPRITES = ROOT / 'sprites'
SPRITES.mkdir(exist_ok=True)
P = {
    'ink':'#263F52','paper':'#FFF8E8','floor':'#F4EBCF','soft':'#E5DABB',
    'mint':'#59CFA7','mint_hi':'#9AE9CB','mint_lo':'#339D83',
    'scarf':'#FFCA70','enemy':'#EF746B','enemy_hi':'#FFAEA0',
    'enemy_lo':'#A64F65','danger':'#EF5C72','gold':'#F8D76D',
    'supply':'#F0BB58','intel':'#7DAFE8','wall':'#8BC8C1',
    'wall_lo':'#5D9F9D','steel':'#7895A2','steel_hi':'#B9D1D5',
}
FONT = '/System/Library/Fonts/Hiragino Sans GB.ttc'


def font(size):
    return ImageFont.truetype(FONT, size)


def canvas(w,h,color=(0,0,0,0)):
    return Image.new('RGBA',(w,h),color)


def save_asset(name, im):
    path=SPRITES / f'{name}.png'
    path.parent.mkdir(parents=True,exist_ok=True)
    im.save(path)
    return im


def box(d,xy,fill,outline=None,width=1):
    d.rectangle(xy,fill=fill,outline=outline,width=width)


def player(facing):
    im=canvas(32,32); d=ImageDraw.Draw(im)
    box(d,(10,27,14,30),P['ink']); box(d,(19,27,23,30),P['ink'])
    box(d,(7,17,25,28),P['ink']); box(d,(9,18,23,26),P['mint_lo'])
    box(d,(10,18,22,23),P['mint'])
    box(d,(6,5,26,17),P['ink']); box(d,(8,6,24,15),P['mint'])
    box(d,(10,4,22,7),P['mint_hi'])
    box(d,(12,16,21,19),P['scarf']); box(d,(8,18,11,21),P['scarf'])
    if facing in ('S','SE','SW'):
        d.line([(11,11),(16,15),(21,11)],fill=P['paper'],width=2)
        box(d,(11,12,13,13),P['ink']); box(d,(19,12,21,13),P['ink'])
    elif facing in ('N','NE','NW'):
        box(d,(11,10,21,12),P['mint_lo'])
        box(d,(14,5,18,6),P['paper'])
    elif facing=='E':
        box(d,(21,10,24,13),P['paper']); box(d,(9,8,11,12),P['mint_lo'])
    else:
        box(d,(8,10,11,13),P['paper']); box(d,(21,8,23,12),P['mint_lo'])
    vec={'N':(0,-1),'NE':(.7,-.7),'E':(1,0),'SE':(.7,.7),'S':(0,1),
         'SW':(-.7,.7),'W':(-1,0),'NW':(-.7,-.7)}[facing]
    ax,ay=16,19; bx,by=round(ax+vec[0]*14),round(ay+vec[1]*14)
    d.line([(ax,ay),(bx,by)],fill=P['ink'],width=7)
    d.line([(ax,ay),(bx,by)],fill=P['steel_hi'],width=3)
    box(d,(bx-2,by-2,bx+2,by+2),P['ink'])
    box(d,(bx-1,by-1,bx+1,by+1),P['gold'])
    return save_asset(f'characters/player_{facing.lower()}',im)


def enemy(kind):
    w=36 if kind=='heavy' else 32
    im=canvas(w,32); d=ImageDraw.Draw(im)
    if kind=='infantry':
        box(d,(10,25,13,30),P['ink']); box(d,(19,25,22,30),P['ink'])
        box(d,(8,17,24,28),P['ink']); box(d,(10,18,22,26),P['enemy_lo'])
        box(d,(8,5,24,17),P['ink']); box(d,(10,7,22,15),P['enemy'])
        box(d,(7,4,25,8),P['enemy_lo']); box(d,(11,10,13,12),P['paper'])
        box(d,(23,20,31,24),P['ink']); box(d,(25,21,30,22),P['steel'])
    elif kind=='assault':
        d.polygon([(5,14),(22,3),(28,18)],fill=P['ink'])
        d.polygon([(9,13),(21,6),(25,15)],fill=P['enemy'])
        d.line([(14,10),(21,8)],fill=P['enemy_hi'],width=2)
        box(d,(12,16,28,28),P['ink']); box(d,(14,18,26,26),P['enemy'])
        box(d,(12,27,17,30),P['ink']); box(d,(24,27,29,30),P['ink'])
        d.polygon([(25,20),(32,22),(25,26)],fill=P['enemy_lo'])
    else:
        box(d,(10,27,15,31),P['ink']); box(d,(24,27,29,31),P['ink'])
        box(d,(2,16,34,29),P['ink'])
        box(d,(4,17,10,26),P['enemy']); box(d,(26,17,32,26),P['enemy'])
        box(d,(12,18,24,27),P['enemy_lo'])
        box(d,(6,4,30,18),P['ink']); box(d,(8,6,28,16),P['enemy_lo'])
        box(d,(12,9,24,13),P['enemy']); box(d,(14,10,22,11),P['enemy_hi'])
        box(d,(4,18,6,24),P['enemy_hi']); box(d,(30,18,32,24),P['enemy_hi'])
    return save_asset(f'characters/{kind}',im)


def boss(phase):
    im=canvas(64,64); d=ImageDraw.Draw(im)
    d.polygon([(8,13),(56,13),(63,27),(58,55),(6,55),(1,27)],fill=P['ink'])
    d.polygon([(11,16),(53,16),(59,28),(54,51),(10,51),(5,28)],fill=P['enemy_lo'])
    box(d,(3,9,14,15),P['ink']); box(d,(6,1,10,12),P['ink'])
    box(d,(50,9,61,15),P['ink']); box(d,(53,1,57,12),P['ink'])
    box(d,(8,23,19,45),P['enemy']); box(d,(45,23,56,45),P['enemy'])
    box(d,(11,20,17,22),P['enemy_hi']); box(d,(47,20,53,22),P['enemy_hi'])
    d.polygon([(32,17),(47,30),(41,47),(23,47),(17,30)],fill=P['ink'])
    core=P['danger'] if phase==2 else P['intel']
    d.polygon([(32,22),(42,31),(38,42),(26,42),(22,31)],fill=core)
    box(d,(28,30,36,33),P['paper']); box(d,(21,50,43,54),P['steel'])
    if phase==2:
        d.line([(32,10),(52,27),(44,50),(20,50),(12,27),(32,10)],fill=P['gold'],width=2)
        box(d,(1,27,5,32),P['gold']); box(d,(59,27,63,32),P['gold'])
    return save_asset(f'characters/boss_phase_{phase}',im)


def weapon(kind):
    im=canvas(64,32); d=ImageDraw.Draw(im)
    if kind=='pistol':
        box(d,(8,9,36,17),P['ink']); box(d,(11,11,33,15),P['steel_hi'])
        box(d,(12,17,19,29),P['ink']); box(d,(14,19,17,26),P['steel'])
        box(d,(36,11,44,15),P['ink'])
    elif kind=='smg':
        box(d,(4,8,48,16),P['ink']); box(d,(7,10,45,14),P['steel'])
        box(d,(19,16,27,30),P['ink']); box(d,(21,18,25,27),P['mint'])
        box(d,(5,16,11,23),P['ink']); box(d,(48,10,57,14),P['ink'])
    elif kind=='shotgun':
        box(d,(3,8,51,17),P['ink']); box(d,(7,10,48,12),P['steel_hi'])
        box(d,(7,14,46,15),P['steel'])
        box(d,(5,18,29,22),P['supply']); box(d,(17,22,22,29),P['ink'])
        box(d,(51,7,60,18),P['ink'])
    elif kind=='sniper':
        box(d,(2,12,58,17),P['ink']); box(d,(5,13,55,15),P['steel_hi'])
        box(d,(20,5,40,12),P['ink']); box(d,(24,7,36,10),P['intel'])
        box(d,(13,18,19,29),P['ink']); box(d,(58,11,63,18),P['ink'])
    else:
        box(d,(1,7,55,19),P['ink']); box(d,(5,9,51,16),P['steel'])
        box(d,(15,18,39,30),P['ink']); box(d,(18,20,36,27),P['supply'])
        box(d,(5,19,11,27),P['ink']); box(d,(55,6,63,20),P['ink'])
        box(d,(8,7,43,8),P['steel_hi'])
    return save_asset(f'weapons/{kind}',im)


def item(kind):
    im=canvas(32,32); d=ImageDraw.Draw(im)
    if kind=='medkit':
        box(d,(4,5,27,27),P['ink']); box(d,(6,7,25,25),P['paper'])
        box(d,(13,10,18,23),P['mint']); box(d,(9,14,22,19),P['mint'])
    elif kind=='grenade':
        box(d,(12,2,19,8),P['ink']); box(d,(8,8,23,27),P['ink'])
        box(d,(10,10,21,24),'#7FAD86'); box(d,(10,16,21,18),P['mint_lo'])
        box(d,(19,4,29,6),P['ink'])
    elif kind=='ammo':
        box(d,(3,9,28,27),P['ink']); box(d,(5,11,26,25),P['supply'])
        box(d,(9,5,22,10),P['ink']); box(d,(12,6,19,8),P['paper'])
        box(d,(11,14,20,21),P['ink']); box(d,(14,11,17,24),P['ink'])
    elif kind=='intel':
        d.polygon([(6,3),(25,3),(25,23),(19,29),(6,29)],fill=P['ink'])
        d.polygon([(8,5),(23,5),(23,22),(18,27),(8,27)],fill=P['intel'])
        box(d,(11,9,20,11),P['paper']); box(d,(11,16,20,18),P['paper'])
    elif kind=='supply':
        d.polygon([(8,4),(23,4),(30,16),(23,28),(8,28),(1,16)],fill=P['ink'])
        d.polygon([(9,7),(22,7),(26,16),(22,25),(9,25),(5,16)],fill=P['supply'])
        box(d,(14,10,17,22),P['paper'])
    elif kind=='molotov':
        box(d,(13,1,19,8),P['ink']); box(d,(9,8,23,27),P['ink'])
        box(d,(11,10,21,24),P['supply']); d.polygon([(16,15),(12,23),(20,23)],fill=P['danger'])
        d.line([(17,5),(25,1),(27,7)],fill=P['danger'],width=2)
    elif kind=='shield':
        d.polygon([(16,2),(29,8),(27,20),(16,30),(5,20),(3,8)],fill=P['ink'])
        d.polygon([(16,5),(25,10),(24,19),(16,26),(8,19),(7,10)],fill=P['intel'])
        box(d,(14,10,17,22),P['paper'])
    elif kind=='missile':
        d.polygon([(3,27),(20,3),(28,11),(11,30)],fill=P['ink'])
        d.polygon([(8,24),(21,7),(24,10),(11,26)],fill=P['paper'])
        d.polygon([(7,18),(2,15),(2,26)],fill=P['danger'])
    elif kind=='airdrop':
        d.pieslice((2,1,30,20),180,360,fill=P['paper'],outline=P['ink'],width=2)
        d.line([(7,12),(10,18)],fill=P['ink'],width=2); d.line([(25,12),(22,18)],fill=P['ink'],width=2)
        box(d,(5,18,27,29),P['ink']); box(d,(7,20,25,27),P['mint']); box(d,(14,21,18,26),P['supply'])
    return save_asset(f'items/{kind}',im)


def prop(kind, state='open'):
    im=canvas(64,64); d=ImageDraw.Draw(im)
    if kind in ('fortress_door','dungeon_door'):
        wall=P['wall_lo'] if kind=='fortress_door' else '#777B9A'
        light=P['intel'] if kind=='fortress_door' else P['supply']
        box(d,(4,3,59,62),P['ink']); box(d,(8,7,55,59),wall)
        box(d,(14,11,49,57),P['ink']); box(d,(18,14,45,57),P['floor'] if state=='open' else wall)
        box(d,(7,6,56,11),light)
        if state=='locked':
            box(d,(30,14,33,57),P['ink']); box(d,(18,34,45,39),P['ink'])
            box(d,(22,22,27,27),P['danger']); box(d,(37,22,42,27),P['danger'])
        else:
            d.line([(32,48),(32,28),(23,37)],fill=P['mint_lo'],width=3)
            d.line([(32,28),(41,37)],fill=P['mint_lo'],width=3)
    elif kind in ('forest_sign','beach_sign'):
        wood='#856E57' if kind=='forest_sign' else '#9D795C'
        box(d,(29,19,35,62),P['ink']); box(d,(30,21,34,60),wood)
        d.polygon([(7,8),(51,8),(60,23),(51,38),(7,38)],fill=P['ink'])
        d.polygon([(10,11),(50,11),(56,23),(50,35),(10,35)],fill=P['supply'] if state=='open' else '#AAB2A9')
        d.line([(18,23),(45,23)],fill=P['ink'],width=3)
        d.line([(38,16),(45,23),(38,30)],fill=P['ink'],width=3)
        if state=='locked': d.line([(10,42),(54,54)],fill=P['danger'],width=6)
    elif kind in ('city_road','village_road'):
        road='#819BA9' if kind=='city_road' else '#D7AD79'
        d.polygon([(18,0),(46,0),(62,64),(2,64)],fill=road)
        for yy in [5,22,43]: box(d,(30,yy,33,yy+10),P['paper'])
        if state=='locked':
            box(d,(1,35,62,48),P['ink']); box(d,(3,37,60,46),P['danger'])
        else:
            d.line([(32,25),(32,6),(23,15)],fill=P['ink'],width=3)
            d.line([(32,6),(41,15)],fill=P['ink'],width=3)
    elif kind=='weapon_chest':
        box(d,(7,27,56,58),P['ink']); box(d,(10,30,53,55),P['supply'])
        box(d,(6,20,57,30),P['ink']); box(d,(9,22,54,27),P['gold'])
        box(d,(27,35,37,51),P['paper']); box(d,(29,32,35,49),P['ink'])
    elif kind=='shop_stall':
        box(d,(8,26,56,58),P['ink']); box(d,(11,29,53,55),P['paper'])
        d.polygon([(6,24),(15,8),(49,8),(58,24)],fill=P['ink'])
        d.polygon([(10,22),(17,11),(47,11),(54,22)],fill=P['enemy'])
        box(d,(23,35,40,52),P['supply']); box(d,(27,38,36,49),P['paper'])
    return save_asset(f'props/{kind}_{state}',im)


def build_assets():
    A={}
    for d in ['N','NE','E','SE','S','SW','W','NW']: A[f'player_{d}']=player(d)
    for k in ['infantry','assault','heavy']: A[k]=enemy(k)
    for p in [1,2]: A[f'boss_{p}']=boss(p)
    for k in ['pistol','smg','shotgun','sniper','machine']: A[k]=weapon(k)
    for k in ['medkit','grenade','ammo','intel','supply','molotov','shield','missile','airdrop']: A[k]=item(k)
    for k in ['fortress_door','dungeon_door','forest_sign','beach_sign','city_road','village_road']:
        for st in ['locked','open']: A[f'{k}_{st}']=prop(k,st)
    for k in ['weapon_chest','shop_stall']: A[k]=prop(k)
    return A


def environment(kind,A):
    im=canvas(160,112); d=ImageDraw.Draw(im)
    floors={'forest':'#CAE6AA','village':'#C9DFAC','fortress':'#B5D9DB',
            'beach':'#F6DEAA','city':'#C5D4D8','dungeon':'#B9B8D1'}
    d.rectangle((0,0,159,111),fill=floors[kind])
    if kind=='forest':
        d.polygon([(60,112),(70,0),(93,0),(106,112)],fill='#E8D9A6')
        for x,y in [(4,7),(29,6),(121,7),(141,20),(5,70),(141,75)]:
            box(d,(x+6,y+13,x+12,y+32),'#856E57')
            d.polygon([(x,y+21),(x+9,y),(x+19,y+21)],fill='#65B980',outline=P['ink'])
        for x,y in [(46,26),(117,50),(18,88),(132,96)]: box(d,(x,y,x+3,y+3),'#79C98D')
        im.alpha_composite(A['forest_sign_open'],(49,-17))
    elif kind=='village':
        d.polygon([(57,112),(69,0),(91,0),(103,112)],fill='#D7AD79')
        for x in [8,20,130,143]:
            box(d,(x,28,x+3,61),'#8C755C')
        d.line([(8,38),(26,38)],fill='#8C755C',width=3)
        d.line([(128,38),(151,38)],fill='#8C755C',width=3)
        box(d,(9,74,39,96),P['supply'],P['ink']); d.polygon([(5,74),(24,59),(43,74)],fill=P['enemy'],outline=P['ink'])
        im.alpha_composite(A['village_road_open'],(48,-26))
    elif kind=='fortress':
        for x in range(0,160,16): d.line([(x,0),(x,111)],fill=P['wall'],width=1)
        for y in range(0,112,16): d.line([(0,y),(159,y)],fill=P['wall'],width=1)
        box(d,(0,0,159,12),P['wall_lo']); box(d,(0,0,10,111),P['wall_lo']); box(d,(149,0,159,111),P['wall_lo'])
        box(d,(14,47,27,66),P['steel'],P['ink']); box(d,(132,47,145,66),P['steel'],P['ink'])
        im.alpha_composite(A['fortress_door_open'],(48,-17))
    elif kind=='beach':
        box(d,(0,0,32,111),'#77D5D2'); d.line([(34,0),(34,111)],fill='#C8F1E8',width=6)
        d.polygon([(60,112),(69,0),(92,0),(101,112)],fill='#FCEBC5')
        for x,y in [(44,22),(128,31),(49,83),(123,93)]:
            d.polygon([(x,y),(x+5,y-3),(x+10,y+3),(x+5,y+6)],fill=P['paper'],outline='#D7B479')
        im.alpha_composite(A['beach_sign_open'],(49,-17))
    elif kind=='city':
        box(d,(0,0,43,111),'#7DAFE8'); box(d,(117,0,159,111),'#8BC8C1')
        box(d,(47,0,113,111),'#819BA9')
        for y in [6,37,68,99]: box(d,(79,y,82,y+14),P['paper'])
        for x in [7,23,126,142]:
            box(d,(x,22,x+9,34),P['paper'])
            box(d,(x,52,x+9,64),P['paper'])
        im.alpha_composite(A['city_road_open'],(48,-26))
    else:
        for x in range(0,160,16): d.line([(x,0),(x,111)],fill='#9293AF',width=1)
        for y in range(0,112,16): d.line([(0,y),(159,y)],fill='#9293AF',width=1)
        box(d,(0,0,159,12),'#777B9A'); box(d,(0,0,10,111),'#777B9A'); box(d,(149,0,159,111),'#777B9A')
        box(d,(21,38,29,55),'#777B9A'); box(d,(132,45,140,62),'#777B9A')
        im.alpha_composite(A['dungeon_door_open'],(48,-17))
    im.alpha_composite(A['player_N'],(56,66))
    im.alpha_composite(A['infantry'],(104,65))
    return save_asset(f'environments/{kind}_room',im)


def effect(kind,frame=0):
    w=h=64 if kind in ('telegraph_line','telegraph_cone','explosion') else 32
    im=canvas(w,h); d=ImageDraw.Draw(im)
    if kind=='friendly_bullet':
        d.polygon([(2,11),(20,11),(30,16),(20,21),(2,21)],fill=P['ink'])
        d.polygon([(5,13),(20,13),(26,16),(20,19),(5,19)],fill=P['gold'])
    elif kind=='enemy_bullet':
        d.ellipse((5,5,26,26),fill=P['ink'])
        d.ellipse((8,8,23,23),fill=P['danger'])
        d.ellipse((10,9,14,13),fill=P['enemy_hi'])
    elif kind=='telegraph_line':
        d.line([(5,32),(58,32)],fill=P['danger'],width=5)
        for x in [12,29,46]: box(d,(x,25,x+6,28),P['enemy_hi'])
        d.polygon([(58,23),(63,32),(58,41)],fill=P['danger'])
    elif kind=='telegraph_cone':
        d.pieslice((-4,-4,68,68),-28,28,fill='#F7B3A7',outline=P['danger'],width=3)
        d.ellipse((26,26,38,38),fill=P['enemy_lo'])
    elif kind=='explosion':
        r=[14,25,30][frame]
        d.ellipse((32-r,32-r,32+r,32+r),outline=P['ink'],width=4)
        d.ellipse((35-r,35-r,29+r,29+r),outline=P['gold'],width=5)
        if frame==1:
            for x,y in [(5,6),(50,8),(8,49),(54,51)]: box(d,(x,y,x+5,y+5),P['danger'])
    elif kind=='heal':
        box(d,(13,2,18,29),P['mint']); box(d,(2,13,29,18),P['mint'])
        box(d,(14,4,17,27),P['paper']); box(d,(4,14,27,17),P['paper'])
    elif kind=='upload':
        d.polygon([(16,2),(29,16),(21,16),(21,29),(11,29),(11,16),(3,16)],fill=P['intel'],outline=P['ink'])
        box(d,(5,30,27,31),P['intel'])
    elif kind=='hit_flash':
        d.rectangle((3,3,28,28),outline=P['paper'],width=3)
        for x,y in [(0,0),(27,0),(0,27),(27,27)]: box(d,(x,y,x+4,y+4),P['danger'])
    elif kind=='muzzle_flash':
        d.polygon([(16,1),(20,11),(30,9),(23,16),(30,23),(20,21),(16,31),(12,21),(2,23),(9,16),(2,9),(12,11)],fill=P['gold'],outline=P['ink'])
        d.ellipse((12,12,20,20),fill=P['paper'])
    elif kind=='room_clear':
        d.polygon([(16,1),(20,11),(31,16),(20,20),(16,31),(12,20),(1,16),(12,11)],fill=P['mint'],outline=P['ink'])
        d.line([(8,16),(14,22),(24,9)],fill=P['paper'],width=4)
    return save_asset(f'effects/{kind}' + (f'_{frame}' if kind=='explosion' else ''),im)


def text(d,xy,value,size=24,color=None,weight='regular'):
    d.text(xy,value,font=font(size),fill=color or P['ink'])


def sheet(title,subtitle,w=1600,h=1000):
    im=canvas(w,h,P['paper']); d=ImageDraw.Draw(im)
    box(d,(0,0,w-1,10),P['mint'])
    text(d,(48,38),title,42)
    text(d,(50,100),subtitle,21,'#5D7480')
    return im,d


def card(d,xy,title,sub=None):
    x1,y1,x2,y2=xy
    d.rounded_rectangle(xy,radius=20,fill='#FFFFFF',outline=P['ink'],width=3)
    text(d,(x1+22,y1+17),title,26)
    if sub: text(d,(x1+22,y1+56),sub,17,'#5D7480')


def paste_nearest(dest,asset,x,y,scale=4):
    img=asset.resize((asset.width*scale,asset.height*scale),Image.Resampling.NEAREST)
    dest.alpha_composite(img,(int(x),int(y)))


def swatch(d,x,y,color,label):
    d.rounded_rectangle((x,y,x+48,y+48),radius=7,fill=color,outline=P['ink'],width=2)
    text(d,(x+61,y+9),label,20)


def sheet_characters(A):
    im,d=sheet('角色设计图','统一源像素尺寸 · 玩家头身约 1:1 · 敌人同时依靠轮廓和阵营色区分')
    card(d,(40,155,1000,680),'前哨空降兵｜八方向','32×32 透明画布；V 形面罩、黄色围巾与枪口方向相互补充')
    dirs=[('N','上'),('NE','右上'),('E','右'),('SE','右下'),('S','下'),('SW','左下'),('W','左'),('NW','左上')]
    for i,(key,label) in enumerate(dirs):
        x=72+(i%4)*225; y=255+(i//4)*198
        d.rounded_rectangle((x,y,x+190,y+168),radius=12,fill=P['floor'],outline='#D7CFB2',width=2)
        paste_nearest(im,A[f'player_{key}'],x+31,y+4,4)
        text(d,(x+76,y+138),label,20)
    card(d,(1020,155,1560,680),'普通敌人','三类轮廓独立；红色只表示敌方')
    for i,(key,label,desc) in enumerate([('infantry','步兵','窄帽 / 短枪'),('assault','突击兵','前倾 / 尖角'),('heavy','重装兵','宽肩 / 双甲')]):
        y=246+i*132
        d.rounded_rectangle((1040,y,1538,y+111),radius=9,fill=P['floor'])
        paste_nearest(im,A[key],1057,y-7,3)
        text(d,(1189,y+25),label,23)
        text(d,(1330,y+31),desc,18,'#5D7480')
    card(d,(40,702,1560,954),'要塞指挥官｜两阶段','固定中心的通信装甲；第二阶段只改变核心与外环，不改变主轮廓和碰撞读法')
    paste_nearest(im,A['boss_1'],120,775,2)
    paste_nearest(im,A['boss_2'],656,775,2)
    text(d,(280,807),'一阶段 · 蓝色信号核',24)
    text(d,(816,807),'二阶段 · 红核与金环',24)
    swatch(d,1230,791,P['mint'],'友方')
    swatch(d,1230,863,P['enemy'],'敌方')
    im.save(ROOT/'01_characters.png')


def sheet_equipment(A):
    im,d=sheet('武器与物品设计图','五种枪的外轮廓和弹匣部位各不相同；所有道具在 32px 图标尺寸下可辨')
    card(d,(40,155,1560,496),'五种枪械｜64×32','绘制方向统一朝右；角色持枪时按八方向旋转')
    guns=[('pistol','手枪','短机匣'),('smg','冲锋枪','直弹匣'),('shotgun','霰弹枪','双管粗口'),('sniper','狙击步枪','长枪管 + 镜'),('machine','重机枪','宽机匣 + 弹盒')]
    for i,(key,label,note) in enumerate(guns):
        x=65+i*298
        d.rounded_rectangle((x,245,x+277,454),radius=12,fill=P['floor'],outline='#D7CFB2',width=2)
        paste_nearest(im,A[key],x+24,286,3)
        text(d,(x+18,388),label,23)
        text(d,(x+18,421),note,17,'#5D7480')
    card(d,(40,520,1050,955),'首版物品｜32×32','物资接触拾取；医疗、手雷、弹药与武器箱按策划规则领取')
    first=[('medkit','医疗包'),('grenade','手雷'),('ammo','弹药箱'),('intel','情报'),('supply','物资')]
    for i,(key,label) in enumerate(first):
        x=64+i*194
        d.rounded_rectangle((x,600,x+177,807),radius=12,fill=P['floor'],outline='#D7CFB2',width=2)
        paste_nearest(im,A[key],x+24,625,4)
        text(d,(x+29,772),label,21)
    text(d,(67,845),'颜色语义：治疗青绿  /  情报蓝  /  物资金  /  敌弹珊瑚红',20)
    card(d,(1070,520,1560,955),'v1.1 扩展设计','首版 UI 不放这些未实现的功能按钮')
    ext=[('molotov','燃烧瓶'),('shield','盾牌'),('missile','导弹'),('airdrop','空投')]
    for i,(key,label) in enumerate(ext):
        x=1090+(i%2)*225; y=616+(i//2)*158
        d.rounded_rectangle((x,y,x+200,y+139),radius=12,fill=P['floor'])
        paste_nearest(im,A[key],x+17,y+5,3)
        text(d,(x+105,y+51),label,20)
    im.save(ROOT/'02_equipment.png')


def sheet_environments(A):
    im,d=sheet('六类场景设计图','当前三关建议：森林外围哨站 → 乡村补给营地 → 通信要塞；其余环境为后续接入设计',h=1110)
    scenes=[('forest','森林','草地 / 树影 / 路牌'),('village','乡村','土路 / 篱笆 / 马路'),('fortress','要塞','金属板 / 门口'),
            ('beach','沙滩','金沙 / 海浪 / 路牌'),('city','城市','灰蓝街区 / 马路'),('dungeon','地牢','浅紫石砖 / 门口')]
    for i,(key,label,desc) in enumerate(scenes):
        col,row=i%3,i//3; x=40+col*520; y=160+row*455
        card(d,(x,y,x+490,y+423),label,desc)
        d.rounded_rectangle((x+19,y+92,x+471,y+388),radius=8,fill=P['floor'])
        paste_nearest(im,A[f'room_{key}'],x+40,y+103,2)
        text(d,(x+34,y+391),'玩家 / 敌人颜色保持一致',17,'#5D7480')
    im.save(ROOT/'03_environments.png')


def sheet_interactables(A):
    im,d=sheet('可交互场景设计图','同一关卡出口交互：封锁时不可离开，清房后开放；目的地名称和 E 提示跟随环境外壳',h=1070)
    families=[('fortress_door','要塞门口','门板合上 → 门洞开放'),('forest_sign','森林路牌','箭头灰显 → 箭头亮起'),('city_road','城市马路','路障拦截 → 道路连通'),
              ('dungeon_door','地牢门口','石门阻断 → 石门开放'),('beach_sign','沙滩路牌','木牌封锁 → 沙路可见'),('village_road','乡村马路','路障移开 → 乡道连通')]
    for i,(key,label,sub) in enumerate(families):
        col,row=i%3,i//3; x=40+col*520; y=160+row*365
        card(d,(x,y,x+490,y+338),label,sub)
        for j,(state,cap) in enumerate([('locked','封锁'),('open','开放')]):
            xx=x+53+j*204
            d.rounded_rectangle((xx,y+102,xx+177,y+186),radius=9,fill=P['floor'])
            paste_nearest(im,A[f'{key}_{state}'],xx+28,y+69,2)
            text(d,(xx+61,y+275),cap,20)
    card(d,(40,910,1560,1030),'功能装置｜跨环境共用图标','商店与武器箱保留固定图标；外框材质可按森林、城市或要塞场景替换')
    paste_nearest(im,A['shop_stall'],940,906,2)
    paste_nearest(im,A['weapon_chest'],1160,906,2)
    text(d,(854,955),'商店',20)
    text(d,(1316,955),'武器箱',20)
    im.save(ROOT/'04_interactables.png')


def sheet_effects(A):
    im,d=sheet('战斗特效设计图','友弹为尖头，敌弹为圆点；预警线和扇形边界对应最终判定',h=1170)
    entries=[
        ('friendly_bullet','友方子弹','短尖头'),('enemy_bullet','敌方子弹','珊瑚红圆点'),
        ('telegraph_line','单发前摇','虚线与枪口亮点'),('telegraph_cone','扇形前摇','扇形对应三弹方向'),
        ('explosion_0','爆炸 1','聚拢'),('explosion_1','爆炸 2','范围最亮'),('explosion_2','爆炸 3','残环'),
        ('heal','治疗','青绿十字'),('upload','情报上传','蓝色上行'),
        ('hit_flash','受击','短时亮边'),('muzzle_flash','枪口闪光','一至两帧'),('room_clear','清房反馈','青绿完成标记')]
    for i,(key,label,desc) in enumerate(entries):
        col,row=i%3,i//3; x=40+col*520; y=160+row*244
        card(d,(x,y,x+490,y+216),label,desc)
        a=A[key]; scale=2 if a.width==64 else 4
        paste_nearest(im,a,x+310,y+54,scale)
    im.save(ROOT/'05_effects.png')


def button(d,xy,label,fill=P['paper'],enabled=True):
    color=fill if enabled else '#B7BEC0'
    d.rounded_rectangle(xy,radius=8,fill=color,outline=P['ink'],width=3)
    x1,y1,x2,y2=xy
    text(d,(x1+18,y1+8),label,20)


def sheet_ui(A):
    im,d=sheet('界面组件设计图','独立的 HUD、指挥部、商店、地图和结算模块；所有数值只是排版样例',h=1120)
    card(d,(40,154,1560,360),'战斗 HUD','浅色底板，深色文字；生命、弹药、物资、情报分别标明')
    d.rounded_rectangle((63,228,1537,332),radius=11,fill=P['paper'],outline=P['ink'],width=4)
    hud=[(77,238,237,310,'生命 76 / 100',P['mint']),
         (250,238,479,310,'手枪  08 / 36',P['floor']),
         (492,238,785,310,'① 手枪  ② 冲锋枪',P['floor']),
         (798,238,933,310,'③ 空槽',P['floor']),
         (946,238,1125,310,'物资 38',P['supply']),
         (1138,238,1321,310,'情报 28',P['intel']),
         (1334,238,1520,310,'手雷 × 2',P['floor'])]
    for x1,y1,x2,y2,label,fill in hud:
        d.rounded_rectangle((x1,y1,x2,y2),radius=7,fill=fill,outline=P['ink'],width=2)
        text(d,(x1+9,y1+19),label,18)
    d.polygon([(1107,255),(1117,263),(1117,282),(1107,290),(1097,282),(1097,263)],fill=P['paper'])
    box(d,(1299,256,1311,289),P['paper']); box(d,(1302,263,1308,265),P['intel'])
    card(d,(40,385,770,775),'指挥部','永久情报、强化、出击与最终资格')
    d.rounded_rectangle((61,465,749,747),radius=10,fill=P['paper'],outline=P['ink'],width=2)
    text(d,(80,486),'前哨指挥部',28)
    text(d,(500,489),'永久情报 160',21,P['intel'])
    for i,(name,detail) in enumerate([('医疗保障 Lv.1','生命 110 → 120   /   70 情报'),('武器校准 Lv.0','手枪 10 → 12   /   40 情报'),('前线补给 Lv.0','物资 0 → 10   /   40 情报')]):
        yy=538+i*57
        d.rounded_rectangle((81,yy,727,yy+49),radius=6,fill='#FFFFFF',outline='#D8D1BE',width=2)
        text(d,(91,yy+8),name,20)
        text(d,(320,yy+11),detail,18,'#5D7480')
    button(d,(81,713,274,746),'普通行动',P['mint'])
    button(d,(288,713,500,746),'最终行动 ×1',P['intel'])
    card(d,(793,385,1560,775),'商店 / 武器库','价格、效果、售罄与领取状态必须可见')
    d.rounded_rectangle((815,465,1538,747),radius=10,fill=P['paper'],outline=P['ink'],width=2)
    text(d,(833,485),'补给商店',28)
    text(d,(1320,489),'本轮物资 38',20,'#A4752F')
    for i,(name,detail,cost,en) in enumerate([('医疗包','立即恢复 25 HP','15',True),('弹药','所选枪 +2 弹匣','10',True),('霰弹枪','满匣 + 初始备弹','35',False)]):
        yy=540+i*58
        d.rounded_rectangle((835,yy,1517,yy+49),radius=6,fill='#FFFFFF',outline='#D8D1BE',width=2)
        text(d,(849,yy+8),name,20)
        text(d,(1050,yy+10),detail,18,'#5D7480')
        button(d,(1445,yy+7,1504,yy+42),cost,P['supply'],en)
    card(d,(40,799,770,1077),'地图 / 暂停','Tab 按住显示简图；Esc 暂停，战斗计时和子弹一起冻结')
    for i,(x,y,col) in enumerate([(117,882,P['mint']),(217,882,P['wall']),(317,882,P['enemy']),(317,969,P['supply']),(417,882,P['intel'])]):
        box(d,(x,y,x+72,y+64),col,P['ink'],3)
    for p1,p2 in [((189,914),(217,914)),((289,914),(317,914)),((389,914),(417,914)),((353,946),(353,969))]:
        d.line((p1,p2),fill=P['ink'],width=5)
    text(d,(540,894),'当前 / 已清 / 战斗',18)
    text(d,(540,924),'商店 / 出口',18)
    text(d,(100,1040),'Esc 继续   ·   放弃行动并结算',18)
    card(d,(793,799,1560,1077),'行动结算','清晰分开本轮收益、额外奖励与最终资格')
    text(d,(835,888),'普通三关完成',27)
    text(d,(835,936),'到达：通信要塞出口    击杀：42',19)
    text(d,(835,976),'本轮情报 128 + 通关奖励 32 = 160',20,P['intel'])
    text(d,(835,1011),'最终行动资格：0 → 1',20)
    button(d,(1250,1026,1513,1063),'返回指挥部',P['mint'])
    im.save(ROOT/'06_ui.png')


def sheet_menus(A):
    im,d=sheet('菜单与叙事界面设计图','主菜单、武器库、设置、暂停、任务简报、胜利结局：每个页面都有明确的下一步',h=1050)
    blocks=[('主菜单','开始、设置、退出',40,160),('武器库','四项分别领取',560,160),('设置','总音量可用',1080,160),
            ('暂停','继续或放弃',40,600),('任务简报','短文本 + 目标',560,600),('胜利结局','进入同一结算流程',1080,600)]
    for name,sub,x,y in blocks:
        card(d,(x,y,x+480,y+402),name,sub)
        d.rounded_rectangle((x+18,y+88,x+462,y+375),radius=10,fill=P['paper'],outline=P['ink'],width=2)
    text(d,(84,279),'岚谷前哨',37)
    text(d,(85,331),'GUERRILLA VANGUARD',18,P['mint_lo'])
    button(d,(84,389,474,431),'开始行动',P['mint'])
    button(d,(84,451,264,493),'设置')
    button(d,(281,451,474,493),'退出游戏')
    for i,(key,name) in enumerate([('pistol','随机武器'),('ammo','全枪弹药'),('medkit','医疗包'),('grenade','手雷包')]):
        x=586; y=269+i*66
        d.rounded_rectangle((x,y,x+428,y+58),radius=7,fill='#FFFFFF',outline='#D8D1BE',width=2)
        paste_nearest(im,A[key],x+13,y+1,1)
        text(d,(x+91,y+11),name,19)
        text(d,(x+314,y+14),'未领取',16,P['mint_lo'])
    text(d,(1127,297),'总音量',24)
    d.rounded_rectangle((1128,351,1500,372),radius=8,fill='#C5D4D8',outline=P['ink'],width=2)
    d.rounded_rectangle((1128,351,1402,372),radius=8,fill=P['mint'],outline=P['ink'],width=2)
    d.ellipse((1387,342,1416,381),fill=P['paper'],outline=P['ink'],width=3)
    text(d,(1128,399),'75%',22)
    button(d,(1128,455,1500,499),'返回')
    text(d,(85,719),'行动已暂停',32)
    button(d,(84,781,474,827),'继续游戏',P['mint'])
    button(d,(84,844,474,890),'放弃行动并结算')
    text(d,(85,925),'局内进度无法在重启后继续',16,'#5D7480')
    text(d,(603,720),'外围哨站 · 任务简报',25)
    text(d,(603,777),'夺取敌方数据，改善指挥部支援能力。',19)
    text(d,(603,812),'找到最终空降的行动窗口。',19)
    button(d,(604,872,972,920),'开始普通行动',P['mint'])
    text(d,(1124,720),'通信网络已切断',25)
    text(d,(1124,781),'敌军失去统一指挥，',20)
    text(d,(1124,819),'岚谷封锁解除。',20)
    button(d,(1124,872,1492,920),'查看行动结算',P['intel'])
    im.save(ROOT/'07_menus.png')


if __name__=='__main__':
    assets=build_assets()
    for kind in ['forest','village','fortress','beach','city','dungeon']:
        assets[f'room_{kind}']=environment(kind,assets)
    for kind in ['friendly_bullet','enemy_bullet','telegraph_line','telegraph_cone','heal','upload','hit_flash','muzzle_flash','room_clear']:
        assets[kind]=effect(kind)
    for frame in range(3): assets[f'explosion_{frame}']=effect('explosion',frame)
    sheet_characters(assets)
    sheet_equipment(assets)
    sheet_environments(assets)
    sheet_interactables(assets)
    sheet_effects(assets)
    sheet_ui(assets)
    sheet_menus(assets)
