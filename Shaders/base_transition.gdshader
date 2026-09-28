shader_type canvas_item;
render_mode unshaded;

uniform sampler2D display_texture : source_color, filter_linear, repeat_disable;

void fragment() {
	// Preserve the ColorRect's modulate alpha, animated by TransitionManager.
	COLOR *= texture(display_texture, UV);
}
