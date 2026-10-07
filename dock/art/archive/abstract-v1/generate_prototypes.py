"""Generate editable, scale independent pixel-art concept sheets for art step 2."""
from html import escape
from pathlib import Path

OUT = Path(__file__).parent
C = {
    "ink": "#263F52", "paper": "#FFF8E8", "floor": "#F4EBCF",
    "mint": "#59CFA7", "mint_dark": "#339D83", "scarf": "#FFCA70",
    "enemy": "#EF746B", "enemy_dark": "#A64F65", "danger": "#EF5C72",
    "gold": "#F8D76D", "supply": "#F0BB58", "intel": "#7DAFE8",
    "wall": "#8BC8C1", "wall_dark": "#5D9F9D", "soft": "#E5DABB",
}


class SVG:
    def __init__(self, w, h, title):
        self.w, self.h = w, h
        self.parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">',
                      f'<title>{escape(title)}</title>',
                      '<rect width="100%" height="100%" fill="#FFF8E8"/>',
                      '<rect width="100%" height="9" fill="#59CFA7"/>']

    def raw(self, s): self.parts.append(s)
    def rect(self, x, y, w, h, fill, stroke=None, sw=2, rx=0):
        self.raw(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}"' +
                 (f' stroke="{stroke}" stroke-width="{sw}"' if stroke else '') + '/>')
    def circle(self, x, y, r, fill, stroke=None, sw=2):
        self.raw(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"' +
                 (f' stroke="{stroke}" stroke-width="{sw}"' if stroke else '') + '/>')
    def path(self, d, fill="none", stroke=None, sw=2, extra=""):
        self.raw(f'<path d="{d}" fill="{fill}"' +
                 (f' stroke="{stroke}" stroke-width="{sw}"' if stroke else '') + f' {extra}/>')
    def text(self, x, y, t, size=18, weight=500, fill=None, anchor=None):
        self.raw(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" fill="{fill or C["ink"]}" font-family="PingFang SC, Noto Sans CJK SC, sans-serif"' +
                 (f' text-anchor="{anchor}"' if anchor else '') + f'>{escape(t)}</text>')
    def group(self, transform, crisp=False):
        self.raw(f'<g transform="{transform}"' + (' shape-rendering="crispEdges"' if crisp else '') + '>')
    def end(self): self.raw('</g>')
    def panel(self, x, y, w, h, title, subtitle=""):
        self.rect(x, y, w, h, '#FFFFFF', C['ink'], 2, 13)
        self.text(x+18, y+31, title, 20, 700)
        if subtitle: self.text(x+18, y+54, subtitle, 13, 400, '#5D7480')
    def save(self, name):
        (OUT / name).write_text('\n'.join(self.parts + ['</svg>']) + '\n', encoding='utf-8')


def player(s, x, y, scale=3, facing=0):
    """0=down, then clockwise in 45 degree increments."""
    s.group(f'translate({x} {y}) scale({scale})', True)
    s.raw('<ellipse cx="16" cy="30" rx="11" ry="3" fill="#5D9F9D" opacity="0.4"/>')
    s.rect(7, 17, 18, 12, C['ink'])
    s.rect(9, 18, 14, 10, C['mint'])
    s.rect(9, 27, 5, 3, C['ink']); s.rect(19, 27, 5, 3, C['ink'])
    s.rect(6, 4, 21, 15, C['ink'])
    s.rect(8, 6, 17, 11, C['mint'])
    s.rect(10, 4, 13, 3, '#95E8C9')
    if facing in (0, 1, 7):
        s.path('M12 11l4 3 4-3', 'none', C['paper'], 2)
        s.rect(14, 18, 7, 3, C['scarf'])
    elif facing in (3, 4, 5):
        s.rect(12, 9, 10, 3, C['mint_dark'])
        s.rect(14, 18, 7, 3, C['scarf'])
    elif facing == 2:
        s.rect(21, 10, 3, 4, C['paper']); s.rect(11, 18, 8, 3, C['scarf'])
    else:
        s.rect(9, 10, 3, 4, C['paper']); s.rect(17, 18, 8, 3, C['scarf'])
    # Gun pivot rotates separately so aim is unambiguous at small scale.
    angle = [90, 45, 0, -45, -90, -135, 180, 135][facing]
    s.group(f'rotate({angle} 16 17)', True)
    s.rect(17, 14, 12, 6, C['ink'])
    s.rect(19, 15, 8, 4, '#879CA4')
    s.rect(28, 15, 4, 4, C['ink'])
    s.end(); s.end()


def enemy(s, x, y, kind, scale=3):
    s.group(f'translate({x} {y}) scale({scale})', True)
    s.raw('<ellipse cx="16" cy="31" rx="12" ry="3" fill="#A64F65" opacity="0.25"/>')
    if kind == 'infantry':
        s.rect(8, 6, 17, 11, C['ink']); s.rect(10, 7, 13, 9, C['enemy'])
        s.rect(7, 5, 19, 4, C['enemy_dark']); s.rect(11, 11, 3, 2, C['paper'])
        s.rect(9, 18, 15, 11, C['ink']); s.rect(11, 19, 11, 8, C['enemy_dark'])
        s.rect(23, 20, 9, 4, C['ink'])
    elif kind == 'assault':
        s.path('M6 13L21 3l7 14z', C['ink']); s.path('M10 12l11-6 4 9z', C['enemy'])
        s.rect(13, 16, 15, 12, C['ink']); s.rect(15, 18, 11, 9, C['enemy'])
        s.path('M24 20l8 3-8 4z', C['enemy_dark'], C['ink'], 1)
        s.rect(12, 28, 5, 3, C['ink']); s.rect(24, 27, 5, 3, C['ink'])
    elif kind == 'heavy':
        s.rect(5, 5, 23, 14, C['ink']); s.rect(7, 7, 19, 10, C['enemy_dark'])
        s.rect(11, 9, 12, 4, C['enemy']); s.rect(2, 17, 29, 12, C['ink'])
        s.rect(4, 18, 6, 9, C['enemy']); s.rect(23, 18, 6, 9, C['enemy'])
        s.rect(11, 18, 11, 9, C['enemy_dark'])
        s.rect(11, 29, 6, 3, C['ink']); s.rect(22, 29, 6, 3, C['ink'])
    s.end()


def boss(s, x, y, phase=1, scale=2.3):
    s.group(f'translate({x} {y}) scale({scale})', True)
    s.raw('<ellipse cx="32" cy="58" rx="30" ry="6" fill="#A64F65" opacity="0.25"/>')
    s.path('M9 10h46l9 16-6 27H6L0 26z', C['ink'])
    s.path('M12 13h40l7 15-5 21H10L5 28z', C['enemy_dark'])
    s.rect(1, 7, 12, 7, C['ink']); s.rect(4, 0, 6, 13, C['ink'])
    s.rect(51, 7, 12, 7, C['ink']); s.rect(54, 0, 6, 13, C['ink'])
    s.rect(10, 21, 13, 23, C['enemy']); s.rect(41, 21, 13, 23, C['enemy'])
    s.path('M32 18l14 10-5 17H23l-5-17z', C['ink'])
    s.path('M32 22l9 8-4 11H27l-4-11z', C['danger'] if phase == 2 else C['intel'])
    s.rect(20, 48, 24, 6, '#72818E')
    if phase == 2:
        s.path('M32 12l20 15-8 23H20l-8-23z', 'none', C['gold'], 2)
        s.rect(0, 26, 6, 5, C['gold']); s.rect(58, 26, 6, 5, C['gold'])
    s.end()


def heading(s, title, subtitle):
    s.text(42, 62, title, 32, 800)
    s.text(43, 92, subtitle, 16, 400, '#5D7480')


def characters():
    s = SVG(1400, 930, '角色原型：玩家、三类敌人、两阶段首领')
    heading(s, '01 角色原型', '头身约 1:1｜统一源像素语法｜方向由面罩 + 枪口同时传达')
    s.panel(40, 120, 850, 510, '前哨空降兵 · 八方向', '24×32 px 起点；白色 V、薄荷头盔、黄色围巾始终可识别')
    names = ['下', '右下', '右', '右上', '上', '左上', '左', '左下']
    for i in range(8):
        x = 70 + (i % 4)*204
        y = 215 + (i // 4)*194
        s.rect(x, y, 160, 152, C['floor'], '#D7CFB2', 1, 8)
        player(s, x+30, y+15, 3.1, i)
        s.text(x+80, y+137, names[i], 17, 700, anchor='middle')
    s.panel(912, 120, 448, 510, '敌人与阵营', '三敌靠剪影区分；相同珊瑚红只标记敌方')
    for i, (kind, label, note) in enumerate([
        ('infantry', '步兵', '窄帽 + 短枪'),
        ('assault', '突击兵', '前倾三角'),
        ('heavy', '重装兵', '宽肩双护甲')]):
        yy = 187 + i*135
        s.rect(932, yy, 408, 116, C['floor'], '#D7CFB2', 1, 8)
        enemy(s, 957, yy+13, kind, 2.7)
        s.text(1072, yy+45, label, 21, 700)
        s.text(1072, yy+78, note, 15, 400, '#5D7480')
    s.panel(40, 652, 1320, 233, '要塞指挥官 · 固定中心的通信核心', '64×64 px 起点；阶段变化只加亮信号核与外环，不改变核心轮廓')
    boss(s, 148, 709, 1, 2.25); boss(s, 591, 709, 2, 2.25)
    s.text(314, 796, '一阶段 · 蓝色信号核', 20, 700)
    s.text(757, 796, '二阶段 · 红核 + 金色外环', 20, 700)
    s.text(1030, 750, '形体 / 攻击提示', 18, 700)
    s.text(1030, 787, '固定不移动；单发 → 三发扇形', 15)
    s.text(1030, 815, '见 04 战斗特效原型', 15, 400, '#5D7480')
    s.save('01_characters.svg')


def gun(s, x, y, kind, scale=3):
    s.group(f'translate({x} {y}) scale({scale})', True)
    ink = C['ink']; steel = '#7895A2'
    if kind == 'pistol':
        s.rect(3, 7, 19, 5, ink); s.rect(6, 8, 14, 3, steel)
        s.rect(8, 12, 5, 11, ink); s.rect(9, 13, 3, 8, '#B1C7C9')
    elif kind == 'smg':
        s.rect(2, 6, 30, 6, ink); s.rect(4, 7, 24, 4, steel)
        s.rect(12, 12, 6, 15, ink); s.rect(13, 12, 4, 11, C['mint'])
        s.rect(3, 12, 5, 5, ink)
    elif kind == 'shotgun':
        s.rect(2, 5, 37, 7, ink); s.rect(4, 6, 32, 4, '#B1C7C9')
        s.rect(2, 13, 20, 5, C['supply']); s.rect(11, 18, 5, 9, ink)
        s.rect(35, 4, 7, 9, ink)
    elif kind == 'sniper':
        s.rect(1, 7, 44, 4, ink); s.rect(3, 8, 40, 2, steel)
        s.rect(16, 2, 15, 5, ink); s.rect(20, 3, 7, 3, C['intel'])
        s.rect(12, 11, 5, 12, ink); s.rect(43, 6, 8, 6, ink)
    elif kind == 'machine':
        s.rect(1, 5, 43, 9, ink); s.rect(4, 7, 35, 5, steel)
        s.rect(18, 14, 13, 12, ink); s.rect(20, 15, 9, 9, C['supply'])
        s.rect(5, 14, 6, 8, ink); s.rect(40, 4, 8, 11, ink)
    s.end()


def icon(s, x, y, kind, scale=3):
    s.group(f'translate({x} {y}) scale({scale})', True)
    if kind == 'med':
        s.rect(2, 3, 24, 22, C['ink']); s.rect(4, 5, 20, 18, C['paper'])
        s.rect(11, 8, 6, 12, C['mint']); s.rect(8, 11, 12, 6, C['mint'])
    elif kind == 'grenade':
        s.rect(10, 1, 8, 6, C['ink']); s.rect(6, 7, 16, 18, C['ink'])
        s.rect(8, 9, 12, 14, '#7FAD86'); s.rect(8, 14, 12, 3, C['mint_dark'])
        s.rect(18, 3, 9, 3, C['ink'])
    elif kind == 'ammo':
        s.rect(2, 7, 24, 17, C['ink']); s.rect(4, 9, 20, 13, C['supply'])
        s.rect(8, 4, 12, 5, C['ink']); s.rect(10, 5, 8, 3, C['paper'])
        s.rect(8, 13, 12, 4, C['ink']); s.rect(12, 10, 4, 10, C['ink'])
    elif kind == 'intel':
        s.path('M5 4h17v17l-5 5H5z', C['ink'])
        s.path('M7 6h13v13l-5 5H7z', C['intel'])
        s.rect(10, 9, 7, 3, C['paper']); s.rect(10, 15, 7, 3, C['paper'])
    elif kind == 'supply':
        s.path('M7 4h14l6 10-6 10H7L1 14z', C['ink'])
        s.path('M8 7h12l4 7-4 7H8l-4-7z', C['supply'])
        s.rect(12, 9, 4, 10, C['paper'])
    elif kind == 'chest':
        s.rect(1, 6, 26, 19, C['ink']); s.rect(3, 8, 22, 15, C['supply'])
        s.rect(1, 12, 26, 4, C['ink']); s.rect(11, 11, 7, 9, C['paper'])
    elif kind == 'shop':
        s.rect(3, 11, 22, 15, C['ink']); s.rect(5, 13, 18, 11, C['paper'])
        s.path('M3 11l4-7h14l4 7z', C['enemy'])
        s.rect(10, 17, 8, 7, C['supply'])
    elif kind == 'molotov':
        s.rect(11,1,7,7,C['ink']); s.rect(7,8,15,18,C['ink'])
        s.rect(9,10,11,13,C['supply']); s.path('M14 4l7-6 2 7', 'none',C['danger'],3)
        s.path('M14 15l-3 5h7z',C['danger'])
    elif kind == 'shield':
        s.path('M14 1l12 5v10l-12 11L2 16V6z',C['ink'])
        s.path('M14 5l8 4v6l-8 7-8-7V9z',C['intel'])
        s.rect(12,9,4,9,C['paper'])
    elif kind == 'missile':
        s.path('M3 22L19 3l6 6L9 26z',C['ink'])
        s.path('M7 21L19 7l2 2L9 23z',C['paper'])
        s.path('M10 17L2 14v8zM17 10l1-8 8 1z',C['danger'])
    elif kind == 'airdrop':
        s.rect(4,14,20,12,C['ink']); s.rect(6,16,16,8,C['mint'])
        s.path('M2 7Q14-4 26 7l-5 5H7z',C['paper'],C['ink'],2)
        s.path('M7 12l2 4m12-4l-2 4','none',C['ink'],2)
        s.rect(12,17,5,6,C['supply'])
    s.end()


def equipment():
    s = SVG(1400, 885, '武器、道具与交互物原型')
    heading(s, '02 武器与物品原型', '不同枪型用轮廓和长度识别；拾取物使用统一黑蓝描边、清晰符号')
    s.panel(40, 120, 1320, 320, '五种枪械', '源像素轮廓示意；枪口统一朝右，角色持枪时随面向旋转')
    weapons = [('pistol','手枪','短枪身'),('smg','冲锋枪','直弹匣'),('shotgun','霰弹枪','双管短粗'),('sniper','狙击步枪','长枪管 + 镜'),('machine','重机枪','宽机匣 + 弹盒')]
    for i,(kind,label,note) in enumerate(weapons):
        x = 61+i*258
        s.rect(x, 186, 238, 220, C['floor'], '#D7CFB2', 1, 8)
        gun(s, x+36, 240, kind, 3.4 if kind in ('pistol','smg') else 3.1)
        s.text(x+19, 361, label, 19, 700)
        s.text(x+19, 387, note, 14, 400, '#5D7480')
    s.panel(40, 460, 858, 385, '首版拾取物与可互动装置', '满血/满库存时不消耗；物资自动拾取，其他对象按 E')
    objects = [('med','医疗包','25 HP'),('grenade','手雷','范围伤害'),('ammo','弹药箱','补备弹'),('intel','情报','清房上传'),('supply','物资','接触拾取'),('chest','武器箱','按 E 领取'),('shop','商店','按 E 打开')]
    for i,(kind,label,note) in enumerate(objects):
        x = 59+(i%4)*206; y = 526+(i//4)*150
        s.rect(x, y, 185, 132, C['floor'], '#D7CFB2', 1, 8)
        icon(s, x+50, y+8, kind, 2.7)
        s.text(x+13, y+105, label, 16, 700)
        s.text(x+104, y+105, note, 12, 400, '#5D7480')
    s.panel(920, 460, 440, 385, 'v1.1 预留', '不在首版 HUD 与商店中显示未实现项')
    for j,(kind,label,note) in enumerate([('molotov','燃烧瓶','持续火区'),('shield','盾牌','短时免伤'),('missile','导弹','范围标记'),('airdrop','重机枪空投','落点补给')]):
        y=525+j*73
        s.rect(947,y,57,53,C['floor'],C['ink'],2,6)
        icon(s,951,y+1,kind,1.8)
        s.text(1024,y+23,label,18,700)
        s.text(1024,y+45,note,13,400,'#5D7480')
    s.save('02_equipment.svg')


def exit_marker(s, cx, top, family, open_state=True):
    ink=C['ink']
    if family == 'door':
        s.rect(cx-39,top,78,65,ink)
        s.rect(cx-31,top+8,62,57,C['floor'] if open_state else C['wall_dark'])
        if not open_state:
            s.rect(cx-4,top+8,8,57,ink)
            s.rect(cx-30,top+30,60,5,ink)
        else:
            s.path(f'M{cx} {top+49}v-25m0 0l-12 12m12-12l12 12', 'none', C['mint_dark'], 5)
    elif family == 'sign':
        s.rect(cx-5,top+27,10,65,'#856E57')
        s.path(f'M{cx-39} {top+4}h76v31h-76z', C['supply'] if open_state else '#AAB2A9', ink, 4)
        s.path(f'M{cx-24} {top+19}h46m0 0l-10-8m10 8l-10 8', 'none', ink, 5)
        if not open_state: s.path(f'M{cx-40} {top+39}l80 40', 'none', C['danger'], 8)
    else:
        s.path(f'M{cx-35} {top+80}l15-80h40l15 80', '#8FADB8' if open_state else '#A4A9A7')
        s.path(f'M{cx} {top+12}v20m0 17v20', 'none', C['paper'], 5)
        if open_state:
            s.path(f'M{cx} {top+4}v-18m0 0l-11 11m11-11l11 11', 'none', ink, 5)
        else:
            s.rect(cx-48,top+30,96,16,C['danger'],ink,3)


def scene_card(s, x, y, name, subtitle, biome):
    s.panel(x,y,420,316,name,subtitle)
    bx,by,w,h=x+12,y+63,396,204
    palette={
        'forest':('#CAE6AA','#65B980'), 'village':('#C9DFAC','#D7AD79'),
        'fortress':('#B5D9DB','#5D9F9D'), 'beach':('#F6DEAA','#77D5D2'),
        'city':('#C5D4D8','#819BA9'), 'dungeon':('#B9B8D1','#777B9A')}
    ground, edge=palette[biome]
    s.rect(bx,by,w,h,ground)
    if biome in ('forest','village','beach'):
        s.path(f'M{bx+155} {by+h}l25-150h43l30 150z', C['floor'] if biome!='village' else '#D7AD79')
    if biome in ('fortress','dungeon'):
        for n in range(5): s.path(f'M{bx} {by+40*n}h{w}', 'none', edge, 2)
        for n in range(1,10): s.path(f'M{bx+40*n} {by}v{h}', 'none', edge, 2)
        s.rect(bx,by,w,20,edge); s.rect(bx,by,22,h,edge); s.rect(bx+w-22,by,22,h,edge)
    elif biome=='forest':
        for px,py in [(15,10),(72,110),(315,14),(342,103)]:
            s.rect(bx+px+10,by+py+22,12,37,'#856E57')
            s.path(f'M{bx+px} {by+py+37}l16-34 17 34z',edge,C['ink'],2)
        for px,py in [(98,44),(260,91),(50,164)]: s.rect(bx+px,by+py,8,8,'#79C98D')
    elif biome=='beach':
        s.rect(bx,by,86,h,'#77D5D2'); s.path(f'M{bx+86} {by}v{h}', 'none','#C8F1E8',10)
        for px,py in [(119,37),(318,79),(72,159)]: s.path(f'M{bx+px} {by+py}l9-5 8 8-7 4z',C['paper'],'#D7B479',2)
    elif biome=='city':
        s.rect(bx,by,99,h,'#7DAFE8'); s.rect(bx+w-99,by,99,h,'#8BC8C1')
        s.rect(bx+109,by,w-218,h,edge)
        for yy in range(22,h,54): s.rect(bx+w/2-3,by+yy,6,26,C['paper'])
        for xx in [24,59,324,359]: s.rect(bx+xx,by+32,19,22,C['paper'])
    elif biome=='village':
        for px in [28,60,316,348]: s.rect(bx+px,by+45,6,45,'#8C755C')
        s.rect(bx+22,by+57,66,5,'#8C755C'); s.rect(bx+307,by+57,66,5,'#8C755C')
        s.rect(bx+31,by+122,41,28,C['supply'],C['ink'],2)
        s.path(f'M{bx+25} {by+122}l27-18 27 18z',C['enemy'],C['ink'],2)
    if biome in ('fortress','dungeon'):
        exit_marker(s,bx+w/2,by+2,'door',True)
    elif biome in ('forest','beach'):
        exit_marker(s,bx+w/2,by+7,'sign',True)
    else:
        exit_marker(s,bx+w/2,by+5,'road',True)
    # Same avatar and enemy color across all environments.
    player(s,bx+145,by+110,1.5,4)
    enemy(s,bx+255,by+117,'infantry',1.55)
    s.text(x+18,y+297,'玩家与敌人颜色不随场景变化',13,400,'#5D7480')


def scenes():
    s=SVG(1400,1100,'六类场景与三类出口原型')
    heading(s,'03 场景与出口原型','环境各有地表、边界和光感；图中同一玩家/敌人在六种地表上保持一致识别')
    for col,row,name,sub,biome in [
        (0,0,'森林外围哨站','浅草 + 树影 / 路牌','forest'),
        (1,0,'乡村补给营地','暖土 + 篱笆 / 马路','village'),
        (2,0,'通信要塞','冷色金属 / 门口','fortress'),
        (0,1,'沙滩海岸','金沙 + 海浪 / 路牌','beach'),
        (1,1,'城市街区','灰蓝街面 / 马路','city'),
        (2,1,'地牢内室','浅紫石砖 / 门口','dungeon')]:
        scene_card(s,40+col*440,120+row*335,name,sub,biome)
    s.panel(40,796,1320,260,'出口状态规范','同一套 E 互动与确认面板；形体不同，阻断 / 开放必须可在无色环境下区分')
    for i,(label,family) in enumerate([('门口','door'),('路牌','sign'),('马路','road')]):
        x=72+i*427
        s.rect(x,858,398,166,C['floor'],'#D7CFB2',1,8)
        exit_marker(s,x+100,882,family,False)
        exit_marker(s,x+300,882,family,True)
        s.text(x+100,1009,'阻断',14,700,anchor='middle')
        s.text(x+300,1009,'开放',14,700,anchor='middle')
        s.text(x+199,1045,label,18,700,anchor='middle')
    s.save('03_scenes.svg')


def effects():
    s=SVG(1400,860,'战斗特效与可读性原型')
    heading(s,'04 战斗特效原型','源像素示意｜双方弹幕用形状 + 颜色双重编码｜预警形状与最终判定一致')
    cards=[
        ('玩家子弹','金黄短尖头 / 深色外缘'),('敌方子弹','珊瑚红圆点 / 深色外缘'),
        ('步兵射击前摇','枪口闪点 + 短线'),('突击兵蓄力','面前短扇形'),
        ('首领三发预警','18° 扇形，发射前显示'),('手雷爆炸','橙黄范围环 / 一次伤害'),
        ('治疗反馈','青绿十字上浮'),('情报上传','蓝色数据片上行'),
        ('玩家受击','亮边 + 短时闪烁')]
    for i,(label,note) in enumerate(cards):
        col,row=i%3,i//3
        x,y=40+col*440,120+row*232
        s.panel(x,y,420,211,label,note)
        cx,cy=x+210,y+132
        s.rect(x+17,y+70,386,124,C['floor'])
        if i==0:
            s.path(f'M{cx-65} {cy+7}l56-17v10l-56 17z',C['gold'],C['ink'],4)
            s.path(f'M{cx+8} {cy-6}l46-13v8l-46 13z',C['gold'],C['ink'],3)
        elif i==1:
            for dx,dy,r in [(-62,10,13),(0,-9,10),(61,15,13)]: s.circle(cx+dx,cy+dy,r,C['danger'],C['ink'],4)
        elif i==2:
            enemy(s,cx-95,cy-52,'infantry',2.4)
            s.path(f'M{cx+10} {cy+5}h89','none',C['danger'],5,'stroke-dasharray="12 8"')
            s.circle(cx+8,cy+5,8,C['danger'],C['ink'],3)
        elif i==3:
            enemy(s,cx-88,cy-50,'assault',2.2)
            s.path(f'M{cx+6} {cy-24}Q{cx+105} {cy-14} {cx+103} {cy+38}L{cx+9} {cy+15}z', '#F7B3A7',C['danger'],3)
        elif i==4:
            s.path(f'M{cx-87} {cy+30}L{cx+75} {cy-28}A172 172 0 0 1 {cx+75} {cy+87}z','#F7B3A7',C['danger'],3)
            for dy in [-16,29,69]: s.circle(cx+68,cy+dy,6,C['danger'],C['ink'],2)
        elif i==5:
            s.circle(cx,cy,50,'none',C['supply'],8)
            s.circle(cx,cy,34,'none',C['danger'],5)
            for dx,dy in [(-44,-24),(33,-39),(48,22),(-25,43)]: s.rect(cx+dx,cy+dy,13,9,C['gold'])
        elif i==6:
            for dx,dy,sc in [(-60,14,1),(0,-13,1.4),(66,23,0.8)]:
                s.group(f'translate({cx+dx} {cy+dy}) scale({sc})',True)
                s.rect(-5,-18,10,36,C['mint']); s.rect(-18,-5,36,10,C['mint']); s.end()
        elif i==7:
            for dx,dy in [(-46,26),(0,-1),(43,-32)]: icon(s,cx+dx,cy+dy,'intel',1.4)
            s.path(f'M{cx+94} {cy+42}v-84m0 0l-12 12m12-12l12 12','none',C['intel'],4)
        else:
            player(s,cx-45,cy-51,3,0)
            s.path(f'M{cx-50} {cy-47}h87v89h-87z','none',C['paper'],5,'stroke-dasharray="13 9"')
            s.text(cx+75,cy+5,'0.6 s',18,700,C['danger'])
    s.save('04_effects.svg')


def label_pill(s,x,y,w,text,fill=C['paper'],color=C['ink']):
    s.rect(x,y,w,35,fill,C['ink'],2,6)
    s.text(x+w/2,y+24,text,15,700,color,'middle')


def ui():
    s=SVG(1400,1080,'HUD、指挥部、商店、结算与地图 UI 原型')
    heading(s,'05 界面原型','画面数值为排版样例；真实数据由游戏状态驱动。功能图标始终配中文名称。')
    s.panel(40,120,1320,230,'战斗 HUD','浅色底板 + 深色文字；避免遮住战斗中心')
    s.rect(61,181,1278,146,'#C9DFAC')
    s.rect(74,193,1252,70,C['paper'],C['ink'],3,8)
    label_pill(s,88,209,170,'✚ 生命 76 / 100','#75D6BE')
    label_pill(s,273,209,214,'手枪  08 / 36')
    label_pill(s,502,209,200,'① 手枪  ② 冲锋枪')
    label_pill(s,718,209,147,'③ 空槽')
    label_pill(s,881,209,109,'◆  物资 38','#F0BB58')
    label_pill(s,1005,209,112,'▣  情报 28','#7DAFE8')
    label_pill(s,1132,209,178,'手雷 × 2')
    s.text(88,301,'外围哨站  /  房间 3 · 6',17,700)
    s.text(987,301,'R 换弹    E 交互    Tab 地图',15,500)

    s.panel(40,370,641,348,'指挥部','菜单式基地；永久情报与本轮资源明确分开')
    s.rect(59,431,603,268,C['paper'],C['ink'],2,8)
    s.text(80,467,'前哨指挥部',25,800)
    s.text(462,467,'永久情报  160',16,700,C['intel'])
    for j,(title,detail) in enumerate([('医疗保障  Lv.1','最大生命 110 → 120   /   70 情报'),('基础武器校准  Lv.0','手枪伤害 10 → 12   /   40 情报'),('前线补给  Lv.0','初始物资 0 → 10   /   40 情报')]):
        yy=488+j*54
        s.rect(77,yy,562,45,'#FFFFFF','#D8D1BE',1,5)
        s.text(88,yy+19,title,16,700)
        s.text(88,yy+37,detail,12,400,'#5D7480')
    label_pill(s,77,663,169,'普通行动',C['mint'])
    label_pill(s,258,663,177,'最终行动  ×1','#7DAFE8')
    label_pill(s,447,663,191,'选择初始武器')

    s.panel(704,370,656,348,'商店 / 武器库','实际效果、价格、库存与领取条件同时出现')
    s.rect(723,431,618,268,C['paper'],C['ink'],2,8)
    s.text(745,468,'补给商店',25,800)
    s.text(1160,468,'本轮物资 38',16,700,'#A4752F')
    for j,(name,detail,price,enabled) in enumerate([('医疗包','立即恢复 25 HP','15',True),('弹药','所选枪 +2 弹匣备弹','10',True),('霰弹枪','满匣 + 初始备弹','35',False)]):
        yy=486+j*59
        s.rect(743,yy,577,51,'#FFFFFF','#D8D1BE',1,5)
        s.text(758,yy+22,name,17,700)
        s.text(881,yy+22,detail,13,400,'#5D7480')
        label_pill(s,1228,yy+8,77,price,C['supply'] if enabled else '#B7BEC0')
    s.text(747,681,'灰色示例：当前物资不足；按 E 打开后暂停战斗',13,400,'#5D7480')

    s.panel(40,739,641,296,'结算 / 失败 / 撤离','原因先行，再列本轮情报与最终资格变化')
    s.rect(59,801,603,215,C['paper'],C['ink'],2,8)
    s.text(81,844,'行动结算 · 普通三关完成',24,800)
    s.text(82,879,'到达：通信要塞出口     击杀：42',17)
    s.text(82,911,'本轮情报：128  +  通关奖励：32  =  160',17,700,C['intel'])
    s.text(82,943,'最终行动资格：0 → 1',17,700)
    label_pill(s,82,963,177,'返回指挥部',C['mint'])

    s.panel(704,739,656,296,'地图 / 暂停提示','地图按住 Tab 展示完整简图；图形先于文字说明')
    s.rect(723,801,618,215,C['paper'],C['ink'],2,8)
    for cx,cy,state in [(809,858,'in'),(897,858,'clear'),(985,858,'fight'),(985,929,'shop'),(1073,858,'exit')]:
        color={'in':C['mint'],'clear':C['wall'],'fight':C['enemy'],'shop':C['supply'],'exit':C['intel']}[state]
        s.rect(cx,cy,59,55,color,C['ink'],3,5)
    for x1,y1,x2,y2 in [(868,885,897,885),(956,885,985,885),(1044,885,1073,885),(1015,913,1015,929)]:
        s.path(f'M{x1} {y1}L{x2} {y2}','none',C['ink'],4)
    s.text(1160,856,'● 当前',14,700,C['mint_dark'])
    s.text(1160,884,'◆ 战斗',14,700,C['enemy'])
    s.text(1160,912,'▣ 商店',14,700,'#A4752F')
    s.text(747,994,'Esc 暂停 / 继续 / 放弃行动',16,700)
    s.save('05_ui.svg')


def menus():
    s=SVG(1400,890,'主菜单、武器库、暂停、设置与剧情面板原型')
    heading(s,'06 菜单与叙事界面','主菜单、武器库、设置、暂停、任务简报与结局；所有按钮都有实际功能')
    blocks=[
        (40,120,'主菜单','清爽标识 + 明确入口'),
        (490,120,'武器库','四项物资分别领取'),
        (940,120,'设置','总音量可调整'),
        (40,500,'暂停','继续或放弃行动'),
        (490,500,'任务简报','短文本 + 出击目标'),
        (940,500,'胜利结局','文本后进入结算')]
    for x,y,title,sub in blocks:
        s.panel(x,y,420,340,title,sub)
        s.rect(x+15,y+67,390,255,C['paper'],C['ink'],2,8)
    # Main menu
    s.text(87,235,'岚谷前哨',36,800)
    s.text(89,263,'GUERRILLA VANGUARD',15,700,C['mint_dark'])
    label_pill(s,86,296,323,'开始行动',C['mint'])
    label_pill(s,86,339,155,'设置')
    label_pill(s,253,339,156,'退出游戏')
    # Armory
    for j,(item,desc) in enumerate([('随机武器','未领取'),('全枪弹药','未领取'),('医疗包','未领取'),('手雷包','未领取')]):
        yy=210+j*54
        s.rect(520,yy,359,44,'#FFFFFF','#D8D1BE',1,5)
        s.text(533,yy+27,item,17,700)
        s.text(784,yy+27,desc,13,500,C['mint_dark'])
    # Settings
    s.text(969,239,'总音量',20,700)
    s.rect(968,266,322,15,'#C5D4D8',C['ink'],2,6)
    s.rect(968,266,240,15,C['mint'],C['ink'],2,6)
    s.circle(1208,273,13,C['paper'],C['ink'],3)
    s.text(969,321,'75%',18,700)
    label_pill(s,968,360,322,'返回')
    # Pause
    s.text(89,620,'行动已暂停',30,800)
    label_pill(s,87,654,322,'继续游戏',C['mint'])
    label_pill(s,87,700,322,'放弃行动并结算')
    s.text(89,789,'局内进度无法在重启后继续',14,400,'#5D7480')
    # Briefing
    s.text(537,619,'外围哨站 · 任务简报',23,800)
    s.text(537,655,'夺取敌方数据，改善指挥部支援能力。',16)
    s.text(537,683,'找到最终空降的行动窗口。',16)
    label_pill(s,536,729,319,'开始普通行动',C['mint'])
    # Ending
    s.text(985,618,'通信网络已切断',24,800)
    s.text(985,657,'敌军失去统一指挥，',16)
    s.text(985,685,'岚谷封锁解除。',16)
    label_pill(s,984,729,319,'查看行动结算',C['intel'])
    s.save('06_menus.svg')


if __name__ == '__main__':
    characters()
    equipment()
    scenes()
    effects()
    ui()
    menus()
