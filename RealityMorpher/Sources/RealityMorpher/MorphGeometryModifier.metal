#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;
using namespace realitykit;

[[visible]]
void debug_normals(realitykit::surface_parameters params)
{
	half3 debug_color = (half3(params.geometry().normal()) + half3(1.)) * 0.5;
	params.surface().set_base_color(debug_color);
}

[[visible]]
void morph_geometry_modifier(realitykit::geometry_parameters params)
{
	float3 weights = params.uniforms().custom_parameter().xyz;
	uint vertex_count = uint(params.uniforms().custom_parameter().z);
	uint vertex_id = params.geometry().vertex_id();
	
	float3 output_normal = params.geometry().normal();
	float3 base_position = params.geometry().model_position();
	float3 position_offset = float3(0);
	
	for (uint target_id = 0; target_id < 3; target_id ++) {
		uint position_id = vertex_id + (target_id * vertex_count);
		uint normal_id = vertex_id + ((3 + target_id) * vertex_count);
		float3 target_offset = float3(params.textures().custom().read(uint2(position_id % 8192, position_id / 8192)).xyz) - base_position;
		float3 target_normal = float3(params.textures().custom().read(uint2(normal_id % 8192, normal_id / 8192)).xyz);
		float weight = weights[target_id];
		position_offset = mix(position_offset, target_offset, weight);
		output_normal = mix(output_normal, target_normal, weight);
	}
	output_normal = normalize(output_normal);
	params.geometry().set_model_position_offset(position_offset);
	params.geometry().set_normal(output_normal);
}
