// 命中闪白只替换精灵颜色，保留原纹理的透明轮廓和节点透明度。
shader_type canvas_item;

void fragment() {
	COLOR = vec4(1.0, 1.0, 1.0, COLOR.a);
}
