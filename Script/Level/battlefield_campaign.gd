## 有序关卡主题列表；关卡编号继续决定 Boss 路线步数，主题只替换模板和美术。
class_name BattlefieldCampaign
extends Resource

## 从第一关开始的主题顺序；直接运行中间关卡场景时也使用相同编号索引。
@export var themes: Array[BattlefieldTheme] = []


## 返回指定关卡对应的主题，配置缺失时返回 null，由控制器使用原有主题兜底。
func get_theme(level_number: int) -> BattlefieldTheme:
	var index := level_number - 1
	if index < 0 or index >= themes.size():
		return null
	return themes[index]
