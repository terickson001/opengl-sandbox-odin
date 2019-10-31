#version 330 core

uniform ivec2 resolution;

layout(location = 0) in vec3 position;
layout(location = 1) in vec2 vertex_uv;

out vec2 uv;

void main()
{
    vec2 position_homogeneous = position.xy - (resolution/2);
    position_homogeneous /= (resolution/2);
    gl_Position = vec4(position_homogeneous, position.z/1024, 1);

    uv = vertex_uv;
}
