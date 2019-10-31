#version 330 core

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
	vec2 msdf_unit = px_range / vec2(textureSize(texture_sampler, 0));
	vec3 s = texture(texture_sampler, uv).rgb;
	float sig_dist = median(s) - 0.5;
	sig_dist *= dot(msdf_unit, 0.5 / fwidth(uv.xy));
    float opacity = clamp(sig_dist + 0.5, 0.0, 1.0);
    
    color = vec4(1, 1, 1, opacity);
}
