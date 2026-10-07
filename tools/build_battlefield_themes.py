"""生成六类可编辑关卡主题、像素风 SVG 贴图和房间模板。

只管理本次新增主题目录；不修改既有 Fortress 和玩家素材。
SVG 使用整数坐标和 crispEdges，便于替换贴图并保持小尺寸像素风。
"""

from pathlib import Path
import random


ROOT = Path(__file__).resolve().parents[1]
THEMES = [
    ("Jungle", "丛林", "#809463", "#9aa879", "#627b4e", "#354d35", "#597346", "#457e78", "#6fada1", "#a58a4e", "#cbb36d", (64, 24), "fern"),
    ("Village", "村庄", "#bba47b", "#cbb994", "#967f5d", "#5b4538", "#9c7350", "#527b87", "#7da4ae", "#af8856", "#dab57a", (64, 32), "wheat"),
    ("Valley", "山谷", "#ada084", "#c1b396", "#93856f", "#515c57", "#7a8274", "#407e92", "#6da9b2", "#ae885c", "#d1b183", (80, 32), "rock"),
    ("Metropolis", "都市", "#889293", "#a6afb0", "#727d80", "#3f515b", "#75858b", "#47667a", "#789eaf", "#687d7e", "#a1b4ad", (72, 24), "lamp"),
    ("UndergroundFortress", "地下要塞", "#82858e", "#a0a4ae", "#666b76", "#303e4c", "#566573", "#477f82", "#72aba3", "#6c7c65", "#a5ac7c", (64, 40), "vent"),
    ("MineShaft", "矿井", "#a28c74", "#b9a188", "#816c57", "#49453f", "#796955", "#4b7480", "#78a6b1", "#99764c", "#c2a16e", (64, 32), "ore"),
]


def rectangle(x, y, width, height, color):
    """以整像素矩形构造贴图细节，避免矢量边缘缩放后出现模糊轮廓。"""
    return f'<rect x="{x}" y="{y}" width="{width}" height="{height}" fill="{color}"/>'


def svg(parts, size=24):
    """输出固定逻辑尺寸的 Godot 原生 SVG 纹理；重复平铺不会改变世界单位。"""
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}" shape-rendering="crispEdges">\n' + "\n".join(parts) + "\n</svg>\n"


def make_textures(theme, stage):
    """为每类地形绘制专用图案，地面保持低对比，阻挡物使用深色轮廓。"""
    name, _, ground, light, shade, dark, wall, water, foam, crate, crate_light, _, decoration = theme
    rng = random.Random(stage)
    parts = [rectangle(0, 0, 24, 24, ground)]
    for _ in range(12):
        parts.append(rectangle(rng.randrange(24), rng.randrange(24), 2, 1, rng.choice([light, shade])))
    if name in ("Metropolis", "UndergroundFortress"):
        parts.extend([rectangle(0, 23, 24, 1, shade), rectangle(23, 0, 1, 24, shade), rectangle(2, 2, 1, 1, light)])
    result = {"ground": svg(parts)}

    parts = [rectangle(0, 0, 24, 24, dark)]
    if name == "Jungle":
        for x, y in [(1, 2), (11, 1), (5, 12), (16, 11)]:
            parts.extend([rectangle(x, y, 8, 9, wall), rectangle(x + 1, y + 1, 4, 3, shade)])
    elif name == "Village":
        for x in (2, 10, 18):
            parts.extend([rectangle(x, 1, 5, 22, wall), rectangle(x + 1, 1, 1, 22, crate_light)])
        parts.extend([rectangle(0, 6, 24, 3, crate), rectangle(0, 17, 24, 3, crate)])
    elif name == "MineShaft":
        for x, y in [(1, 2), (12, 2), (5, 12)]:
            parts.extend([rectangle(x, y, 9, 8, wall), rectangle(x + 1, y, 6, 2, shade)])
        parts.extend([rectangle(0, 0, 4, 24, crate), rectangle(0, 0, 1, 24, crate_light)])
    else:
        for x, y, width in [(1, 1, 10), (13, 1, 10), (0, 13, 6), (8, 13, 14)]:
            parts.extend([rectangle(x, y, width, 10, wall), rectangle(x, y, width, 2, light)])
    result["wall"] = svg(parts)
    parts = [rectangle(0, 0, 24, 24, water)]
    for x, y in [(1, 4), (14, 9), (5, 17)]:
        parts.extend([rectangle(x, y, 6, 1, foam), rectangle(x + 1, y + 2, 3, 1, dark)])
    result["water"] = svg(parts)

    # 箱体保持 16×16，与复用的碰撞预制体一致；改变外观不改变伤害与掉落判定。
    parts = [rectangle(0, 0, 16, 16, dark), rectangle(1, 1, 14, 14, crate), rectangle(2, 2, 12, 2, crate_light)]
    parts.extend([rectangle(2, 4, 2, 9, crate_light), rectangle(12, 4, 2, 9, crate_light), rectangle(4, 11, 8, 2, dark), rectangle(6, 6, 4, 3, crate_light)])
    result["box"] = svg(parts, 16)

    parts = [rectangle(10, 11, 4, 12, dark), rectangle(11, 11, 2, 11, crate), rectangle(2, 4, 20, 10, dark), rectangle(3, 5, 18, 8, crate)]
    # 小路牌向北；房间根据实际出口方向旋转，箭头无需额外方向素材。
    parts.append('<path d="M10 12V9H7L12 5L17 9H14V12Z" fill="#f1d386"/>')
    result["entrance"] = svg(parts)

    parts = [rectangle(0, 0, 24, 24, dark), rectangle(1, 1, 22, 22, crate)]
    if name == "Metropolis":
        parts.append(rectangle(1, 3, 22, 17, "#bf8759"))
        for x in (-5, 7, 19):
            parts.append(f'<path d="M{x} 20L{x+8} 3H{x+13}L{x+5} 20Z" fill="#decba0"/>')
    elif name == "UndergroundFortress":
        parts.extend([rectangle(2, 3, 20, 18, wall), rectangle(4, 5, 9, 7, foam), rectangle(16, 5, 3, 3, "#e3ad6a")])
        for y in (15, 18):
            parts.append(rectangle(4, y, 15, 1, dark))
    elif name == "Valley":
        parts.extend([rectangle(2, 3, 12, 11, wall), rectangle(11, 11, 11, 11, wall), rectangle(3, 3, 9, 3, light)])
    elif name == "Jungle":
        parts.extend([rectangle(0, 4, 24, 16, wall), rectangle(0, 6, 24, 3, crate_light), rectangle(0, 16, 24, 2, dark)])
    else:
        for y in (4, 11, 18):
            parts.extend([rectangle(1, y, 22, 2, crate_light), rectangle(1, y + 3, 22, 1, dark)])
    result["cover"] = svg(parts)

    parts = []
    if decoration in ("fern", "wheat"):
        leaf = wall if decoration == "fern" else crate_light
        parts.extend([rectangle(11, 4, 2, 18, dark), rectangle(6, 9, 6, 3, leaf), rectangle(13, 5, 5, 3, leaf), rectangle(3, 15, 9, 3, leaf), rectangle(13, 12, 8, 3, leaf)])
    elif decoration == "rock":
        parts.extend([rectangle(4, 12, 16, 9, dark), rectangle(6, 9, 12, 10, wall), rectangle(7, 10, 8, 3, light), rectangle(2, 21, 5, 2, shade)])
    elif decoration == "lamp":
        parts.extend([rectangle(10, 5, 4, 18, dark), rectangle(5, 1, 14, 7, dark), rectangle(7, 2, 10, 4, "#e8d193"), rectangle(7, 21, 10, 3, wall)])
    elif decoration == "vent":
        parts.extend([rectangle(2, 5, 20, 16, dark), rectangle(3, 6, 18, 14, wall)])
        for y in (8, 11, 14, 17):
            parts.append(rectangle(5, y, 14, 1, dark))
    else:
        parts.extend([rectangle(3, 14, 19, 8, dark), rectangle(6, 10, 5, 10, foam), rectangle(13, 7, 5, 13, water), rectangle(7, 11, 2, 5, "#b4ccba")])
    result["decoration"] = svg(parts)
    return result


def write_theme(theme, stage):
    """生成独立主题资源和十八个房间场景，两个样式保留不同色调和内容种子。"""
    name, display_name, *unused = theme
    directory = ROOT / "Scene" / f"Level{name}"
    terrain = directory / "Terrain"
    terrain.mkdir(parents=True, exist_ok=True)
    textures = make_textures(theme, stage)
    for kind, source in textures.items():
        (terrain / f"{kind}.svg").write_text(source)
    resource_root = f"res://Scene/Level{name}"
    entries = ['[gd_resource type="Resource" script_class="BattlefieldTheme" load_steps=9 format=3]', '', '[ext_resource type="Script" path="res://Script/Level/battlefield_theme.gd" id="1_theme"]']
    for index, kind in enumerate(textures, 2):
        entries.append(f'[ext_resource type="Texture2D" path="{resource_root}/Terrain/{kind}.svg" id="{index}_{kind}"]')
    entries.extend(['', '[resource]', 'script = ExtResource("1_theme")', f'display_name = "{display_name}"', f'room_template_root = "{resource_root}"'])
    for index, kind in enumerate(textures, 2):
        entries.append(f'{kind}_texture = ExtResource("{index}_{kind}")')
    size = theme[-2]
    entries.extend(['secondary_style_tint = Color(0.92, 0.94, 0.9, 1)', 'cover_count = 1', f'cover_size = Vector2({size[0]}, {size[1]})'])
    (directory / "theme.tres").write_text("\n".join(entries) + "\n")
    for width in range(1, 4):
        for height in range(1, 4):
            for style in (1, 2):
                room_name = f"Room_{width}x{height}_{style:02}"
                room_dir = directory / room_name
                room_dir.mkdir(exist_ok=True)
                text = f'''[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://Scene/LevelFortress/room_template.gd" id="1_room"]
[ext_resource type="Resource" path="{resource_root}/theme.tres" id="2_theme"]

[node name="{room_name}" type="Node2D"]
script = ExtResource("1_room")
room_size_units = Vector2i({width}, {height})
room_style_index = {style}
populate_on_first_entry = true
battlefield_theme = ExtResource("2_theme")
'''
                (room_dir / f"{room_name}.tscn").write_text(text)
    # 六个入口都具有玩家、HUD、摄像机和同一有序主题列表，可直接运行中间关卡。
    text = f'''[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://Scene/LevelFortress/fortress_level_controller.gd" id="1_controller"]
[ext_resource type="PackedScene" path="res://Prefab/Player/player.tscn" id="2_player"]
[ext_resource type="PackedScene" path="res://Prefab/Camera/follow_camera.tscn" id="3_camera"]
[ext_resource type="PackedScene" path="res://Scene/UI/HUD/HUD.tscn" id="4_hud"]
[ext_resource type="Resource" path="{resource_root}/theme.tres" id="5_theme"]
[ext_resource type="Resource" path="res://Script/Level/themed_campaign.tres" id="6_campaign"]

[node name="{name}Level" type="Node2D"]
script = ExtResource("1_controller")
player_path = NodePath("Player")
hud_path = NodePath("HUD")
camera_path = NodePath("FollowCamera")
level_number = {stage}
battlefield_theme = ExtResource("5_theme")
campaign = ExtResource("6_campaign")

[node name="Player" parent="." instance=ExtResource("2_player")]

[node name="FollowCamera" parent="." instance=ExtResource("3_camera")]
zoom = Vector2(2, 2)
target_path = NodePath("../Player")

[node name="HUD" parent="." instance=ExtResource("4_hud")]
'''
    (directory / f"{name}Level.tscn").write_text(text)


def write_campaign():
    """把主题推进顺序集中在一个 Resource 中，避免关卡脚本硬编码主题目录。"""
    entries = ['[gd_resource type="Resource" script_class="BattlefieldCampaign" load_steps=9 format=3]', '', '[ext_resource type="Script" path="res://Script/Level/battlefield_campaign.gd" id="1_campaign"]', '[ext_resource type="Script" path="res://Script/Level/battlefield_theme.gd" id="2_theme_type"]']
    for index, theme in enumerate(THEMES, 3):
        entries.append(f'[ext_resource type="Resource" path="res://Scene/Level{theme[0]}/theme.tres" id="{index}_theme"]')
    refs = ', '.join(f'ExtResource("{index}_theme")' for index in range(3, 9))
    entries.extend(['', '[resource]', 'script = ExtResource("1_campaign")', f'themes = Array[ExtResource("2_theme_type")]([{refs}])'])
    (ROOT / 'Script/Level/themed_campaign.tres').write_text('\n'.join(entries) + '\n')


def main():
    """生成主题资源；所有像素图案都有固定种子，重复运行可以复现同一批素材。"""
    for stage, theme in enumerate(THEMES, 1):
        write_theme(theme, stage)
    write_campaign()
    print('Generated 6 level scenes, 108 room templates, 6 themes, 42 SVG textures and one campaign.')


if __name__ == '__main__':
    main()
