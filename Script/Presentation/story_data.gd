## 剧情分镜数据：美术页按等分网格取图，字幕与图像可单独手工替换。
class_name StoryIntroData
extends Resource
@export var sheet: Texture2D
@export var columns := 3
@export var rows := 2
@export var captions: Array[String] = []
