#version 430 core

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
