package rendering

using import "core:math"
using import "core:fmt"

import "core:os"
import "core:strings"
import "shared:gl"

using import "../util"

Mesh :: struct
{
    vertices   : [dynamic]Vec3,
    uvs        : [dynamic]Vec2,
    normals    : [dynamic]Vec3,
    tangents   : [dynamic]Vec3,
    bitangents : [dynamic]Vec3,

    indexed    : bool,
    indices    : [dynamic]u16,

    vao        : u32,

    vbuff      : u32,
    uvbuff     : u32,
    nbuff      : u32,
    tbuff      : u32,
    btbuff     : u32,
    ebuff      : u32,
}

init_mesh :: proc() -> Mesh
{
    m: Mesh;

    m.vertices   = make([dynamic]Vec3);
    m.uvs        = make([dynamic]Vec2);
    m.normals    = make([dynamic]Vec3);
    m.tangents   = make([dynamic]Vec3);
    m.bitangents = make([dynamic]Vec3);
    m.indices    = make([dynamic]u16);

    return m;
}

load_obj :: proc(filepath : string) -> Mesh
{
    file_buf, ok := os.read_entire_file(filepath);
    if !ok
    {
        eprintf("Couldn't open .obj %q for reading\n", filepath);
        return Mesh{};
    }
    file := string(file_buf);
    m := init_mesh();

    vert_indices := make([dynamic]u16);
    norm_indices := make([dynamic]u16);
    uv_indices   := make([dynamic]u16);
    
    temp_verts := make([dynamic]Vec3);
    temp_norms := make([dynamic]Vec3);
    temp_uvs   := make([dynamic]Vec2);
    
    for
    {
        header: string;
        if !read_ident(&file, &header) do
            break;

        if header == "v"
        {
            vert := Vec3{};
            read_fmt(&file, "%f %f %f\n", &vert.x, &vert.y, &vert.z);
            append(&temp_verts, vert);
        }
        else if header == "vn"
        {
            norm := Vec3{};
            read_fmt(&file, "%f %f %f\n", &norm.x, &norm.y, &norm.z);
            append(&temp_norms, norm);
        }
        else if header == "vt"
        {
            uv := Vec2{};
            read_fmt(&file, "%f %f\n", &uv.x, &uv.y);
            append(&temp_uvs, uv);
        }
        else if header == "f"
        {
            vi, ni, uvi : [3]u16;
            read_fmt(&file, "%d/%d/%d %d/%d/%d %d/%d/%d\n",
                     &vi[0], &uvi[0], &ni[0],
                     &vi[1], &uvi[1], &ni[1],
                     &vi[2], &uvi[2], &ni[2]
                    );
            append_elems(&vert_indices, ..vi[:]);
            append_elems(&norm_indices, ..ni[:]);
            append_elems(&uv_indices,   ..uvi[:]);
        }
    }

    for v in vert_indices do
        append(&m.vertices, temp_verts[v-1]);
    for n in norm_indices do
        append(&m.normals, temp_norms[n-1]);
    for uv in uv_indices do
        append(&m.uvs, temp_uvs[uv-1]);

    delete(temp_verts);
    delete(temp_norms);
    delete(temp_uvs);

    delete(vert_indices);
    delete(norm_indices);
    delete(uv_indices);

    return m;
}

is_near :: proc(v1: f32, v2: f32) -> bool
{
    return abs(v1-v2) < 0.01;
}

_get_similar_vertex :: proc(vert: Vec3, norm: Vec3, uv: Vec2, verts: []Vec3, norms: []Vec3, uvs: []Vec2) -> (u16, bool)
{
    for _, i in verts
    {
        if  is_near(vert.x, verts[i].x) &&
            is_near(vert.y, verts[i].y) &&
            is_near(vert.z, verts[i].z) &&
            is_near(norm.x, norms[i].x) &&
            is_near(norm.y, norms[i].y) &&
            is_near(norm.z, norms[i].z) &&
            is_near(uv.x,   uvs  [i].x) &&
            is_near(uv.y,   uvs  [i].y)
        {
            return u16(i), true;
        }
    }

    return 0, false;
}

index_mesh :: proc(m: ^Mesh)
{
    temp_verts := make([dynamic]Vec3);
    temp_norms := make([dynamic]Vec3);
    temp_uvs   := make([dynamic]Vec2);

    temp_tangents   := make([dynamic]Vec3);
    temp_bitangents := make([dynamic]Vec3);

    for _, i in m.vertices
    {
        index, found := _get_similar_vertex(m.vertices[i], m.normals[i], m.uvs[i],
                                            temp_verts[:], temp_norms[:], temp_uvs[:]);

        if found
        {
            append(&m.indices, index);
            temp_tangents[index]   += m.tangents[i];
            temp_bitangents[index] += m.bitangents[i];
        }
        else
        {
            append(&temp_verts,      m.vertices[i]);
            append(&temp_norms,      m.normals[i]);
            append(&temp_uvs,        m.uvs[i]);
            append(&temp_tangents,   m.tangents[i]);
            append(&temp_bitangents, m.bitangents[i]);

            new_index := u16(len(temp_verts)-1);
            append(&m.indices, new_index);
        }
    }

    delete(m.vertices);
    delete(m.normals);
    delete(m.uvs);
    delete(m.tangents);
    delete(m.bitangents);

    m.vertices   = temp_verts;
    m.normals    = temp_norms;
    m.uvs        = temp_uvs;
    m.tangents   = temp_tangents;
    m.bitangents = temp_bitangents;

    m.indexed = true;
}

_compute_tangent_basis_indexed :: proc(m: ^Mesh)
{
    reserve(&m.tangents,   len(m.vertices));
    resize (&m.tangents,   len(m.vertices));

    i := 0;
    for i < len(m.indices)
    {
        i0 := m.indices[i+0];
        i1 := m.indices[i+1];
        i2 := m.indices[i+2];

        v0 := m.vertices[i0];
        v1 := m.vertices[i1];
        v2 := m.vertices[i2];

        uv0 := m.uvs[i0];
        uv1 := m.uvs[i1];
        uv2 := m.uvs[i2];

        delta_pos0 := v1 - v0;
        delta_pos1 := v2 - v0;

        delta_uv0 := uv1 - uv0;
        delta_uv1 := uv2 - uv0;

        r: f32 = 1.0 / (delta_uv0.x*delta_uv1.y - delta_uv0.y*delta_uv1.x);

        tangent := (delta_pos0*delta_uv1.y - delta_pos1*delta_uv0.y) * r;

        m.tangents[i0] = tangent;
        m.tangents[i1] = tangent;
        m.tangents[i2] = tangent;
        
        i += 3;
    }
}

_compute_tangent_basis_unindexed :: proc(m: ^Mesh)
{
    i := 0;
    
    for i < len(m.vertices)
    {
        v0 := m.vertices[i+0];
        v1 := m.vertices[i+1];
        v2 := m.vertices[i+2];

        uv0 := m.uvs[i+0];
        uv1 := m.uvs[i+1];
        uv2 := m.uvs[i+2];

        delta_pos0 := v1 - v0;
        delta_pos1 := v2 - v0;

        delta_uv0 := uv1 - uv0;
        delta_uv1 := uv2 - uv0;

        r: f32 = 1.0 / (delta_uv0.x*delta_uv1.y - delta_uv0.y*delta_uv1.x);

        tangent := (delta_pos0*delta_uv1.y - delta_pos1*delta_uv0.y) * r;

        append(&m.tangents, tangent);
        append(&m.tangents, tangent);
        append(&m.tangents, tangent);
    }
}

compute_tangent_basis :: proc(m: ^Mesh)
{
    if (m.indexed) do _compute_tangent_basis_indexed(m);
    else do           _compute_tangent_basis_unindexed(m);

    for _, i in m.vertices
    {
        t := &m.tangents[i];
        n := m.normals[i];

        t^ = norm(t^ - n * dot(n, t^));
        append(&m.bitangents, cross(n, t^));
    }
}

create_mesh_vbos :: proc(m: ^Mesh)
{
    gl.GenBuffers(1, &m.vbuff);
    gl.BindBuffer(gl.ARRAY_BUFFER, m.vbuff);
    gl.BufferData(gl.ARRAY_BUFFER, len(m.vertices)*size_of(Vec3), &m.vertices[0], gl.STATIC_DRAW);

    gl.GenBuffers(1, &m.uvbuff);
    gl.BindBuffer(gl.ARRAY_BUFFER, m.uvbuff);
    gl.BufferData(gl.ARRAY_BUFFER, len(m.uvs)*size_of(Vec2), &m.uvs[0], gl.STATIC_DRAW);

    gl.GenBuffers(1, &m.nbuff);
    gl.BindBuffer(gl.ARRAY_BUFFER, m.nbuff);
    gl.BufferData(gl.ARRAY_BUFFER, len(m.normals)*size_of(Vec3), &m.normals[0], gl.STATIC_DRAW);

    gl.GenBuffers(1, &m.tbuff);
    gl.BindBuffer(gl.ARRAY_BUFFER, m.tbuff);
    gl.BufferData(gl.ARRAY_BUFFER, len(m.tangents)*size_of(Vec3), &m.tangents[0], gl.STATIC_DRAW);

    gl.GenBuffers(1, &m.btbuff);
    gl.BindBuffer(gl.ARRAY_BUFFER, m.btbuff);
    gl.BufferData(gl.ARRAY_BUFFER, len(m.bitangents)*size_of(Vec3), &m.bitangents[0], gl.STATIC_DRAW);

    if m.indexed
    {
        gl.GenBuffers(1, &m.ebuff);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, m.ebuff);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(m.indices)*size_of(u16), &m.indices[0], gl.STATIC_DRAW);
    }
}

invert_uvs :: proc(m: ^Mesh)
{
    for _, i in m.uvs do
        m.uvs[i].y = 1.0 - m.uvs[i].y;
}

make_mesh :: proc(filepath: string, normals: bool, invert_uv: bool) -> Mesh
{
    mesh := load_obj(filepath);
    if normals do compute_tangent_basis(&mesh);
    index_mesh(&mesh);
    if invert_uv do invert_uvs(&mesh);

    return mesh;
}

draw_model :: proc(s: Shader, m: Mesh)
{
    gl.EnableVertexAttribArray(0);
    gl.BindBuffer(gl.ARRAY_BUFFER, m.vbuff);

    gl.VertexAttribPointer(
        0,        // attribute 0
        3,        // size
        gl.FLOAT, // type
        gl.FALSE, // normalized?
        0,        // stride
        nil       // array buffer offset
    );

    gl.EnableVertexAttribArray(1);
    gl.BindBuffer(gl.ARRAY_BUFFER, m.uvbuff);
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 0, nil);

    gl.EnableVertexAttribArray(2);
    gl.BindBuffer(gl.ARRAY_BUFFER, m.nbuff);
    gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 0, nil);
    
    gl.EnableVertexAttribArray(3);
    gl.BindBuffer(gl.ARRAY_BUFFER, m.tbuff);
    gl.VertexAttribPointer(3, 3, gl.FLOAT, gl.FALSE, 0, nil);

    gl.EnableVertexAttribArray(4);
    gl.BindBuffer(gl.ARRAY_BUFFER, m.btbuff);
    gl.VertexAttribPointer(4, 3, gl.FLOAT, gl.FALSE, 0, nil);

    if m.indexed
    {
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, m.ebuff);
        gl.DrawElements(gl.TRIANGLES, i32(len(m.indices)), gl.UNSIGNED_SHORT, nil);
    }
    else
    {
        gl.DrawArrays(gl.TRIANGLES, 0, i32(len(m.vertices)));
    }

    gl.DisableVertexAttribArray(0); // vbuff
    gl.DisableVertexAttribArray(1); // uvbuff
    gl.DisableVertexAttribArray(2); // nbuff
    gl.DisableVertexAttribArray(3); // tbuff
    gl.DisableVertexAttribArray(4); // btbuff
}

delete_model :: proc (m: ^Mesh)
{
    delete(m.vertices);
    delete(m.uvs);
    delete(m.normals);
    delete(m.indices);
    delete(m.tangents);
    delete(m.bitangents);

    m.vertices   = nil;
    m.uvs        = nil;
    m.normals    = nil;
    m.indices    = nil;
    m.tangents   = nil;
    m.bitangents = nil;
}
