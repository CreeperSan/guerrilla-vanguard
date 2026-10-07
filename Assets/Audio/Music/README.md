# 原创循环配乐

生成器：`tools/build_background_music.py`（需要 numpy）。导出为 22050 Hz / 16-bit / 双声道 WAV，旋律、和声、节奏和音色均由代码合成，没有引用商业音乐或外部音频采样。

| 场景 | 曲名 | 文件 | 速度 | 单轮时长 |
| --- | --- | --- | --- | --- |
| 首页、升级、设置、关于 | 集结号 | `menu_command.wav` | 92 BPM | 41.739 秒 |
| LevelFortress | 突破防线 | `level_fortress.wav` | 112 BPM | 34.286 秒 |
| LevelJungle | 绿色潜行 | `level_jungle.wav` | 124 BPM | 30.968 秒 |
| LevelVillage | 黎明巡行 | `level_village.wav` | 96 BPM | 40 秒 |
| LevelValley | 风之回声 | `level_valley.wav` | 88 BPM | 43.636 秒 |
| LevelMetropolis | 霓虹追击 | `level_metropolis.wav` | 128 BPM | 30 秒 |
| LevelUndergroundFortress | 铁幕核心 | `level_underground_fortress.wav` | 108 BPM | 35.556 秒 |
| LevelMineShaft | 深层脉冲 | `level_mine_shaft.wav` | 104 BPM | 36.923 秒 |

每首均为完整 16 小节乐句。最后小节的旋律下降回主音，响应下一轮开头；有限音符包络和环形延迟把尾音延续到下一轮，不以全局淡出或静音段分割循环。

播放由 AutoLoad GameSettings 管理。WAV 的完整乐句循环区间在运行时明确设置，也兼容以后替换为循环 OGG / MP3。换主题采用 0.8 秒线性响度交叉淡化。资源副本与播放器独立管理，不修改原有音效。

主题音乐在各 `theme.tres` 的 `background_music` 配置。当前源文件和 `tracks.json` 保存曲目映射、种子与时长；早期 `forward_base.wav` 保留，但正式入口已使用新的首页曲。

当前未验证真实音频设备的播放、混音与听感，需要在 Godot 或播放器中试听。
