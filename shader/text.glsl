@version 430 core

@vertex

uniform ivec2 resolution;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 vertex_uv;

out vec3 uv;

void main()
{
    vec2 position_homogeneous = position.xy - (resolution/2);
    position_homogeneous /= (resolution/2);
    gl_Position = vec4(position_homogeneous, 0, 1);
    
    uv = vertex_uv;
}

@fragment

in vec3 uv;

uniform sampler2DArray texture_sampler;
uniform float px_range;

out vec4 color;

float median(vec3 texel)
{
    return max(min(texel.r, texel.g), min(max(texel.r, texel.g), texel.b));
}

void main()
{
	vec3 s = texture(texture_sampler, uv).rgb;
	float sig_dist = median(s) - 0.5;
    
    float opacity = clamp(sig_dist/fwidth(sig_dist) + 0.5, 0.0, 1.0);
    
    color = vec4(1, 1, 1, opacity);
}

@fragment
