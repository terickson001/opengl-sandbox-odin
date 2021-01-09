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

@out vert
{
    vec2 uv;
    vec3 position_m;
    vec3 position_mv;
    
    mat3 TBN;
    
    vec3 normal_mv;
    vec3 eye_direction_mv;
    vec3 light_direction_mv;
    
    vec3 eye_direction_tbn;
    vec3 light_direction_tbn;
};

uniform mat4 V;
uniform mat4 P;

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
    
    vec3 T = normalize(vec3(M * vec4(vertex_tangent,   0.0)));
    vec3 B = normalize(vec3(M * vec4(vertex_bitangent, 0.0)));
    vec3 N = normalize(vec3(M * vec4(vertex_normal,    0.0)));
    
    vert.TBN = mat3(T, B, N);
    
    mat3 TBNinv = transpose(mat3(tangent_mv,
                                 bitangent_mv,
                                 vert.normal_mv
                                 ));
    
    vert.light_direction_tbn = TBNinv * vert.light_direction_mv;
    vert.eye_direction_tbn   = TBNinv * vert.eye_direction_mv;
    
    // UV of the vertex
    vert.uv = vertex_uv;
    
    gl_Position = P*MV * vec4(position, 1);
}


@geometry
layout (triangles) in;
layout (triangle_strip, max_vertices = 3) out;

uniform ivec2 resolution;

@inout vert[] frag;
noperspective out vec3 edge_dist;

void main(void)
{
    vec2 p0 = resolution * gl_in[0].gl_Position.xy/gl_in[0].gl_Position.w;
    vec2 p1 = resolution * gl_in[1].gl_Position.xy/gl_in[1].gl_Position.w;
    vec2 p2 = resolution * gl_in[2].gl_Position.xy/gl_in[2].gl_Position.w;
    vec2 v0 = p2-p1;
    vec2 v1 = p2-p0;
    vec2 v2 = p1-p0;
    float area = abs(v1.x*v2.y - v1.y*v2.x);
    
    edge_dist = vec3(area/length(v0), 0, 0);
    frag = vert[0];
    gl_Position = gl_in[0].gl_Position;
    EmitVertex();
    
    edge_dist = vec3(0, area/length(v1), 0);
    frag = vert[1];
    gl_Position = gl_in[1].gl_Position;
    EmitVertex();
    
    edge_dist = vec3(0, 0, area/length(v2));
    frag = vert[2];
    gl_Position = gl_in[2].gl_Position;
    EmitVertex();
    
    EndPrimitive();
}

@fragment

@in frag;
noperspective in vec3 edge_dist;

out vec3 color;

uniform bool shaded;

uniform sampler2D albedo_map;
uniform vec3 albedo_const;
uniform bool use_albedo_tex;

uniform sampler2D normal_map;
uniform vec3 normal_const;
uniform bool use_normal_tex;

uniform sampler2D metalness_map;
uniform float metalness_const;
uniform bool use_metalness_tex;

uniform sampler2D roughness_map;
uniform float roughness_const;
uniform bool use_roughness_tex;

uniform sampler2D ao_map;
uniform float ao_const;
uniform bool use_ao_tex;

uniform sampler2D luminance_map;
uniform vec3 luminance_const;
uniform bool use_luminance_tex;

uniform vec3 light_color;
uniform float light_power;
uniform vec3 light_position_m;
uniform vec3 eye_position_m;
uniform bool wireframe;

uniform float light_extent;
uniform samplerCube depth_map;

float calculate_shadow(vec3 frag_pos)
{
    vec3 frag_to_light = frag_pos - light_position_m;
    float closest_depth = texture(depth_map, frag_to_light).r;
    closest_depth *= light_extent;
    float frag_depth = length(frag_to_light);
    
    float epsilon = 0.05;
    float shadow = frag_depth - bias > closest_depth ? 1.0 : 0.0;
    
    return shadow;
}

const float PI = 3.14159265359;

struct Material
{
    vec3 albedo;
    vec3 normal;
    float metalness;
    float roughness;
    float ao;
    vec3 luminance;
    vec3 F0;
};

Material get_material()
{
    Material m;
    if (use_albedo_tex) m.albedo = pow(texture(albedo_map, frag.uv).rgb, vec3(2.2));
    else                m.albedo = pow(albedo_const, vec3(2.2));
    if (use_normal_tex) m.normal = frag.TBN * texture(normal_map, frag.uv).rgb;
    else                m.normal = frag.TBN * normal_const;
    if (use_metalness_tex) m.metalness = texture(metalness_map, frag.uv).r;
    else                   m.metalness = metalness_const;
    if (use_roughness_tex) m.roughness = texture(roughness_map, frag.uv).r;
    else                   m.roughness = roughness_const;
    if (use_ao_tex) m.ao = texture(ao_map, frag.uv).r;
    else            m.ao = ao_const;
    if (use_luminance_tex) m.luminance = texture(luminance_map, frag.uv).rgb;
    else                   m.luminance = luminance_const;
    m.F0 = vec3(0.04);
    m.F0 = mix(m.F0, m.albedo, m.metalness);
    
    return m;
}

vec3 fresnel_schlick(float cos_theta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cos_theta, 5.0);
}

float distribution_GGX(vec3 N, vec3 H, float roughness)
{
    float a = roughness * roughness;
    float a2 = a*a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;
    
    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
    
    return num / denom;
}

float geometry_SchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;
    
    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    
    return num / denom;
}

float geometry_Smith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    
    float ggx2 = geometry_SchlickGGX(NdotV, roughness);
    float ggx1 = geometry_SchlickGGX(NdotL, roughness);
    
    return ggx1 * ggx2;
}

vec3 reflectance(Material m, vec3 light_col, vec3 light_pos)
{
    vec3 N = m.normal;
    vec3 L = normalize(light_pos - frag.position_m);
    vec3 V = normalize(eye_position_m);
    vec3 H = normalize(V + L);
    float cos_theta = max(dot(N, L), 0.0);
    
    float dist = length(light_pos - frag.position_m);
    float attenuation = 1.0 / (dist * dist);
    vec3 radiance = light_col * attenuation * cos_theta;
    
    vec3 F = fresnel_schlick(max(dot(H, V), 0.0), m.F0);
    
    float D = distribution_GGX(N, H, m.roughness);
    float G = geometry_Smith(N, V, L, m.roughness);
    
    vec3 num = F * D * G;
    float denom = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0);
    vec3 specular = num / max(denom, 0.001);
    
    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    
    kD = mix(kD, vec3(0), m.metalness);
    //kD = kD * m.metalness;
    
    float NdotL = max(dot(N, L), 0.0);
    
    vec3 diffuse = kD * m.albedo;
    // vec3 diffuse = kD * albedo_const;
    return (diffuse + specular) * radiance * NdotL;
}

void main()
{
    // float pixels = 128.0;
    // float d = 15 * (1/pixels);
    // vec2 pix_uv = d * floor(frag.uv/d);
    Material material = get_material();
    if (shaded)
    {
        vec3 Lo = reflectance(material, light_color*light_power*10, light_position_m);
        
        // Ambient Lighting
        
        vec3 ambient = vec3(0.03) * material.albedo * material.ao;
        float shadow = calculate_shadow(frag.position_m);
        color = ambient + (1.0 - shadow) * Lo;
        
        vec3 frag_to_light = frag.position_m - light_position_m;
        float closest_depth = texture(depth_map, frag_to_light).r;
        color = vec4(vec3(closest_depth), 1.0);
    }
    else
    {
        color = material.albedo;
    }
    // HDR tonemapping
    color = color / (color + vec3(1.0));
    // Gamma Correction
    color = pow(color, vec3(1.0/2.2));
    
    float nearD = min(min(edge_dist.x, edge_dist.y), edge_dist.z);
    float edge_intensity = exp2(-1.0*nearD*nearD);
    vec3 edge_color = vec3(1, 0, 0);
    float edge_thickness = 0.5;
    if (wireframe)
        color = mix(color, edge_color, edge_intensity*edge_thickness);
}

