# 验证记录

2026-10-10，Godot 4.7.2 headless。

| 验证 | 结果 |
| --- | --- |
| 八主题 Boss 测试 | 375 checks，0 failures |
| 既有战术 Boss | 267 checks，0 failures |
| 坦克 Boss | 190 checks，0 failures |
| 特殊武器 | 74 checks，0 failures |
| 对局流程 | 224 checks，0 failures |
| PCM 文件检查 | 48 个文件均唯一、非静音，22.05 kHz / mono / 16-bit，无削波 |
| Git 空白检查 | `git diff --check` 通过 |

八主题测试覆盖三管生命、全部阶段招式执行、独立伙伴死亡、驾驶员受击尺寸、搁浅艇停止移动、危险区预警与重入、射毁、数量上限、正式关卡生成、一次结算，以及八个主体在真实物理帧中的首次攻击和播放器数量上限。真实帧检查发现过 GDScript 条件数组与 `Array[String]` 返回值不匹配，已修正并完整重跑。

对局流程原测试使用 SceneTree 入口，在当前 Godot 版本下直接 `--script` 会先于 AutoLoad 编译依赖。此次临时转为 Node 场景宿主执行相同断言，224 项通过；临时探针已删除，未修改原测试。该测试主动构造的无效模式、主题池不足错误属于预期断言。

新 Boss 可复现命令：

```sh
Godot --headless --path . res://tests/expedition_boss_test.tscn
```

沙箱下日志目录／音频设置写入、macOS 系统证书读取与部分退出资源警告仍存在；检查结果未把这些环境或退出警告算作玩法验收。未做真实设备听音、最终美术验收、长时间平衡或手柄验证。

所有八张 imagegen 源图请求返回网络连接错误，没有收到可打包图集。当前八主题 `art_provisional` 均为 true，临时引用旧资源，正式美术未完成。已保存内置 imagegen 提示词；未启用需 OPENAI_API_KEY 的 CLI/API 备用方案。
