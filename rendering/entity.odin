package rendering

import "core:math"
import "core:math/linalg"

import "shared:gl"

Entity :: struct
{
    mesh       : ^Mesh,
    tex        : ^Texture,
    pos        : [3]f32,
    dir        : [3]f32,
    scale      : [3]f32,
}
Entity_3D :: Entity;

Entity_2D :: struct
{
    sprite : ^Sprite,
    pos    : [2]f32,
    scale  : [2]f32,
    angle  : f32,
}

make_entity :: proc(m: ^Mesh, t: ^Texture, pos, dir: [3]f32) -> (e: Entity)
{
    e.mesh = m;
    e.tex = t;
    e.pos  = pos;
    e.dir  = linalg.normalize(dir);
    return;
}

entity_transform :: proc(using e: Entity) -> [4][4]f32
{
    translate := cast([4][4]f32)linalg.matrix4_translate(
        cast(linalg.Vector3)pos
    );

    rotate: [4][4]f32;
    {
        right := linalg.cross(dir, [3]f32{0, 1, 0});
        up := linalg.cross(right, dir);
        rotate = cast([4][4]f32)linalg.matrix4_look_at(
            cast(linalg.Vector3)pos,
            cast(linalg.Vector3)(pos+dir),
            cast(linalg.Vector3)up);
    }

    return translate * rotate;
}

draw_entity :: proc(s: Shader, using e: Entity)
{
    M := entity_transform(e);

    gl.VertexAttrib4fv(5, &M[0][0]);
    gl.VertexAttrib4fv(6, &M[1][0]);
    gl.VertexAttrib4fv(7, &M[2][0]);
    gl.VertexAttrib4fv(8, &M[3][0]);

    activate_texture(s, tex^);
    draw_model(s, mesh^);
    disable_texture(s, tex^);
}


make_entity_2d :: proc(s: ^Sprite, pos, scale: [2]f32) -> (e: Entity_2D)
{
    e.sprite = s;
    e.pos = pos;
    e.scale = scale;

    return e;
}

draw_entity_2d :: proc(s: Shader, using e: ^Entity_2D)
{
    draw_sprite(s, sprite, pos, scale);
}

update_entity_2d :: proc(using e: ^Entity_2D)
{
    update_sprite(sprite);
}
