"""构建八个远征关卡的资源、房间、Boss 与原创音频，不覆盖旧主题。

素材源为 imagegen 生成的 4×4 图集；仅做裁切和尺寸打包。
缺失源图时显式记录临时复用资源，方便逻辑验证及后续替换，绝不冒充完成美术。
"""
from pathlib import Path
import argparse
import json
import math
import random
import re
import struct
import wave
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
THEMES = [
    ('OldTown', '老城居民区', '楼城督军', 'Metropolis', 1, (140, 110, 90), 104),
    ('Neon', '霓虹娱乐街', '夜幕双煞', 'Metropolis', 0, (100, 55, 150), 128),
    ('Park', '郊野公园', '灰熊', 'Jungle', 2, (90, 130, 70), 92),
    ('Chemical', '化工厂', '压力主管', 'UndergroundFortress', 3, (160, 155, 70), 112),
    ('Route66', '66号公路', '末路车王', 'Valley', 4, (185, 115, 65), 120),
    ('Swamp', '沼泽湿地', '沉舟', 'Jungle', 2, (75, 105, 80), 84),
    ('Canal', '运河小镇', '闸门长', 'Village', 4, (140, 145, 125), 100),
    ('Hospital', '废弃医院·生化实验室', '零号病人', 'UndergroundFortress', 3, (100, 140, 135), 80),
]


def save(path, content):
    """写入本扩展拥有的文件，统一 UTF-8 与真实换行。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')


def crop_terrain_interior(cell):
    """裁出地形格内最大的实色矩形，避免把图集透明留白重复铺进房间。

    生成图的地形边框和留白不固定，按 alpha 逐行累计直方图寻找矩形，
    不对人物或独立物件执行此步骤。地形内部的轻微半透明统一为不透明。
    """
    alpha = cell.getchannel('A')
    pixels = alpha.load()
    heights = [0] * cell.width
    best_area = 0
    best_box = None
    for y in range(cell.height):
        for x in range(cell.width):
            heights[x] = heights[x] + 1 if pixels[x, y] >= 200 else 0
        # 单调栈在线性时间求当前行向上延伸的最大矩形。
        stack = []
        for x in range(cell.width + 1):
            height = heights[x] if x < cell.width else 0
            start = x
            while stack and stack[-1][1] > height:
                left, previous_height = stack.pop()
                area = (x - left) * previous_height
                if area > best_area:
                    best_area = area
                    best_box = (left, y + 1 - previous_height, x, y + 1)
                start = left
            if height and (not stack or stack[-1][1] < height):
                stack.append((start, height))
    if best_box is None or best_area < cell.width * cell.height * 0.15:
        raise ValueError('terrain cell has no sufficiently large opaque interior')
    tile = cell.crop(best_box)
    tile.putalpha(255)
    return tile


def package_art(name, fallback, column):
    """切分生成图集；没有源图则返回明确的旧素材引用和临时状态。"""
    source = ROOT / f'docs/expedition/source/{name}.png'
    folder = ROOT / f'Assets/Art/MilitaryArcade/Expedition/{name}'
    folder.mkdir(parents=True, exist_ok=True)
    if not source.exists():
        terrain = {kind: f'res://Assets/Art/MilitaryArcade/World/Terrain/{fallback}/{kind}.png'
                   for kind in ['ground', 'wall', 'water', 'box', 'cover', 'decoration']}
        terrain['entrance'] = 'res://Assets/Art/MilitaryArcade/World/entrance.png'
        # 单张素材成功时也能独立接入；完整图集未到齐时继续保留临时状态。
        for kind in terrain:
            individual = ROOT / f'docs/expedition/source/{name}_{kind}.png'
            if not individual.exists():
                continue
            size = (64, 64) if kind in ['ground', 'wall', 'water'] else ((64, 32) if kind == 'cover' else (48, 48))
            Image.open(individual).convert('RGBA').resize(size, Image.Resampling.LANCZOS).save(folder / f'{kind}.png')
            terrain[kind] = f'res://Assets/Art/MilitaryArcade/Expedition/{name}/{kind}.png'
        # AtlasTexture 保留已有透明度和四方向，不改写已有图片。
        atlas = f'''[gd_resource type="AtlasTexture" load_steps=2 format=3]
[ext_resource type="Texture2D" path="res://Assets/Art/MilitaryArcade/Bosses/tactical_boss_atlas.png" id="art"]
[resource]
atlas = ExtResource("art")
region = Rect2({column * 280}, 0, 280, 1120)
'''
        save(folder / 'boss.tres', atlas)
        return terrain, f'res://Assets/Art/MilitaryArcade/Expedition/{name}/boss.tres', True
    image = Image.open(source).convert('RGBA')
    # 验证真正透明的方形图集，拒绝把缺失透明度或错误网格标成正式资源。
    if image.width != image.height or image.width < 512:
        raise ValueError(f'{source}: expected a square atlas large enough for four cells per row')
    if image.getchannel('A').getextrema() != (0, 255):
        raise ValueError(f'{source}: atlas must preserve opaque terrain and transparent sprite backgrounds')
    # 内置服务可能返回 1254 等非四倍数尺寸，按比例取边界覆盖完整源图。
    columns = [round(index * image.width / 4) for index in range(5)]
    rows = [round(index * image.height / 4) for index in range(5)]
    for index, kind in enumerate(['ground', 'wall', 'water', 'box', 'cover', 'decoration', 'entrance', 'prop']):
        x, y = index % 4, index // 4
        size = (64, 64) if index < 3 else ((64, 32) if kind == 'cover' else (48, 48))
        cell = image.crop((columns[x], rows[y], columns[x + 1], rows[y + 1]))
        if index < 3:
            cell = crop_terrain_interior(cell)
        cell.resize(size, Image.Resampling.LANCZOS).save(folder / f'{kind}.png')
    for row, kind in [(2, 'boss'), (3, 'companion')]:
        image.crop((0, rows[row], image.width, rows[row + 1])).resize((1024, 256), Image.Resampling.LANCZOS).save(folder / f'{kind}.png')
    terrain = {kind: f'res://Assets/Art/MilitaryArcade/Expedition/{name}/{kind}.png'
               for kind in ['ground', 'wall', 'water', 'box', 'cover', 'decoration', 'entrance', 'prop']}
    return terrain, f'res://Assets/Art/MilitaryArcade/Expedition/{name}/boss.png', False


def build_theme(index, spec):
    """每主题建立十八个尺寸模板、独立关卡入口及手工布局的 Boss 房。"""
    name, title, boss_title, fallback, column, palette, bpm = spec
    terrain, boss_art, provisional = package_art(name, fallback, column)
    root = f'res://Scene/Level{name}'
    refs = ['[ext_resource type="Script" path="res://Script/Level/battlefield_theme.gd" id="script"]']
    for kind, path in terrain.items():
        refs.append(f'[ext_resource type="Texture2D" path="{path}" id="{kind}"]')
    refs += [f'[ext_resource type="PackedScene" path="res://Prefab/BossExpedition/{name}.tscn" id="boss"]',
             f'[ext_resource type="PackedScene" path="res://Scene/BossRooms/{name}.tscn" id="arena"]',
             f'[ext_resource type="AudioStream" path="res://Assets/Audio/Music/expedition_{name}.wav" id="music"]']
    assignments = '\n'.join(f'{kind}_texture = ExtResource("{kind}")' for kind in terrain)
    save(ROOT / f'Scene/Level{name}/theme.tres', f'''[gd_resource type="Resource" script_class="BattlefieldTheme" load_steps={len(refs)+1} format=3]
{chr(10).join(refs)}
[resource]
script = ExtResource("script")
display_name = "{title}"
room_template_root = "{root}"
{assignments}
secondary_style_tint = Color(0.93, 0.95, 0.94, 1)
cover_count = 2
cover_size = Vector2(64, 32)
boss_scene = ExtResource("boss")
boss_room_scene = ExtResource("arena")
background_music = ExtResource("music")
''')
    for width in range(1, 4):
        for height in range(1, 4):
            for style in (1, 2):
                room = f'Room_{width}x{height}_{style:02}'
                save(ROOT / f'Scene/Level{name}/{room}/{room}.tscn', f'''[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://Scene/LevelFortress/room_template.gd" id="script"]
[ext_resource type="Resource" path="{root}/theme.tres" id="theme"]
[node name="{room}" type="Node2D"]
script = ExtResource("script")
room_size_units = Vector2i({width}, {height})
room_style_index = {style}
populate_on_first_entry = true
battlefield_theme = ExtResource("theme")
''')
    # 入口沿用玩家、HUD 和镜头资源，F6 不依赖正式对局抽取命中新主题。
    save(ROOT / f'Scene/Level{name}/{name}Level.tscn', f'''[gd_scene load_steps=6 format=3]
[ext_resource type="Script" path="res://Scene/LevelFortress/fortress_level_controller.gd" id="script"]
[ext_resource type="PackedScene" path="res://Prefab/Player/player.tscn" id="player"]
[ext_resource type="PackedScene" path="res://Prefab/Camera/follow_camera.tscn" id="camera"]
[ext_resource type="PackedScene" path="res://Scene/UI/HUD/HUD.tscn" id="hud"]
[ext_resource type="Resource" path="{root}/theme.tres" id="theme"]
[node name="{name}Level" type="Node2D"]
script = ExtResource("script")
player_path = NodePath("Player")
hud_path = NodePath("HUD")
camera_path = NodePath("FollowCamera")
battlefield_theme = ExtResource("theme")
[node name="Player" parent="." instance=ExtResource("player")]
[node name="FollowCamera" parent="." instance=ExtResource("camera")]
zoom = Vector2(2, 2)
target_path = NodePath("../Player")
[node name="HUD" parent="." instance=ExtResource("hud")]
''')
    companion = boss_art if provisional else f'res://Assets/Art/MilitaryArcade/Expedition/{name}/companion.png'
    scale = 0.34 if index in [4, 5, 7] else 0.24
    save(ROOT / f'Prefab/BossExpedition/{name}.tscn', f'''[gd_scene load_steps=8 format=3]
[ext_resource type="Script" path="res://Prefab/BossExpedition/expedition_boss.gd" id="boss"]
[ext_resource type="Texture2D" path="{boss_art}" id="art"]
[ext_resource type="Texture2D" path="{companion}" id="companion"]
[ext_resource type="Script" path="res://Script/Component/health_component.gd" id="health"]
[ext_resource type="Script" path="res://Script/Component/hurt_box.gd" id="hurt"]
[sub_resource type="CircleShape2D" id="body"]
radius = {24 if index in [4,5,7] else 12}.0
[sub_resource type="CircleShape2D" id="hurt_shape"]
radius = {28 if index in [4,5,7] else 18}.0
[node name="{name}Boss" type="CharacterBody2D" groups=["enemies"]]
collision_layer = 0
script = ExtResource("boss")
encounter = {index}
audio_key = "{name}"
boss_display_name = "{boss_title}"
first_health = {160 if index in [4,5,7] else 120}
second_health = {130 if index in [4,5,7] else 100}
third_health = {100 if index in [4,5,7] else 80}
move_speed = {45 if index in [4,5,7] else 55}.0
companion_art = ExtResource("companion")
survivor_art = ExtResource("companion")
[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("body")
[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("art")
scale = Vector2({scale}, {scale})
hframes = {1 if provisional else 4}
vframes = {4 if provisional else 1}
[node name="Health" type="Node" parent="."]
script = ExtResource("health")
[node name="HurtBox" type="Area2D" parent="."]
collision_layer = 2
collision_mask = 4
script = ExtResource("hurt")
[node name="CollisionShape2D" type="CollisionShape2D" parent="HurtBox"]
shape = SubResource("hurt_shape")
''')
    # 完整图集的第八格是独立场景物件；缺图时继续使用该主题的已有装饰。
    arena_prop = terrain.get('prop', terrain['decoration'])
    arena = ['[gd_scene load_steps=6 format=3]',
             '[ext_resource type="Script" path="res://Scene/LevelFortress/room_template.gd" id="room"]',
             f'[ext_resource type="Texture2D" path="{terrain["cover"]}" id="cover"]',
             f'[ext_resource type="Texture2D" path="{terrain["decoration"]}" id="decoration"]',
             f'[ext_resource type="Texture2D" path="{arena_prop}" id="prop"]',
             '[sub_resource type="RectangleShape2D" id="shape"]\nsize = Vector2(64, 32)',
             f'[node name="{name}Arena" type="Node2D"]\nscript = ExtResource("room")\nroom_size_units = Vector2i(2, 2)\nroom_type = "boss"\npopulate_on_first_entry = false',
             '[node name="BossSpawn" type="Marker2D" parent="."]\nposition = Vector2(0, -100)']
    layouts = [ [(-240,-190),(240,-190),(-240,190),(240,190)], [(-280,0),(280,0)],
                [(-220,-220),(220,220)], [(-260,-180),(260,180)],
                [(-300,-220),(300,220)], [(-250,-220),(250,-220),(-250,220)],
                [(-310,-180),(310,-180),(-310,180),(310,180)], [(-260,-220),(260,-220),(-260,220),(260,220)] ]
    for i, (x,y) in enumerate(layouts[index]):
        arena += [f'[node name="Cover{i}" type="StaticBody2D" parent="."]\nposition = Vector2({x}, {y})\ncollision_layer = 8\ncollision_mask = 0',
                  f'[node name="Shape" type="CollisionShape2D" parent="Cover{i}"]\nshape = SubResource("shape")',
                  f'[node name="Art" type="Sprite2D" parent="Cover{i}"]\ntexture = ExtResource("cover")\ntexture_repeat = 2\nregion_enabled = true\nregion_rect = Rect2(0, 0, 64, 32)']
    for i, (x,y) in enumerate([(-380,-340),(380,-340),(-380,340),(380,340)]):
        # 四角交替使用两种物件，保持手工竞技场布局和通道宽度。
        art_id = 'prop' if i % 2 else 'decoration'
        arena += [f'[node name="Prop{i}" type="Sprite2D" parent="."]\nposition = Vector2({x}, {y})\ntexture = ExtResource("{art_id}")']
    save(ROOT / f'Scene/BossRooms/{name}.tscn', '\n\n'.join(arena)+'\n')
    completed = [kind for kind, path in terrain.items() if '/Expedition/' in path]
    if not provisional:
        completed += ['boss', 'companion']
    return {'id': name, 'title': title, 'boss': boss_title, 'art_provisional': provisional, 'completed_art': completed, 'bpm': bpm}


def write_wave(path, samples, rate=22050):
    """输出单声道 16 位 PCM；限幅避免削波，不引用外部录音。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as output:
        output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        output.writeframes(b''.join(struct.pack('<h', int(max(-.9, min(.9, value)) * 32767)) for value in samples))


def build_audio(index, spec):
    """主题专属五种状态音效与八小节循环配乐，固定种子便于复现。"""
    name, _, _, _, _, _, bpm = spec
    rate = 22050
    rng = random.Random(20261010 + index)
    for sound, duration in [('intro', .9), ('warning', .65), ('attack', .35), ('recover', .45), ('phase', 1.1)]:
        base = [150, 500, 240, 90, 75, 110, 170, 65][index]
        if sound == 'warning':
            base = 620 + index * 75
        values = []
        for sample in range(int(duration * rate)):
            t = sample / rate
            envelope = min(1, t/.01, (duration-t)/.05)
            tonal = math.sin(math.tau * (base*t + (45*t*t if sound in ['phase','intro'] else 0)))
            noise = rng.uniform(-1,1) * (.3 if sound == 'attack' else .08)
            pulse = .65 + .35*math.sin(math.tau*(4+index)*t)
            values.append((tonal*.3+noise)*envelope*pulse)
        write_wave(ROOT / f'Assets/Audio/SFX/Expedition/{name}/{sound}.wav', values)
    # 八小节整数周期音符与包络让循环两端连续；各主题音阶、速度和节奏独立。
    duration = 32 * 60 / bpm
    frames = round(duration*rate)
    notes = [0,3,7,10,7,5,3,0] if index % 2 == 0 else [0,2,7,9,5,2,3,0]
    root = [110,123.47,98,82.41,146.83,73.42,130.81,65.41][index]
    values=[]
    for sample in range(frames):
        cycle = sample/frames
        beat = cycle*32
        phase = beat%1
        frequency = root * 2**(notes[int(beat)%8]/12)
        t=sample/rate
        envelope=math.sin(math.pi*phase)**2
        melody=math.sin(math.tau*frequency*t)*.13*envelope
        bass=math.sin(math.tau*(root/2)*t)*.07*math.exp(-phase*7)
        drum=math.sin(math.tau*52*t)*.12*math.exp(-phase*25)
        # 环境底色由整数周期组成，文件首尾不出现环境层跳变。
        ambient=.018*math.sin(math.tau*cycle*(index+2))*math.sin(math.tau*cycle*300)
        edge=min(1, phase/.015, (1-phase)/.015)
        values.append((melody+bass+drum)*edge+ambient)
    write_wave(ROOT / f'Assets/Audio/Music/expedition_{name}.wav', values)


def register_pool():
    """追加正式抽取池条目，保留原七主题的顺序和引用，重复执行不重复追加。"""
    path = ROOT / 'Script/Level/run_level_pool.tres'
    text = path.read_text()
    for name, *_ in THEMES:
        id = 'expedition_'+name
        if f'id="{id}"' in text:
            continue
        text = text.replace('\n[resource]', f'\n[ext_resource type="Resource" path="res://Scene/Level{name}/theme.tres" id="{id}"]\n\n[resource]')
        text = text.replace('])\n', f', ExtResource("{id}")])\n')
    count = text.count('[ext_resource') + 1
    text = re.sub(r'load_steps=\d+', f'load_steps={count}', text, count=1)
    save(path, text)


def main():
    """仅管理本扩展文件；美术接入可跳过已验收音频，避免无关资源重新生成。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--art-only', action='store_true', help='package art and scene references without rebuilding audio')
    args = parser.parse_args()
    manifest=[]
    for index, spec in enumerate(THEMES):
        manifest.append(build_theme(index,spec))
        if not args.art_only:
            build_audio(index,spec)
        print('Built',spec[0],flush=True)
    register_pool()
    save(ROOT / 'docs/expedition/assets.json', json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')


if __name__ == '__main__':
    main()
