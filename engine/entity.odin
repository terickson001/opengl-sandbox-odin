package engine

import "core:fmt"
import "core:math"
import "core:math/linalg"

import "shared:gl"

Entity_Group :: struct
{
    entities: [dynamic]^Entity
}

Entity :: struct
{
    name  : string,
    mesh  : ^Mesh "noinspect",
    material: ^Material,
    pos   : [3]f32,
    rot   : quaternion128,
    scale : [3]f32,
    
    wireframe: bool "noinspect",
    bounds: AABB "noinspect",
}
Entity_3D :: Entity;

Entity_2D :: struct
{
    sprite : ^Sprite,
    pos    : [2]f32,
    scale  : [2]f32,
    angle  : f32,
}

make_entity :: proc(name: string, m: ^Mesh, mat: ^Material, pos: [3]f32 = {0, 0, 0}, dir: [3]f32 = {0, 0, 1}, scale: [3]f32 = {1, 1, 1}) -> (e: Entity)
{
    // @hack(Tyler): Compiler bug workaround (Issue #831)
    {
        q := quaternion128{};
        hack := q == quaternion128{};
    }
    e.name = name;
    e.mesh = m;
    e.material = mat;
    e.pos = pos;
    {
        right := linalg.cross(dir, [3]f32{0, 1, 0});
        if right == {0, 0, 0} do right = linalg.cross(dir, [3]f32{0, 0, 1});
        up := linalg.cross(right, dir);
        
        e.rot = cast(quaternion128)linalg.quaternion_look_at(
                                                             cast(linalg.Vector3f32)(pos),
                                                             cast(linalg.Vector3f32)(pos+dir),
                                                             cast(linalg.Vector3f32)(up)
                                                             );
    }
    e.bounds = get_mesh_bounds(m);
    e.scale = scale;
    return;
}

entity_transform :: proc(using e: Entity) -> [4][4]f32
{
    using linalg;
    translate := matrix4_translate(cast(Vector3f32)pos);
    rotate    := matrix4_from_quaternion(cast(Quaternionf32)rot);
    scale_mat := matrix4_scale(cast(Vector3f32)scale);
    
    transform := mul(translate, mul(rotate, scale_mat));
    return cast([4][4]f32)transform;
}

draw_entity :: proc(s: ^Shader, using e: Entity)
{
    M := entity_transform(e);
    
    set_uniform(s, "M", M);
    
    set_uniform(s, "wireframe", e.wireframe);
    
    set_material(s, material);
    draw_model(s, mesh);
}

entity_get_bounds :: proc(using e: Entity) -> AABB
{
    M := entity_transform(e);
    return transform_aabb(bounds, M);
}

make_entity_2d :: proc(s: ^Sprite, pos, scale: [2]f32) -> (e: Entity_2D)
{
    e.sprite = s;
    e.pos = pos;
    e.scale = scale;
    
    return e;
}

draw_entity_2d :: proc(s: ^Shader, using e: ^Entity_2D)
{
    draw_sprite(s, sprite, pos, scale);
}

update_entity_2d :: proc(using e: ^Entity_2D, dt: f32)
{
    update_sprite(sprite, dt);
}
