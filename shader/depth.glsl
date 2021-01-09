@version 430 core

@vertex
layout(location = 0) in vec3 position;

uniform mat4 M;

void main()
{
    gl_Position = M * vec4(position, 1);
}

@geometry
layout(triangles) in;
layout(triangle_strip, max_vertices=18) out;

uniform mat4 shadow_matrices[6];

out vec4 frag_pos;

void main()
{
    for (int face = 0; face < 6; face++)
    {
        gl_Layer = face;
        for (int i = 0; i < 3; i++)
        {
            frag_pos = gl_in[i].gl_Position;
            gl_Position = shadow_matrices[face] * frag_pos;
            EmitVertex();
        }
        EndPrimitive();
    }
}

@fragment

in vec4 frag_pos;

uniform vec3 light_pos;
uniform float far_plane;

void main()
{
    float dist = length(frag_pos.xyz - light_pos);
    dist = dist / far_plane;
    gl_FragDepth = dist;
}