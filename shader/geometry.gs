#version 330 core

layout (triangles) in;
layout (triangle_strip, max_vertices = 12) out;
uniform mat4 P;
struct vert_data
{
    vec2 uv;
    vec3 position_m;
    vec3 normal_mv;
    vec3 eye_direction_mv;
    vec3 light_direction_mv;

    vec3 eye_direction_tbn;
    vec3 light_direction_tbn;
};
in vec3 normal[];
in vec3 position[];
in mat4 mvp_mat[];
in vert_data vert[];
out vert_data frag;

void main()
{
    vec4 avg_normal = mvp_mat[0]*vec4(normalize(normal[0]+normal[1]+normal[2]),0);
    vec4 tri_centroid =
        (gl_in[0].gl_Position + gl_in[1].gl_Position + gl_in[2].gl_Position)/3.0f;

    for (int i = 0; i < 3; i++)
    {
        frag = vert[i];
        gl_Position = gl_in[i].gl_Position;
        EmitVertex();
    }
    EndPrimitive();

    {
        frag = vert[0];
        gl_Position = tri_centroid+vec4(-0.1, -0.1, 0, 0);
        EmitVertex();
        frag = vert[0];
        gl_Position = tri_centroid+(avg_normal);
        EmitVertex();
        frag = vert[0];
        gl_Position = tri_centroid+vec4(0, 0.1, 0, 0);
        EmitVertex();
    }
    EndPrimitive();

    {
        frag = vert[1];
        gl_Position = tri_centroid+vec4(0, 0.1, 0, 0);
        EmitVertex();
        frag = vert[1];
        gl_Position = tri_centroid+(avg_normal);
        EmitVertex();
        frag = vert[1];
        gl_Position = tri_centroid+vec4(0.1, -0.1, 0, 0);
        EmitVertex();
    }
    EndPrimitive();

    {
        frag = vert[2];
        gl_Position = tri_centroid+vec4(0.1, -0.1, 0, 0);
        EmitVertex();
        frag = vert[2];
        gl_Position = tri_centroid+(avg_normal);
        EmitVertex();
        frag = vert[2];
        gl_Position = tri_centroid+vec4(-0.1, -0.1, 0, 0);
        EmitVertex();
    }
    EndPrimitive();
}
