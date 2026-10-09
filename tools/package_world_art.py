"""打包军事街机世界素材：只裁切生成图、等比缩放和排列，不绘制替代美术。

保留 source 原图与完整提示词清单，旧贴图不覆盖。坐标针对本次选定图集；
角色方向沿用玩家的八方向顺序，显示尺寸与碰撞/房间世界单位分开管理。
"""
from pathlib import Path
from PIL import Image
from package_military_art import sprite_from_cell

ROOT = Path(__file__).resolve().parents[1] / 'Assets/Art/MilitaryArcade/World'
THEMES = ['Fortress', 'Jungle', 'Village', 'Valley', 'Metropolis', 'UndergroundFortress', 'MineShaft']
COVER_SIZES = [(64, 32), (64, 24), (64, 32), (80, 32), (72, 24), (64, 40), (64, 32)]


def character_sheet(name, columns, rows, cell_size, cuts=None):
    """按实际行列的透明间隙裁切角色，保持全身比例，排列成 Godot 的固定动画格。"""
    source = Image.open(ROOT / 'source' / f'{name}.png')
    atlas = Image.new('RGBA', (columns * cell_size[0], rows * cell_size[1]))
    for row in range(rows):
        for col in range(columns):
            if cuts:
                xs, ys = cuts
                box = (xs[col], ys[row], xs[col + 1], ys[row + 1])
            else:
                box = (round(col * source.width / columns), round(row * source.height / rows),
                       round((col + 1) * source.width / columns), round((row + 1) * source.height / rows))
            atlas.alpha_composite(sprite_from_cell(source, box, cell_size), (col * cell_size[0], row * cell_size[1]))
    atlas.save(ROOT / f'{name}_atlas.png')


def surface_tile(cell, size):
    """从不透明表面取方形纹理，输出完整覆盖地面的平铺图，不把透明留白当作地面。"""
    alpha = cell.getchannel('A').point(lambda a: 255 if a > 200 else 0)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError('地形表面没有有效像素')
    left, top, right, bottom = bounds
    edge = min(right - left, bottom - top)
    x = left + (right - left - edge) // 2
    y = top + (bottom - top - edge) // 2
    return cell.crop((x, y, x + edge, y + edge)).convert('RGB').resize((size, size), Image.Resampling.NEAREST)


def package_effects():
    """保留爆炸、火焰的四帧顺序，并输出独立飞行投掷物和通用房间道具。"""
    source = Image.open(ROOT / 'source/effects.png')
    xs = [0, 350, 720, 1090, source.width]
    ys = [0, 312, 580, 826, source.height]
    for row, name in enumerate(['explosion', 'burning']):
        atlas = Image.new('RGBA', (256, 64))
        for col in range(4):
            frame = sprite_from_cell(source, (xs[col], ys[row], xs[col + 1], ys[row + 1]), (64, 64))
            atlas.alpha_composite(frame, (col * 64, 0))
        atlas.save(ROOT / f'{name}_atlas.png')
    names = ['grenade_flight', 'molotov_flight', 'shell_flight', 'enemy_bullet', 'crate', 'entrance', 'sandbags', 'crater']
    sizes = [(64, 64)] * 4 + [(16, 16), (24, 24), (64, 32), (32, 24)]
    for index, (name, size) in enumerate(zip(names, sizes)):
        row, col = 2 + index // 4, index % 4
        sprite_from_cell(source, (xs[col], ys[row], xs[col + 1], ys[row + 1]), size).save(ROOT / f'{name}.png')


def package_visible_bullets():
    """裁切高对比普通弹：上行为玩家黄白、下行为敌方红白，保留生成图的透明边缘。"""
    source_path = ROOT / 'source/bullets_visible.png'
    if not source_path.exists():
        return
    source = Image.open(source_path)
    # 每张图打包为64×32；游戏显示约12×6世界像素，只放大外观，不改变命中半径。
    for row, name in enumerate(['player_bullet_visible', 'enemy_bullet_visible']):
        box = (0, round(row * source.height / 2), source.width, round((row + 1) * source.height / 2))
        sprite_from_cell(source, box, (64, 32)).save(ROOT / f'{name}.png')


def package_round_bullets():
    """裁切圆形普通弹，统一使用正方形透明画布，方向变化时轮廓不会改变。"""
    source_path = ROOT / 'source/bullets_round.png'
    if not source_path.exists():
        return
    source = Image.open(source_path)
    # 64×64画布只控制图片精度；游戏中的圆形碰撞仍由原有 bullet_size 配置决定。
    for row, name in enumerate(['player_bullet_round', 'enemy_bullet_round']):
        box = (0, round(row * source.height / 2), source.width, round((row + 1) * source.height / 2))
        sprite_from_cell(source, box, (64, 64)).save(ROOT / f'{name}.png')


def package_terrain():
    """七种关卡各自使用独立地面、墙、水和摆件；箱子与出口保留原世界尺寸。"""
    for theme, cover_size in zip(THEMES, COVER_SIZES):
        source = Image.open(ROOT / 'source' / f'{theme}.png')
        target = ROOT / 'Terrain' / theme
        target.mkdir(parents=True, exist_ok=True)
        for col, (name, size) in enumerate([('ground', 64), ('wall', 32), ('water', 64)]):
            box = (col * 512, 0, (col + 1) * 512, 512)
            surface_tile(source.crop(box), size).save(target / f'{name}.png')
        for col, (name, size) in enumerate([('box', (16, 16)), ('cover', cover_size), ('decoration', (24, 32))]):
            sprite_from_cell(source, (col * 512, 512, (col + 1) * 512, 1024), size).save(target / f'{name}.png')
    # TestLevel 的 TileMap 地砖固定16像素，单独生成适配图，正式房间使用64像素纹理。
    Image.open(ROOT / 'Terrain/Fortress/ground.png').resize((16, 16), Image.Resampling.NEAREST).save(ROOT / 'Terrain/Fortress/ground_test_tile.png')


def main():
    """打包已生成的世界资源，供场景引用；不修改房间、敌人或武器参数。"""
    character_sheet('enemy', 3, 8, (96, 80), ([160, 440, 700, 970], [0, 194, 380, 582, 770, 951, 1122, 1282, 1448]))
    if (ROOT / 'source/boss.png').exists():
        character_sheet('boss', 2, 8, (96, 96))
    package_effects()
    package_visible_bullets()
    package_round_bullets()
    package_terrain()


if __name__ == '__main__':
    main()
