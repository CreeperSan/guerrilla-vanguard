# 临时死亡与胜利动作

生成方式：内置 `image_gen` 工具，透明背景。原图保存为 `death_actions_source.png`。

运行时图集为 `death_actions.png`，288 × 400，三列五行，每帧 96 × 80。
按等分单元裁切原图透明边缘，每一行使用相同缩放比例，以最近邻缩小并对齐底部基线；没有重新绘制或改变动作内容。

从上到下：玩家倒地、普通敌人倒地、指挥官倒地、佣兵倒地、玩家胜利。
每行从左至右播放三帧，死亡行的第三帧就是静态遗体。
所有方向暂时共用一套动作，Boss/机械犬也使用统一的临时倒地占位图，供后续美术审视与替换。

实际生成提示词：

> Use case: stylized-concept. Asset type: provisional 2D top-down military arcade game sprite animation atlas. Produce ONE transparent PNG sprite sheet arranged in EXACTLY 3 equal columns and 5 equal rows, no margins between cells, each cell same size. Fifteen separate sprites total, absolutely no text labels, no grid lines, no background, no shadows extending outside a cell. Chunky cute compact soldiers with very large helmet and small body, dark bold outlines, simple olive/steel military uniform, match top-down 3/4 chibi arcade soldiers. Each sprite centered on the same anchor at 50% width and 65% height of its cell, all fully within cell with generous transparent padding. ROW 1: olive green helmet player soldier death in 3 frames from left to right: recoiling injured, falling sideways, lying motionless on side. ROW 2: dark steel blue helmet enemy soldier death, same 3 poses. ROW 3: tan armored commander death, same 3 poses. ROW 4: teal helmet friendly mercenary death, same 3 poses. ROW 5: olive green player victory in 3 frames: standing with rifle lowered, raising a clenched fist, fist high in celebration. Each final death pose is a readable prone body, no blood or gore, no extra weapons separate from bodies. All three stages have consistent character scale. Prefer simple pixel-art-like shapes and few colors, this is temporary low-frame-count animation art. Canvas portrait with 3 columns by 5 rows equal square cells, ideal 1536x2560. Actual alpha transparency required.
