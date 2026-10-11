# 启动、转场、战报和片尾

## 正式流程

每次启动从 `Scene/StudioIntro/StudioIntro.tscn` 进入，完整播放两张滚动工作室信息卡（约 5.4 秒），不可通过键盘、手柄或触摸提前跳过。之后默认进入 `Scene/StoryIntro/StoryIntro.tscn`，六格漫画按触摸或按键逐格推进，右上角跳过可进入首页。

首页设置页新增“启动时跳过剧情介绍”，保存在 `user://audio_settings.cfg` 的 `presentation/skip_story_intro`。开启后仍播放 Sunny Studio，但不再加载漫画。回到首页不会重播工作室或故事。

首页开始 → 战斗、Level → 下一个 Level、胜败 → 战报、战报 → 首页 / 片尾均使用 `SceneTransition` 全屏淡入淡出遮幕。换场、房间释放及新地图生成发生在遮幕完全不透明之后。覆盖期间阻止输入与重复导航，暂停期间 Tween 仍运行。

胜败都进入 `Scene/RunResult/RunResult.tscn`，替代 HUD 旧结果对话框。原节点仅保留给旧场景工具兼容，正式结果不再显示它们。反击完整七关胜利的主按钮是“继续 · 制作人员”，进入 `Scene/Credits/Credits.tscn` 滚动片尾；片尾可返回战报或首页，按住 Shift 或触摸加速滚动。

## 可以直接编辑的内容

- `Script/Presentation/credits.tres`：制作人员、版权、感谢与技术致谢，支持 BBCode。`scroll_speed` 控制滚动速度。当前没有捏造创作者姓名，姓名、版权年份、权利人及联系地址保留“请填写”；发布前替换为真实信息并核对第三方许可。
- `Script/Presentation/story_intro.tres`：六格字幕、原图与网格行列数。
- `Assets/Art/MilitaryArcade/Story/prologue.png`：已接入的 imagegen 漫画原图，提示词见同目录 `GENERATION.md`。替换时保持分格顺序和网格数一致。
- `Scene/StudioIntro/studio_intro.gd`：工作室两张卡的名称、副标题，`card_duration` 控制每张卡停留时间。
- `Script/Presentation/flow_ui.gd`：新流程页面共享字体、背景、文字颜色和页边距。

## 战报的记录口径

`RunStats` 常驻整个对局，只在新局重置，跨 Level 保留；胜败时在钱包清空前冻结，之后所有事件都不再改变报告。记录成功发生的事件，而非输入尝试：

- 作战时间：不含暂停、开场倒计时、转场、结果与片尾。
- 房间：按“关卡序号 + 房间 ID”去重；战斗房与首领房是清空，安全商店 / 起始房 / 佣兵房是完成探索。
- 敌人：按实例去重，分普通敌军行为类别及首领名称；包含佣兵击杀，同时单列佣兵贡献。不统计由脚本标记为无奖励清理的临时敌人。
- 金钱：记录倍率处理后的实际收入、实际消费、结算前余额；发放失败退款冲减消费，不计为新收入。研究点数另列。
- 道具与能力：成功投掷手雷 / 燃烧瓶、实际恢复生命的医疗补给、举盾、闪避、成功召唤的迫击炮 / 战术轰炸。
- 武器：按实际扣除弹夹的一次扳机记录，空枪、冷却、换弹不计；霰弹多个颗粒另外累计到投射物总数。佣兵开火不计入玩家武器。
- 战术装备：按唯一 ID 记录本局实际获得的显示名。

最后一次战报以 JSON 保存在 `user://last_run_report.json`；先写临时文件再原子替换。结果页数字 Tween 只处理副本，不修改真实收益。战报或研究结算保存失败会在结果页明确提示并提供重试；研究账户待存时暂缓离开，以免关闭进程丢失收益。战报单独保存失败不会锁住退出。该版本只保存最近一局，并非历史战报列表。

## 验证入口

```sh
godot --headless --path . res://tests/presentation_flow_test.tscn
godot --headless --path . res://tests/presentation_navigation_test.tscn
godot --path . --resolution 1280x720 res://tests/presentation_preview.tscn
```

事件/UI 测试覆盖重复统计、实际开火、退款、暂停计时、动画遮幕、漫画分格、结果按钮、制作名单滚动和新局重置。导航测试使用真实场景验证启动偏好两个分支、不可跳过开场、触摸推进、跳过漫画、首页进入战场、后续 Level、战败进入结果、反击战报进入片尾及返回战报。测试战报写入 `/private/tmp`，不结算真实研究收益。

图形预览截图输出 `/private/tmp/gv-studio.png`、`gv-story.png`、`gv-report.png`、`gv-credits.png`。实际手柄、手机和长时间游玩仍需设备验收。既有战斗 HUD 的 VBoxContainer 方向修改日志、macOS 无头证书日志与沙箱设置保存警告不属于本次功能；不为清除日志改动无关逻辑。

本次验证结果：事件/UI 30 项、真实导航 15 项、既有路线推进 224 项、特殊武器 76 项、玩家操作 97 项，均为零失败。路线测试的 SceneTree 命令行预编译会提前解析自动加载依赖，因此本次以临时 Node 适配入口在自动加载就绪后执行同一份 224 项断言，未改动原测试源文件。
