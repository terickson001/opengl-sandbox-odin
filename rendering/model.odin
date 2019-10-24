package rendering

using import "core:math"
using import "core:strconv"

import "core:os"

import "../util"

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
    m := init_mesh();

    for
    {
        
    }

    return m;
}
