"""切分 imagegen 的原始透明图集并按游戏使用尺寸打包；不覆盖旧资源。

原始生成图保持在 source 中，坐标对应已选定版本；只裁切、等比缩放与排版，
不重新绘制角色。运行本脚本需要 Pillow，输出统一归入 MilitaryArcade。
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / 'Assets/Art/MilitaryArcade'


def sprite_from_cell(image, box, size):
    """裁出一格有效主体，保持透明边缘和宽高比，再居中放入目标画布。"""
    cell = image.crop(box).convert('RGBA')
    bounds = cell.getchannel('A').point(lambda a: 255 if a > 64 else 0).getbbox()
    if bounds is None:
        raise ValueError(f'素材格为空：{box}')
    cell = cell.crop(bounds)
    cell.thumbnail((size[0] - 4, size[1] - 4), Image.Resampling.NEAREST)
    output = Image.new('RGBA', size)
    output.alpha_composite(cell, ((size[0] - cell.width) // 2, (size[1] - cell.height) // 2))
    return output


def main():
    """生成 24 帧八方向玩家图集、16 个独立图标和可重复打包的 UI 面板。"""
    hero = Image.open(ROOT / 'source/player_sheet.png')
    xs = [(278, 424), (474, 612), (662, 809)]
    ys = [(18, 187), (187, 358), (358, 528), (528, 705), (705, 884), (884, 1059), (1059, 1233), (1233, 1411)]
    # 瞄准动作的枪管更长，增加格宽但保持人物高度及显示缩放，避免横向举枪时整体缩小。
    atlas = Image.new('RGBA', (288, 640))
    for row, (top, bottom) in enumerate(ys):
        for col, (left, right) in enumerate(xs):
            frame = sprite_from_cell(hero, (left, top, right, bottom), (64, 80))
            atlas.alpha_composite(frame, (col * 96 + 16, row * 80))
    # 修订图只包含下、右、左的瞄准姿态，其余五个方向继续使用原始帧。
    # 每次打包都应用此补丁，避免再次执行脚本时把已修正的持枪动作覆盖回去。
    aiming_path = ROOT / 'source/player_aiming_patch.png'
    if aiming_path.exists():
        aiming = Image.open(aiming_path)
        # 生成图各行留白并非严格等分，按实际透明间隙裁切，避免带入邻行帽檐或鞋尖。
        aiming_columns = [0, 450, 850, 1300]
        aiming_rows = [(80, 415), (435, 775), (795, 1125)]
        for source_row, atlas_row in enumerate([0, 1, 3]):
            for col in range(3):
                top, bottom = aiming_rows[source_row]
                box = (aiming_columns[col], top, aiming_columns[col + 1], bottom)
                frame = sprite_from_cell(aiming, box, (96, 80))
                # paste 替换整格透明像素，不能仅 alpha_composite，否则会残留旧枪轮廓。
                atlas.paste(frame, (col * 96, atlas_row * 80))
    atlas.save(ROOT / 'player_atlas.png')
    icons = Image.open(ROOT / 'source/item_sheet.png')
    names = ['pistol', 'smg', 'shotgun', 'grenade', 'molotov', 'shield', 'mortar', 'bombing', 'health', 'money', 'research', 'sprint', 'dodge', 'portrait', 'bullet', 'shell']
    widths = [0, 340, 685, 1015, icons.width]
    heights = [0, 280, 585, 825, icons.height]
    for index, name in enumerate(names):
        row, col = divmod(index, 4)
        size = (96, 48) if index < 3 else (64, 64)
        sprite_from_cell(icons, (widths[col], heights[row], widths[col + 1], heights[row + 1]), size).save(ROOT / f'{name}.png')
    panel = ROOT / 'source/panel.png'
    if panel.exists():
        Image.open(panel).resize((256, 256), Image.Resampling.NEAREST).save(ROOT / 'hud_panel.png')


if __name__ == '__main__':
    main()
