package engine

import "core:math/rand"
import "core:mem"
import "core:fmt"
import "core:math/linalg"

Scene :: struct
{
    camera: Camera,
    base_entities: map[string]Entity,
    entities: [dynamic]Entity,
}

make_scene :: proc(allocator := context.allocator) -> Scene
{
    scene: Scene;
    scene.base_entities = make(T=map[string]Entity, allocator=allocator);
    scene.entities = make([dynamic]Entity, allocator);
    return scene;
}

scene_add_entity :: proc(scene: ^Scene, entity: Entity) -> int
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

scene_register_entity :: proc(scene: ^Scene, entity: Entity)
{
    base := entity;
    base.pos = {0, 0, 0};
    base.scale = {1, 1, 1};
    scene.base_entities[entity.name] = base;
}

scene_render :: proc(scene: ^Scene, shader: ^Shader)
{
    for e in scene.entities 
    {
        draw_entity(shader, e);
    }
}

world_to_clip :: proc(scene: ^Scene, worldspace: [3]f32) -> [3]f32
{
    using linalg;
    cameraspace := mul(scene.camera.view, nvec(4, worldspace));
    clipspace := mul(scene.camera.projection, cameraspace);
    return nvec(3, clipspace);
}

clip_to_world :: proc(scene: ^Scene, clipspace: [3]f32) -> [3]f32
{
    using linalg;
    cameraspace := mul(matrix4_inverse(cast(Matrix4)scene.camera.projection), nvec(4, clipspace));
    worldspace  := mul(matrix4_inverse(cast(Matrix4)scene.camera.view), cameraspace);
    return nvec(3, worldspace);
}