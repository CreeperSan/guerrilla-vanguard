"""将内置 imagegen 源图裁切为规则游戏图集；只做透明裁切、等比缩放和打包。"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "Assets/Art/MilitaryArcade/Tactical"
# 生成源图并非等高网格；按实际透明行间隔切分，避免第一行弹匣被裁断。
ROW_EDGES = (0, 328, 610, 895, 1220)
COLUMN_EDGES = (0, 322, 644, 966, 1289)
CELL_SIZE = 96


def package() -> None:
    """保留原图与透明边缘，将每件完整轮廓置入独立 96 像素格。"""
    source = Image.open(ART / "source/tactical_atlas_generated.png").convert("RGBA")
    atlas = Image.new("RGBA", (CELL_SIZE * 4, CELL_SIZE * 4))
    for row in range(4):
        for column in range(4):
            cell = source.crop((COLUMN_EDGES[column], ROW_EDGES[row], COLUMN_EDGES[column + 1], ROW_EDGES[row + 1]))
            bounds = cell.getchannel("A").getbbox()
            if bounds is None:
                raise ValueError(f"Empty tactical icon at {row}, {column}")
            icon = cell.crop(bounds)
            icon.thumbnail((80, 80), Image.Resampling.LANCZOS)
            left = column * CELL_SIZE + (CELL_SIZE - icon.width) // 2
            top = row * CELL_SIZE + (CELL_SIZE - icon.height) // 2
            atlas.alpha_composite(icon, (left, top))
    atlas.save(ART / "tactical_atlas.png")
    print("Packaged 15 equipment icons and one reward chest:", atlas.size)


if __name__ == "__main__":
    package()
