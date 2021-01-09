package rendering

import "core:math"
import "core:math/linalg"
import "core:fmt"

import "core:os"
import "core:strings"
import "shared:gl"

import "../util"

Model :: struct
{
    mesh: Mesh,
    animations: []Keyframed_Animation
}

Mesh :: struct
{
    vertices   : [][3]f32,
    uvs        : [][2]f32,
    normals    : [][3]f32,
    tangents   : [][3]f32,
    bitangents : [][3]f32,
    
    indexed    : bool,
    indices    : []u16,
    
    using ctx: Context,
}

init_mesh :: proc() -> Mesh
{
    m: Mesh;
    
    /*
         m.vertices   = make([dynamic][3]f32);
        m.uvs        = make([dynamic][2]f32);
        m.normals    = make([dynamic][3]f32);
    */
    
    // m.tangents   = make([dynamic][3]f32);
    // m.bitangents = make([dynamic][3]f32);
    // m.indices    = make([dynamic]u16);
    
    return m;
}

load_obj_from_mem :: proc(data: []byte) -> Mesh
{
    file := string(data);
    m := init_mesh();
    
    vert_indices := make([dynamic]u16);
    norm_indices := make([dynamic]u16);
    uv_indices   := make([dynamic]u16);
    
    temp_verts := make([dynamic][3]f32);
    temp_norms := make([dynamic][3]f32);
    temp_uvs   := make([dynamic][2]f32);
    
    defer
    {
        delete(temp_verts);
        delete(temp_norms);
        delete(temp_uvs);
        
        delete(vert_indices);
        delete(norm_indices);
        delete(uv_indices);
    }
    
    for len(file) > 0
    {
        if file[0] == '#'
        {
            util.read_line(&file, nil);
            continue;
        }
        
        header: string;
        if !util.read_fmt(&file, "%s ", &header) 
        {
            break;
        }
        
        if header == "v"
        {
            vert := [3]f32{};
            util.read_fmt(&file, "%f %f %f%>", &vert.x, &vert.y, &vert.z);
            append(&temp_verts, vert);
        }
        else if header == "vn"
        {
            norm := [3]f32{};
            util.read_fmt(&file, "%f %f %f%>", &norm.x, &norm.y, &norm.z);
            
            append(&temp_norms, norm);
        }
        else if header == "vt"
        {
            uv := [2]f32{};
            util.read_fmt(&file, "%f %f%>", &uv.x, &uv.y);
            append(&temp_uvs, uv);
        }
        else if header == "f"
        {
            vi, ni, uvi : [3]u16;
            util.read_fmt(&file, "%d/%d/%d %d/%d/%d %d/%d/%d%>",
                          &vi[0], &uvi[0], &ni[0],
                          &vi[1], &uvi[1], &ni[1],
                          &vi[2], &uvi[2], &ni[2]
                          );
            append(&vert_indices, ..vi[:]);
            append(&norm_indices, ..ni[:]);
            append(&uv_indices,   ..uvi[:]);
        }
        else if header == "s" || header == "usemtl"
        {
            util.read_line(&file, nil);
        }
    }
    
    m.vertices = make([][3]f32, len(vert_indices));
    m.normals = make([][3]f32, len(norm_indices));
    m.uvs = make([][2]f32, len(uv_indices));
    
    for v, i in vert_indices 
    {
        m.vertices[i] = temp_verts[v-1];
    }
    for n, i in norm_indices 
    {
        m.normals[i] = temp_norms[n-1];
    }
    for uv, i in uv_indices 
    {
        m.uvs[i] = temp_uvs[uv-1];
    }
    
    return m;
}

load_obj :: proc(filepath : string) -> Mesh
{
    data, ok := os.read_entire_file(filepath);
    if !ok
    {
        fmt.eprintf("Couldn't open .obj %q for reading\n", filepath);
        return Mesh{};
    }
    
    return load_obj_from_mem(data);
}

is_near :: inline proc(v1: f32, v2: f32) -> bool
{
    return abs(v1-v2) < 0.01;
}

_get_similar_vertex :: proc(vert: [3]f32, norm: [3]f32, uv: [2]f32, verts: [][3]f32, norms: [][3]f32, uvs: [][2]f32) -> (u16, bool)
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
    indices := make([dynamic]u16);
    
    temp_verts := make([dynamic][3]f32);
    temp_norms := make([dynamic][3]f32);
    temp_uvs   := make([dynamic][2]f32);
    
    temp_tangents   := make([dynamic][3]f32);
    temp_bitangents := make([dynamic][3]f32);
    
    for _, i in m.vertices
    {
        index, found := _get_similar_vertex(m.vertices[i], m.normals[i], m.uvs[i],
                                            temp_verts[:], temp_norms[:], temp_uvs[:]);
        
        if found
        {
            append(&indices, index);
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
            append(&indices, new_index);
        }
    }
    
    delete(m.vertices);
    delete(m.normals);
    delete(m.uvs);
    delete(m.tangents);
    delete(m.bitangents);
    
    m.vertices   = temp_verts[:];
    m.normals    = temp_norms[:];
    m.uvs        = temp_uvs[:];
    m.tangents   = temp_tangents[:];
    m.bitangents = temp_bitangents[:];
    m.indices    = indices[:];
    
    m.indexed = true;
}

_compute_tangent_basis_indexed :: proc(m: ^Mesh)
{
    m.tangents = make([][3]f32, len(m.vertices));
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
    m.tangents = make([][3]f32, len(m.vertices));
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
        
        m.tangents[i] = tangent;
        m.tangents[i+1] = tangent;
        m.tangents[i+2] = tangent;
        
        i += 3;
    }
}

compute_tangent_basis :: proc(m: ^Mesh)
{
    if m.indexed do _compute_tangent_basis_indexed(m);
    else do         _compute_tangent_basis_unindexed(m);
    
    m.bitangents = make([][3]f32, len(m.vertices));
    for _, i in m.vertices
    {
        t := &m.tangents[i];
        n := m.normals[i];
        
        t^ = linalg.normalize(t^ - n * linalg.dot(n, t^));
        m.bitangents[i] = linalg.cross(n, t^);
    }
}

create_mesh_vbos :: proc(using m: ^Mesh)
{
    ctx = make_context(5, 0, indexed);
    
    bind_context(&ctx);
    
    update_vbo(&ctx, 0, vertices[:]);
    update_vbo(&ctx, 1, uvs[:]);
    update_vbo(&ctx, 2, normals[:]);
    update_vbo(&ctx, 3, tangents[:]);
    update_vbo(&ctx, 4, bitangents[:]);
    
    if indexed 
    {
        update_ebo(&ctx, indices[:]);
    }
}

invert_uvs :: proc(m: ^Mesh)
{
    for _, i in m.uvs 
    {
        m.uvs[i].y = 1.0 - m.uvs[i].y;
    }
}

make_mesh :: proc(filepath: string, normals: bool, invert_uv: bool) -> Mesh
{
    mesh := load_obj(filepath);
    if normals do compute_tangent_basis(&mesh);
    index_mesh(&mesh);
    if invert_uv do invert_uvs(&mesh);
    
    return mesh;
}

draw_model :: proc(s: ^Shader, m: ^Mesh)
{
    bind_context(&m.ctx);
    
    if m.indexed 
    {
        gl.DrawElements(gl.TRIANGLES, i32(len(m.indices)), gl.UNSIGNED_SHORT, nil);
    }
    else 
    {
        gl.DrawArrays(gl.TRIANGLES, 0, i32(len(m.vertices)));
    }
}

delete_model :: proc (m: ^Mesh)
{
    delete_context(&m.ctx);
    
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