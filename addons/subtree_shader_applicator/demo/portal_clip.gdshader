// Spatial shader applied to PortalMeshDuplicator clones.
// Discards fragments that are on the exit side of the portal plane so the
// duplicate is only visible from the side it logically belongs to.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// World-space clip plane: discard if dot(world_pos, normal) > d + epsilon
uniform vec3  clip_plane_normal;
uniform float clip_plane_d;

// Basic PBR properties mirrored from the original surface material.
uniform vec4  albedo_color   : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color,
    filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float roughness      : hint_range(0.0, 1.0) = 0.8;
uniform float metallic       : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Clip to portal plane.  Fragments on the exit side (positive dot) are discarded.
	if (dot(world_pos, clip_plane_normal) - clip_plane_d > 0.001) {
		discard;
	}
	vec4 color = albedo_color * texture(albedo_texture, UV);
	ALBEDO    = color.rgb;
	ROUGHNESS = roughness;
	METALLIC  = metallic;
}
