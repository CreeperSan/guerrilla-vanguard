"""打包 imagegen 生成的佣兵 4×8 图集，保留源图透明度并统一动画脚底锚点。

此工具只做等格裁切、最近邻缩放和资源排布，不重新绘制角色。
输入源图留存于 Assets/Art/MilitaryArcade/Mercenary/source/。
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / 'Assets/Art/MilitaryArcade/Mercenary'


def package(name, source_name=None):
    """按八方向、四姿势裁切图集，以统一缩放系数将每帧脚底对齐到 y=54。"""
    image = Image.open(ROOT / 'source' / ((source_name or name) + '.png')).convert('RGBA')
    frames = []
    for row in range(8):
        for column in range(4):
            bounds = (round(column * image.width / 4), round(row * image.height / 8),
                      round((column + 1) * image.width / 4), round((row + 1) * image.height / 8))
            frame = image.crop(bounds)
            bbox = frame.getchannel('A').point(lambda value: 255 if value > 32 else 0).getbbox()
            if bbox is None:
                raise ValueError(f'{name}: empty sprite at {row}, {column}')
            frames.append(frame.crop(bbox))
    factor = min(48 / max(frame.height for frame in frames), 56 / max(frame.width for frame in frames))
    atlas = Image.new('RGBA', (256, 512))
    for index, frame in enumerate(frames):
        resized = frame.resize((max(1, round(frame.width * factor)), max(1, round(frame.height * factor))), Image.Resampling.NEAREST)
        cell = Image.new('RGBA', (64, 64))
        cell.alpha_composite(resized, ((64 - resized.width) // 2, 54 - resized.height))
        atlas.alpha_composite(cell, ((index % 4) * 64, (index // 4) * 64))
    atlas.save(ROOT / (name + '_atlas.png'))
    portrait = Image.new('RGBA', (128, 128))
    front = frames[0]
    factor = min(112 / front.width, 112 / front.height)
    front = front.resize((round(front.width * factor), round(front.height * factor)), Image.Resampling.NEAREST)
    portrait.alpha_composite(front, ((128 - front.width) // 2, 120 - front.height))
    portrait.save(ROOT / (name + '_portrait.png'))


def main():
    """生成两个兵种的战斗图集和对应招募肖像，不覆盖手枪佣兵美术。"""
    package('grenadier')
    package('fearless_v2', 'fearless_fists')


if __name__ == '__main__':
    main()
