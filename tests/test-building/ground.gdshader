shader_type canvas_item;
render_mode blend_mix;

uniform vec4 grass_color : source_color;
uniform vec4 dirt_color : source_color;

//varying vec2 world_pos;

void vertex() {
	//world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0, 1.0)).xy;

}

void fragment() {
	vec4 color = dirt_color;
	if (UV.y > 0.02) {
		color = dirt_color;
	} else {
		color = grass_color;
	}

	COLOR = vec4(0, UV.y, 0.0, 1.0);
	color.r = mix(color.r, COLOR.r, 0.5);
	color.g = mix(color.g, COLOR.g, 0.5);
	color.b = mix(color.b, COLOR.b, 0.5);
	COLOR = color;
}