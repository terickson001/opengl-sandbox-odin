package engine

import "core:math/linalg"

Ray :: struct
{
    origin: [3]f32,
    dir: [3]f32,
}

AABB :: struct
{
    lbb: [4]f32,
    rtf: [4]f32,
}

Plane :: struct
{
    center: [3]f32,
    normal: [3]f32,
}

get_mesh_bounds :: proc(mesh: ^Mesh) -> AABB
{
    using box: AABB;
    for v in mesh.vertices
    {
        if      v.x < lbb.x do lbb.x = v.x;
        else if v.x > rtf.x do rtf.x = v.x;
        if      v.y < lbb.y do lbb.y = v.y;
        else if v.y > rtf.y do rtf.y = v.y;
        if      v.z < lbb.z do lbb.z = v.z;
        else if v.z > rtf.z do rtf.z = v.z;
    }
    lbb.w = 1.0;
    rtf.w = 1.0;
    return box;
}

transform_aabb :: proc(aabb: AABB, transform: [4][4]f32) -> AABB
{
    r, t, f, l, b, B: f32;
    {
        using aabb;
        r = rtf.x;
        t = rtf.y;
        f = rtf.z;
        l = lbb.x;
        b = lbb.y;
        B = lbb.z;
    }
    verts := [8][4]f32{
        {l, t, f, 1},
        {l, t, B, 1},
        {r, t, B, 1},
        {r, t, f, 1},
        {l, b, f, 1},
        {l, b, B, 1},
        {r, b, B, 1},
        {r, b, f, 1},
    };
    
    ret: AABB;
    for v in &verts
    {
        v = linalg.mul(transform, v);
        using ret;
        if      v.x < lbb.x do lbb.x = v.x;
        else if v.x > rtf.x do rtf.x = v.x;
        if      v.y < lbb.y do lbb.y = v.y;
        else if v.y > rtf.y do rtf.y = v.y;
        if      v.z < lbb.z do lbb.z = v.z;
        else if v.z > rtf.z do rtf.z = v.z;
    }
    ret.lbb.w = 1.0;
    ret.rtf.w = 1.0;
    return ret;
}

cast_ray_aabb :: proc(ray: Ray, box: AABB) -> (t: f32, result: bool)
{
    frac := 1/ray.dir;
    
    t1 := (box.lbb.x - ray.origin.x) * frac.x;
    t2 := (box.rtf.x - ray.origin.x) * frac.x;
    t3 := (box.lbb.y - ray.origin.y) * frac.y;
    t4 := (box.rtf.y - ray.origin.y) * frac.y;
    t5 := (box.lbb.z - ray.origin.z) * frac.z;
    t6 := (box.rtf.z - ray.origin.z) * frac.z;
    
    tmin := max(max(min(t1, t2), min(t3, t4)), min(t5, t6));
    tmax := min(min(max(t1, t2), max(t3, t4)), max(t5, t6));
    
    if tmax < 0 do    return tmax, false;
    if tmin > tmax do return tmax, false;
    
    return tmin, true;
}

cast_ray_plane :: proc(ray: Ray, plane: Plane) -> (t: f32, result: bool)
{
    denom := linalg.dot(plane.normal, ray.dir);
    if abs(denom) >= 0.0001
    {
        t := linalg.dot(plane.center - ray.origin, plane.normal) / denom;
        if t >= 0 do return t, true;
    }
    return 0, false;
}

cast_ray_triangles :: proc(ray: Ray, using e: Entity) -> (t: f32, result: bool)
{
    transform := entity_transform(e);
    using linalg;
    if mesh.indexed
    {
        for i in 0..<(len(mesh.indices)/3)
        {
            a := mesh.vertices[mesh.indices[i*3+0]];
            b := mesh.vertices[mesh.indices[i*3+1]];
            c := mesh.vertices[mesh.indices[i*3+2]];
            
            aw := nvec(3, mul(cast(Matrix4f32)transform, [4]f32{a.x, a.y, a.z, 1}));
            bw := nvec(3, mul(cast(Matrix4f32)transform, [4]f32{b.x, b.y, b.z, 1}));
            cw := nvec(3, mul(cast(Matrix4f32)transform, [4]f32{c.x, c.y, c.z, 1}));
            
            t, succ := test_triangle(ray, aw, bw, cw);
            if succ do return t, succ;
        }
    }
    else
    {
        for i in 0..<(len(mesh.vertices)/3)
        {
            a := mesh.vertices[i*3+0];
            b := mesh.vertices[i*3+1];
            c := mesh.vertices[i*3+2];
            aw := nvec(3, mul(cast(Matrix4f32)transform, [4]f32{a.x, a.y, a.z, 1}));
            bw := nvec(3, mul(cast(Matrix4f32)transform, [4]f32{b.x, b.y, b.z, 1}));
            cw := nvec(3, mul(cast(Matrix4f32)transform, [4]f32{c.x, c.y, c.z, 1}));
            t, succ := test_triangle(ray, aw, bw, cw);
            if succ do return t, succ;
        }
    }
    return 0, false;
    
    // Möller–Trumbore
    test_triangle :: proc(ray: Ray, v1, v2, v3: [3]f32) -> (t: f32, result: bool)
    {
        using linalg;
        EPSILON :: 0.0000001;
        
        e1 := v2-v1;
        e2 := v3-v1;
        
        h := cross(ray.dir, e2);
        a := dot(e1, h);
        if a > -EPSILON && EPSILON > a do return 0, false;
        
        f := 1.0/a;
        s := ray.origin - v1;
        u := f * dot(s, h);
        if u < 0.0 || u > 1.0 do return 0, false;
        
        q := cross(s, e1);
        v := f * dot(ray.dir, q);
        if v < 0.0 || u + v > 1.0 do return 0, false;
        
        t = f * dot(e2, q);
        if t < EPSILON do return t, false;
        return t, true;
    }
}