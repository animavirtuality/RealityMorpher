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

// Function to create a 3x3 rotation matrix for rotation around the Z-axis
float3x3 create_rotation_matrix(float rotation) {
    float cosTheta = cos(rotation);
    float sinTheta = sin(rotation);
    return float3x3(
        float3(cosTheta, -sinTheta, 0.0),
        float3(sinTheta, cosTheta, 0.0),
        float3(0.0, 0.0, 1.0)
    );
}

// Define the custom type
struct TransformElements {
    float2 scale;
    float rotation;
    float2 translation;
};

// Function to convert a unit quaternion to a 3x3 rotation matrix
float3x3 quaternionToMatrix(float4 q) {
    float w = q.w;
    float x = q.x;
    float y = q.y;
    float z = q.z;

    return float3x3(
        1 - 2*y*y - 2*z*z, 2*x*y - 2*z*w, 2*x*z + 2*y*w,
        2*x*y + 2*z*w, 1 - 2*x*x - 2*z*z, 2*y*z - 2*x*w,
        2*x*z - 2*y*w, 2*y*z + 2*x*w, 1 - 2*x*x - 2*y*y
    );
}

// Function to rotate a vector by a unit quaternion
float3 rotateVectorByQuaternion(float3 v, float4 q) {
    // Normalize the quaternion
    float qNorm = length(q);
    q /= qNorm;

    // Convert quaternion to rotation matrix
    float3x3 R = quaternionToMatrix(q);

    // Rotate the vector
    float3 v_rotated = R * v;

    return v_rotated;
}

TransformElements extract_transform_elements(realitykit::geometry_parameters params) {
    // The scale and rotation are packed into a float2x2 matrix, and the offset is contained in a separate float2.
    float2x2 matrix = params.uniforms().uv1_transform();

    // Extracting scale
    float scaleX = length(matrix[0]);
    float scaleY = length(matrix[1]);

    // Extracting rotation
    // Saving compute for now since we're not using this.
    float rotation = float(0); // atan2(matrix[0][1], matrix[0][0]);

    // Extracting translation
    float2 translation = params.uniforms().uv1_offset();

    // Return the extracted elements
    return TransformElements{float2(scaleX, scaleY), rotation, translation};
}

void morph_geometry(realitykit::geometry_parameters params, uint target_count) {
    
    float4 weights = params.uniforms().custom_parameter();
    uint vertex_id = params.geometry().vertex_id();
    float total_weight = min(1.0, weights.x + weights.y + weights.z + weights.w);
    float3 output_normal = params.geometry().normal() * (1.0 - total_weight);
    float3 position_offset = float3(0);
    uint tex_width = params.textures().custom().get_width();

    for (uint target_id = 0; target_id < target_count; target_id++) {
        uint position_id = ((vertex_id * target_count) + target_id) * 2;
        uint normal_id = position_id + 1;
        float3 target_offset = float3(params.textures().custom().read(uint2(position_id % tex_width, position_id / tex_width)).xyz);
        float3 target_normal = float3(params.textures().custom().read(uint2(normal_id % tex_width, normal_id / tex_width)).xyz);
        float weight = weights[target_id];

        position_offset += target_offset * weight;
        output_normal += target_normal * weight;
    }
    
    // The scale and rotation are packed into a float2x2 matrix, and the offset is contained in a separate float2.
    const TransformElements transformElements = extract_transform_elements(params);
    
    const float4 quat = float4(transformElements.translation.x,
                               transformElements.translation.y,
                               transformElements.scale.x,
                               transformElements.scale.y);
    
    // Fix the askew issue with skeletal animation + geometry morphing.
    position_offset = rotateVectorByQuaternion(position_offset, quat);
    
    params.geometry().set_model_position_offset(position_offset);
    
    params.geometry().set_normal(normalize(output_normal));
}

// We cannot use MTLFunctionConstants with RealityKit Geometry Modifiers, hence 3 different targets

[[visible]]
void morph_geometry_target_count_1(realitykit::geometry_parameters params)
{
    morph_geometry(params, 1);
}

[[visible]]
void morph_geometry_target_count_2(realitykit::geometry_parameters params)
{
    morph_geometry(params, 2);
}

[[visible]]
void morph_geometry_target_count_3(realitykit::geometry_parameters params)
{
    morph_geometry(params, 3);
}

[[visible]]
void morph_geometry_target_count_4(realitykit::geometry_parameters params)
{
    morph_geometry(params, 4);
}
