package scene

import "core:math/rand"
import render "../rendering"
import "core:mem"
import "core:fmt"
import "core:math/linalg"

import "../entity"
import "../util"
Scene :: struct
{
    camera: render.Camera,
    base_entities: map[string]entity.Entity,
    entities: [dynamic]entity.Entity,
}

make_scene :: proc(allocator := context.allocator) -> Scene
{
    scene: Scene;
    scene.base_entities = make(T=map[string]entity.Entity, allocator=allocator);
    scene.entities = make([dynamic]entity.Entity, allocator);
    return scene;
}

add_entity :: proc(scene: ^Scene, entity: entity.Entity) -> int
{
    if entity.name not_in scene.base_entities
    {
        base := entity;
        base.pos = {0, 0, 0};
        base.scale = {1, 1, 1};
        scene.base_entities[entity.name] = base;
    }
    append(&scene.entities, entity);
    return len(scene.entities)-1;
}

add_camera :: proc(scn: ^Scene, cam: render.Camera)
{
    scn.camera = cam;
}

register_entity :: proc(scene: ^Scene, entity: entity.Entity)
{
    base := entity;
    base.pos = {0, 0, 0};
    base.scale = {1, 1, 1};
    scene.base_entities[entity.name] = base;
}

render :: proc(scene: ^Scene, shader: ^render.Shader)
{
    for e in scene.entities 
    {
        entity.draw_entity(shader, e);
    }
}

world_to_clip :: proc(scene: ^Scene, worldspace: [3]f32) -> [3]f32
{
    using util;
    using linalg;
    cameraspace := mul(scene.camera.view, nvec(4, worldspace));
    clipspace := mul(scene.camera.projection, cameraspace);
    return nvec(3, clipspace);
}

clip_to_world :: proc(scene: ^Scene, clipspace: [3]f32) -> [3]f32
{
    using util;
    using linalg;
    cameraspace := mul(matrix4_inverse(cast(Matrix4)scene.camera.projection), nvec(4, clipspace));
    worldspace  := mul(matrix4_inverse(cast(Matrix4)scene.camera.view), cameraspace);
    return nvec(3, worldspace);
}