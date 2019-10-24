#version 330 core

layout(location = 0) in vec3 vertex_position;
layout(location = 1) in vec2 vertex_uv;
layout(location = 2) in vec3 vertex_normal;
layout(location = 3) in vec3 vertex_tangent;
layout(location = 4) in vec3 vertex_bitangent;

layout(location = 5) in mat4 M;
// layout (location = 6) in use ...
// layout (location = 7) in use ...
// layout (location = 8) in use ...

out vec2 uv;
out vec3 position_m;
out vec3 normal_mv;
out vec3 eye_direction_mv;
out vec3 light_direction_mv;

out vec3 eye_direction_tbn;
out vec3 light_direction_tbn;

uniform mat4 MVP;
uniform mat4 VP;
uniform mat4 V;
uniform mat4 P;
uniform vec3 light_position_m;

void main()
{
    mat4 MV = V*M;

    // Position of the vertex, in worldspace
    position_m =  (M * vec4(vertex_position,1)).xyz;
    
    // Vector from vertex to camera, in camera space
    vec3 vertex_position_mv = (MV * vec4(vertex_position, 1)).xyz;
    eye_direction_mv = vec3(0, 0, 0) - vertex_position_mv;

    // Vector from vertex to light, in camera space
    vec3 light_position_mv = (V * vec4(light_position_m, 1)).xyz;
    light_direction_mv = light_position_mv + eye_direction_mv;

    // normal_mv         = (MV * vec4(vertex_normal, 0)).xyz;
    // vec3 tangent_mv   = (MV * vec4(vertex_tangent, 0)).xyz;
    // vec3 bitangent_mv = (MV * vec4(vertex_bitangent, 0)).xyz;
    
    mat3 MV3x3 = mat3(MV);
    normal_mv         = MV3x3 * normalize(vertex_normal);
    vec3 tangent_mv   = MV3x3 * normalize(vertex_tangent);
    vec3 bitangent_mv = MV3x3 * normalize(vertex_bitangent);

    mat3 TBN = transpose(mat3(
        tangent_mv,
        bitangent_mv,
        normal_mv
    ));

    light_direction_tbn = TBN * light_direction_mv;
    eye_direction_tbn   = TBN * eye_direction_mv;

    // UV of the vertex
    uv = vertex_uv;

    // Position of the vertex, in clip space
    gl_Position = P*MV * vec4(vertex_position, 1);
}
