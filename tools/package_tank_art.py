"""为已生成的透明坦克图集创建 Godot AtlasTexture，不重绘或修改原始 PNG。

素材行的实际留白不同，按可见对象边界切分，而不是强制四乘三的等分帧。
资源保留源图引用，后续替换美术只需调整切片矩形与炮塔轴心。
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Assets/Art/MilitaryArcade/Tank'
NAMES = ['hull_down', 'hull_right', 'hull_up', 'hull_left',
         'turret', 'turret_overload', 'wreck', 'shell',
         'driver_down', 'driver_right', 'driver_up', 'driver_left']
ROWS = [(0, 400), (400, 754), (754, 1086)]
COLS = [0, 362, 724, 1086, 1448]


def main():
    """只写可编辑的 AtlasTexture 切片资源，PNG 源文件保持原始字节。"""
    for index, name in enumerate(NAMES):
        row, col = divmod(index, 4)
        top, bottom = ROWS[row]
        resource = ('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
                    '[ext_resource type="Texture2D" path="res://Assets/Art/MilitaryArcade/Tank/source/tank_sheet.png" id="1"]\n\n'
                    '[resource]\natlas = ExtResource("1")\n'
                    f'region = Rect2({COLS[col]}, {top}, {COLS[col + 1] - COLS[col]}, {bottom - top})\n')
        (ART / f'{name}.tres').write_text(resource)


if __name__ == '__main__':
    main()
