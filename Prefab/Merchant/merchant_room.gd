## 商人房内容控制器：初始化三件独立限购商品，反馈音效保留在房间内以免售出截断。
class_name MerchantRoom
extends Node2D

@export var catalog: ShopCatalog
## 由房间模板在入树前设置，各关库存随关卡种子变化，返回同一房间不重新生成。
@export var stock_seed: int = 0
## 商人原图的世界显示高度，单独调节不会影响商品碰撞或房间尺寸。
@export_range(24.0, 96.0, 1.0) var merchant_display_height: float = 56.0

@onready var feedback_label: Label = $FeedbackLabel
@onready var feedback_audio: AudioStreamPlayer2D = $FeedbackAudio

const PURCHASE_SOUND: AudioStream = preload("res://Assets/Audio/SFX/Shop/purchase.wav")
const DENIED_SOUND: AudioStream = preload("res://Assets/Audio/SFX/Shop/insufficient.wav")


## 在可编辑场景的三个展示位生成库存；商品位置避开四侧门口和商人所在处。
func _ready() -> void:
	# 原图保持完整透明像素；运行时按场景显示尺寸缩放，不覆盖生成源文件。
	var merchant: Sprite2D = $Merchant
	merchant.scale = Vector2.ONE * (merchant_display_height / maxf(merchant.texture.get_width(), merchant.texture.get_height()))
	if catalog == null:
		push_error("商人房缺少商品池配置。")
		return
	var stock := catalog.select_stock(stock_seed)
	var slots := $Offers.get_children()
	if stock.size() != 3 or slots.size() != 3:
		push_error("商人房必须包含三件商品和三个展示位。")
		return
	for index: int in range(3):
		var offer := slots[index] as ShopOffer
		offer.sig_purchase_result.connect(_on_purchase_result)
		offer.product = stock[index]
		# 子节点先于父节点 ready；这里配置后主动同步展示，触碰到下一物理帧才发生。
		offer.refresh_appearance()


## 商品发出结果后在商人位置反馈；商品销毁后音效仍能播放完，失败不逐帧重试。
func _on_purchase_result(success: bool, message: String) -> void:
	feedback_label.text = message
	feedback_label.modulate = Color("9fdfab") if success else Color("efb074")
	feedback_audio.stream = PURCHASE_SOUND if success else DENIED_SOUND
	feedback_audio.play()
