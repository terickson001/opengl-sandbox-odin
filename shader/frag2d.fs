#version 330 core

in vec2 uv;

uniform sampler2D diffuse_sampler;

out vec4 color;

void main()
{
    color = texture(diffuse_sampler, uv);
}
