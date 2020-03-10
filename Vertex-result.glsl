
#version 430 core
layout(location = 0) in vec3 vertex_position;
layout(location = 1) in vec2 vertex_uv;
layout(location = 2) in vec3 vertex_normal;
layout(location = 3) in vec3 vertex_tangent;
layout(location = 4) in vec3 vertex_bitangent;

layout(location = 5) in mat4 M;
// layout (location = 6) in use ...
// layout (location = 7) in use ...
// layout (location = 8) in use ...

out Vertex {
    vec2 uv;
    vec3 position_m;
    vec3 position_mv;

    vec3 normal_mv;
    vec3 eye_direction_mv;
    vec3 light_direction_mv;

    vec3 eye_direction_tbn;
    vec3 light_direction_tbn;
} vert;


uniform mat4 V;
uniform mat4 P;
uniform mat4 Ortho;

uniform vec3 light_position_m;

uniform bool flatten;

void main()
{
    mat4 MV = V*M;

    vec3 position = vertex_position;
    if (flatten)
    {
        // vec3 plane_normal = normalize((inverse(V) * vec4(0, 0, 0, 1)).xyz);
        // plane_normal      = normalize(((inverse(M) * vec4(plane_normal, 0)).xyz) * vec3(1, 0, 1));
        
        vec3 plane_normal = (inverse(V) * vec4(0, 0, -1, 0)).xyz * vec3(1,0,1);
        plane_normal = normalize((inverse(M) * vec4(plane_normal, 0)).xyz);
        
        vec3 flattened = vertex_position - dot(vertex_position, plane_normal)*plane_normal*0.98;
        position = flattened; 
    }

    // vec3 pixelated = round(position*6)/6;
    
    // Position of the vertex, in worldspace
    vert.position_m =  (M * vec4(position,1)).xyz;
    
    // Vector from vertex to camera, in camera space
    vec3 vertex_position_mv = (MV * vec4(position, 1)).xyz;
    vert.eye_direction_mv = vec3(0, 0, 0) - vertex_position_mv;

    // Vector from vertex to light, in camera space
    vec3 light_position_mv = (V * vec4(light_position_m, 1)).xyz;
    vert.light_direction_mv = light_position_mv + vert.eye_direction_mv;
    
    mat3 MV3x3 = mat3(MV);
    vert.normal_mv    = transpose(inverse(MV3x3)) * normalize(vertex_normal);
    vec3 tangent_mv   = MV3x3 * normalize(vertex_tangent);
    vec3 bitangent_mv = MV3x3 * normalize(vertex_bitangent);

    mat3 TBN = transpose(mat3(
        tangent_mv,
        bitangent_mv,
        vert.normal_mv
    ));

    vert.light_direction_tbn = TBN * vert.light_direction_mv;
    vert.eye_direction_tbn   = TBN * vert.eye_direction_mv;

    // UV of the vertex
    vert.uv = vertex_uv;
    
    gl_Position = P*MV * vec4(position, 1);
}


