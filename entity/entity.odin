package entity

import "core:fmt"
import "core:math"
import "core:math/linalg"

import "shared:gl"
import "../asset/model"

import render "../rendering"

Entity_Group :: struct
{
    entities: [dynamic]^Entity
}

Entity :: struct
{
    name  : string,
    mesh  : ^render.Mesh "noinspect",
    // tex   : ^render.Texture "noinspect",
    material: ^render.Material,
    pos   : [3]f32,
    dir   : [3]f32,
    scale : [3]f32,
    
    wireframe: bool "noinspect",
    bounds: AABB "noinspect",
}
Entity_3D :: Entity;

Entity_2D :: struct
{
    sprite : ^render.Sprite,
    pos    : [2]f32,
    scale  : [2]f32,
    angle  : f32,
}

make_entity :: proc(name: string, m: ^render.Mesh, mat: ^render.Material, pos: [3]f32 = {0, 0, 0}, dir: [3]f32 = {0, 0, 1}) -> (e: Entity)
{
    fmt.printf("Making entity %q\n", name);
    e.name = name;
    e.mesh = m;
    e.material = mat;
    e.pos = pos;
    e.dir = linalg.normalize(dir);
    e.bounds = get_mesh_bounds(m);
    
    return;
}

entity_transform :: proc(using e: Entity) -> [4][4]f32
{
    
    translate := cast([4][4]f32)linalg.matrix4_translate(
                                                         cast(linalg.Vector3)pos
                                                         );
    
    rotate := cast([4][4]f32)linalg.MATRIX4_IDENTITY;
    {
        right := linalg.cross(dir, [3]f32{0, 1, 0});
        if right == {0, 0, 0} do right = linalg.cross(dir, [3]f32{0, 0, 1});
        up := linalg.cross(right, dir);
        quat := linalg.quaternion_look_at(
                                          cast(linalg.Vector3)(pos),
                                          cast(linalg.Vector3)(pos+dir),
                                          cast(linalg.Vector3)(up)
                                          );
        rotate = cast([4][4]f32)linalg.matrix4_from_quaternion(quat);
    }
    
    transform := linalg.mul(translate, rotate);
    return transform;
}

draw_entity :: proc(s: ^render.Shader, using e: Entity)
{
    M := entity_transform(e);
    
    gl.VertexAttrib4fv(5, &M[0][0]);
    gl.VertexAttrib4fv(6, &M[1][0]);
    gl.VertexAttrib4fv(7, &M[2][0]);
    gl.VertexAttrib4fv(8, &M[3][0]);
    
    render.set_uniform(s, "wireframe", e.wireframe);
    
    render.set_material(s, material);
    render.draw_model(s, mesh);
}

get_bounds :: proc(using e: Entity) -> AABB
{
    M := entity_transform(e);
    
    using linalg;
    world_bounds := bounds;
    world_bounds.lbb = mul(M, world_bounds.lbb);
    world_bounds.rtf = mul(M, world_bounds.rtf);
    return world_bounds;
}

make_entity_2d :: proc(s: ^render.Sprite, pos, scale: [2]f32) -> (e: Entity_2D)
{
    e.sprite = s;
    e.pos = pos;
    e.scale = scale;
    
    return e;
}

draw_entity_2d :: proc(s: ^render.Shader, using e: ^Entity_2D)
{
    render.draw_sprite(s, sprite, pos, scale);
}

update_entity_2d :: proc(using e: ^Entity_2D, dt: f32)
{
    render.update_sprite(sprite, dt);
}
