shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_disabled;

uniform sampler2D watercolor_texture : source_color, repeat_enable;
uniform sampler2D paper_texture : source_color, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float wash_amount : hint_range(0.0, 0.5) = 0.18;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 paint_uv = UV * 1.7 + world_position.xz * 0.035;
	vec3 wash = texture(watercolor_texture, paint_uv).rgb;
	vec3 paper = texture(paper_texture, paint_uv * 1.9).rgb;
	float paper_value = dot(paper, vec3(0.3333));
	vec3 pigment = mix(vec3(0.92), wash, wash_amount);
	ALBEDO = tint.rgb * pigment * mix(0.91, 1.08, paper_value);
	ROUGHNESS = 1.0;
}
