## 关卡主题资源列表；GameManager 将其作为抽取池，主题只替换模板和美术。
class_name BattlefieldCampaign
extends Resource

## 可用主题配置；数组顺序不决定正式对局顺序，旧资源仍可通过 get_theme 按索引读取。
@export var themes: Array[BattlefieldTheme] = []


## 保留旧资源的按索引读取接口；正式对局随机推进由 GameManager 统一负责。
func get_theme(level_number: int) -> BattlefieldTheme:
    var index := level_number - 1
    if index < 0 or index >= themes.size():
        return null
    return themes[index]
