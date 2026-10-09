"""将已确认的参考图玩家原画打包为 Godot 使用的八方向动画图集。

原画行序为下、右、上、左、右上、左上、左下、右下；每行三列依次是
待机、迈左腿、迈右腿。保留原画及枪口朝向，只裁切透明边缘和缩放。
"""
from pathlib import Path

from PIL import Image


ART_DIR = Path(__file__).resolve().parents[1] / "Assets/Art/MilitaryArcade"
SOURCE = ART_DIR / "source/player_reference_24_refined.png"
OUTPUT = ART_DIR / "player_reference_atlas.png"
SOURCE_SIZE = (1086, 1448)
FRAME_SIZE = (96, 80)
SOURCE_SCALE = 0.38

# 原画角色间距不均，且向上射击的枪口越过普通等分行界；这些边界均在透明间隙。
ROW_EDGES = (0, 186, 356, 549, 721, 894, 1068, 1239, 1448)
# 每行的三组横向裁切范围只包含对应人物，避免长枪管带入相邻动画帧。
COLUMN_EDGES = (
    ((279, 405), (481, 606), (686, 810)),
    ((272, 446), (477, 652), (680, 855)),
    ((284, 408), (488, 611), (693, 815)),
    ((234, 410), (438, 612), (643, 817)),
    ((269, 436), (475, 638), (678, 847)),
    ((255, 422), (460, 620), (663, 827)),
    ((254, 419), (464, 623), (660, 827)),
    ((260, 423), (471, 639), (672, 843)),
)


def pack_player_atlas() -> None:
    """逐帧裁出原画主体，等比缩小并将脚底对齐到现有 96×80 动画格。"""
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != SOURCE_SIZE:
        raise ValueError(f"原画尺寸已变化，请重审裁切边界：{source.size}")

    atlas = Image.new("RGBA", (FRAME_SIZE[0] * 3, FRAME_SIZE[1] * 8))
    for row in range(8):
        for column in range(3):
            left, right = COLUMN_EDGES[row][column]
            cell = source.crop((left, ROW_EDGES[row], right, ROW_EDGES[row + 1]))
            # 使用主体像素定位，保留外围两像素的半透明抗锯齿，不让背景噪点改变对齐。
            bounds = cell.getchannel("A").point(lambda alpha: 255 if alpha > 16 else 0).getbbox()
            if bounds is None:
                raise ValueError(f"原画第 {row + 1} 行第 {column + 1} 列为空")
            bounds = (
                max(0, bounds[0] - 2), max(0, bounds[1] - 2),
                min(cell.width, bounds[2] + 2), min(cell.height, bounds[3] + 2),
            )
            character = cell.crop(bounds)
            size = (round(character.width * SOURCE_SCALE), round(character.height * SOURCE_SCALE))
            if size[0] > FRAME_SIZE[0] - 4 or size[1] > FRAME_SIZE[1] - 4:
                raise ValueError(f"原画第 {row + 1} 行第 {column + 1} 列超出动画格：{size}")
            character = character.resize(size, Image.Resampling.LANCZOS)
            # 两像素脚底余量避免线性采样时取到下一行；角色视觉位置保持居中。
            x = column * FRAME_SIZE[0] + (FRAME_SIZE[0] - size[0]) // 2
            y = row * FRAME_SIZE[1] + FRAME_SIZE[1] - 2 - size[1]
            atlas.alpha_composite(character, (x, y))
    atlas.save(OUTPUT)


if __name__ == "__main__":
    pack_player_atlas()
