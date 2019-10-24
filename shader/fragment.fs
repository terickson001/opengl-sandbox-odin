#version 330 core

in vec2 uv;
in vec3 normal_mv;
in vec3 eye_direction_mv;
in vec3 light_direction_mv;
in vec3 eye_direction_tbn;
in vec3 light_direction_tbn;
in vec3 position_m;

out vec3 color;

uniform sampler2D diffuse_sampler;
uniform sampler2D normal_sampler;
uniform sampler2D specular_sampler;
uniform bool use_normal;
uniform bool use_specular;

uniform vec3 light_color;
uniform float light_power;
uniform vec3 light_position_m;

void main()
{
    vec3 material_diffuse_color = texture(diffuse_sampler, uv).rgb;
    vec3 material_ambient_color = vec3(0.1, 0.1, 0.1) * material_diffuse_color;
    vec3 material_specular_color;
    if (use_specular)
        material_specular_color = texture(specular_sampler, uv).rgb * 0.3;
    else
        material_specular_color = vec3(0.3, 0.3, 0.3);

    float dist = length(light_position_m - position_m);

    vec3 n, l, E;
    if (use_normal)
    {
        n = normalize(texture(normal_sampler, vec2(uv.x, -uv.y)).rgb*2.0 - 1.0);
        l = normalize(light_direction_tbn);
        E = normalize(eye_direction_tbn);
    }
    else
    {
        n = normalize(normal_mv);
        l = normalize(light_direction_mv);
        E = normalize(eye_direction_mv);
    }
    vec3 R = reflect(-l, n);
    float cos_theta = clamp(dot(n, l), 0, 1);
    float cos_alpha = clamp(dot(E, R), 0, 1);

    color = 
        // Ambient : simulates indirect lighting
        material_ambient_color +
        // Diffuse : "color" of the object
        material_diffuse_color * light_color * light_power * cos_theta / (dist*dist) +
        // Specular : reflective highlight, like a mirror
        material_specular_color * light_color * light_power * pow(cos_alpha, 5) / (dist*dist);
}
