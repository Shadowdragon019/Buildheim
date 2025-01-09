shader_type canvas_item;
render_mode blend_mix;

uniform bool blocked;

void fragment() {
	if (blocked) {
		COLOR.r = 1.0;
	}
}