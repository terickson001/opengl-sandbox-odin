@version 430 core

@vertex

layout(location = 0) in vec3 vertex_position;
layout(location = 1) in vec2 vertex_uv;
layout(location = 2) in vec3 vertex_normal;
layout(location = 3) in vec3 vertex_tangent;
layout(location = 4) in vec3 vertex_bitangent;

layout(location = 5) in mat4 M;
// layout (location = 6) in use ...
// layout (location = 7) in use ...
// layout (location = 8) in use ...

@interface(vert, frag)
{
     vec2 uv;
     vec3 position_m;
     vec3 position_mv;
     
     vec3 normal_mv;
     vec3 eye_direction_mv;
     vec3 light_direction_mv;
     
     vec3 eye_direction_tbn;
     vec3 light_direction_tbn;
}

uniform mat4 V;
uniform mat4 P;

uniform vec3 light_position_m;

uniform bool flatten;

void main()
{
     mat4 MV = V*M;
     
     vec3 position = vertex_position;
     /*
     vec3 pixelated = round(position*6)/6;
     position = pixelated;
     */
     
     if (flatten)
         {
         // vec3 plane_normal = normalize((inverse(V) * vec4(0, 0, 0, 1)).xyz);
         // plane_normal      = normalize(((inverse(M) * vec4(plane_normal, 0)).xyz) * vec3(1, 0, 1));
         
         vec3 plane_normal = (inverse(V) * vec4(0, 0, -1, 0)).xyz * vec3(1,0,1);
         plane_normal = normalize((inverse(M) * vec4(plane_normal, 0)).xyz);
         
         vec3 flattened = position - dot(position, plane_normal)*plane_normal*0.98;
         position = flattened;
     }
     
     
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


@fragment

out vec3 color;

uniform sampler2D diffuse_sampler;
uniform sampler2D normal_sampler;
uniform sampler2D specular_sampler;

uniform vec3 light_color;
uniform float light_power;
uniform vec3 light_position_m;

const float specularity = 0.5;
void main()
{
     float pixels = 128.0;
     float d = 15 * (1/pixels);
     vec2 pix_uv = d * floor(frag.uv/d);
     
     vec3 material_diffuse_color = texture(diffuse_sampler, frag.uv).rgb;
     vec3 material_ambient_color = 0.3f * material_diffuse_color;
     vec3 material_specular_color = texture(specular_sampler, frag.uv).rgb * specularity;
     
     float dist = length(light_position_m - frag.position_m);
     
     vec3 n = normalize(texture(normal_sampler, vec2(frag.uv.x, frag.uv.y)).rgb*2.0 - 1.0);
     vec3 l = normalize(frag.light_direction_tbn);
     vec3 E = normalize(frag.eye_direction_tbn);
     
     vec3 R = reflect(-l, n);
     float cos_theta = clamp(dot(n, l), 0, 1);
     float cos_alpha = clamp(dot(E, R), 0, 1);
     
     color =
         // Ambient : simulates indirect lighting
         material_ambient_color +
         // Diffuse : "color" of the object
         material_diffuse_color * light_color * light_power * cos_theta / (dist*dist) +
         // Specular : reflective highlight, like a mirror
         material_specular_color * light_color * light_power * pow(cos_alpha, 16) / (dist*dist);
}
