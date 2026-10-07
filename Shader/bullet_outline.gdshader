shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_size : hint_range(0.0, 4.0, 1.0) = 1.0;

void fragment() {
	vec4 modulation = COLOR;
	vec4 sprite_color = texture(TEXTURE, UV) * modulation;
	if (sprite_color.a > 0.01) {
		COLOR = sprite_color;
	} else {
		vec2 pixel = TEXTURE_PIXEL_SIZE * outline_size;
		float neighbor_alpha = 0.0;
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-pixel.x, 0.0)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, -pixel.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + pixel).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - pixel).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);

		COLOR = vec4(outline_color.rgb, outline_color.a * neighbor_alpha) * modulation;
	}
}
