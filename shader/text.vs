#version 330 core

layout(location = 0) in vec2 position;
layout(location = 1) in vec2 vertex_uv;

out vec4 gl_Position;
out vec2 uv;

void main()
{
    vec2 position_homogeneous = position - vec2(400, 300);
    position_homogeneous /= vec2(400, 300);
    gl_Position = vec4(position_homogeneous, 0, 1);

    uv = vertex_uv;
}
