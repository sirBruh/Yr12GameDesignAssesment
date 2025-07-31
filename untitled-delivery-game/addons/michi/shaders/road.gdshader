/*
	道描画シェーダー
		Programmed by あるる（きのもと 結衣） @arlez80
	Road Drawing Shader

	MIT License
*/
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D asphalt_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D white_line_texture : source_color, hint_default_transparent, repeat_enable;
uniform float repeat_per_meter : hint_range( 0.01, 1000.0 ) = 1.0;
uniform vec2 asphalt_uv_scale = vec2( 1.0, 1.0 );
uniform float metallic : hint_range( 0.0, 1.0 ) = 0.0;
uniform float specular : hint_range( 0.0, 1.0 ) = 0.5;
uniform float roughness : hint_range( 0.0, 1.0 ) = 1.0;

instance uniform int from_lanes = 1;
instance uniform int to_lanes = 1;
instance uniform float road_length = 1.0;
instance uniform bool has_opposite_lane = false;

void fragment( )
{
	float lanes = mix( float( from_lanes ), float( to_lanes ), UV.y  );
	float max_lanes = float( max( from_lanes, to_lanes ) );
	float rev_uv_x = 1.0 - UV.x;

	// テクスチャのABCDのうち、どこに入るか？
	float lane_uv_x = UV.x * lanes;
	float rev_lane_uv_x = rev_uv_x * lanes;
	float tex_base_x = mix(
		float( rev_lane_uv_x < floor( max_lanes - 1.0 ) )	//	AかB
	,	3.0 - float( has_opposite_lane )					//	CかD
	,	float( rev_lane_uv_x < 0.5 )
	);
	vec2 last_uv = vec2(
		mix(
			( mod( lane_uv_x, 1.0 ) ) * 0.25						// A
		,	( tex_base_x + 1.0 - mod( rev_lane_uv_x, 1.0 ) ) * 0.25	// B,C,D
		,	clamp( tex_base_x, 0.0, 1.0 )
		)
	,	UV.y * road_length / repeat_per_meter
	);

	vec4 white_line_albedo = textureLod( white_line_texture, last_uv, 0.0 );
	ALBEDO = mix(
		texture( asphalt_texture, vec2( UV.x, last_uv.y * 2.0 ) * asphalt_uv_scale ).rgb
	,	white_line_albedo.rgb
	,	white_line_albedo.a
	);
	METALLIC = metallic;
	SPECULAR = specular;
	ROUGHNESS = roughness;
	// NORMAL_MAP = texture( normal_texture, last_uv ).rgb;
}
