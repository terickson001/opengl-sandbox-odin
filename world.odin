package main

import "core:math/rand"
import render "rendering"
import "core:mem"
import "core:fmt"

import "entity"

Scene :: struct
{
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

scene_add_entity :: proc(scene: ^Scene, entity: entity.Entity)
{
    if entity.name not_in scene.base_entities
    {
        base := entity;
        base.pos = {0, 0, 0};
        base.scale = {1, 1, 1};
        scene.base_entities[entity.name] = entity;
    }
    append(&scene.entities, entity);
}

render_scene :: proc(scene: ^Scene, shader: ^render.Shader)
{
    for e in scene.entities 
    {
        entity.draw_entity(shader, e);
    }
}

gen_wall :: proc(dims: [3]f32) -> render.Mesh
{
    assert(dims.x > 0 && dims.y > 0 && dims.z > 0);
    offset := -dims/2;
    
    v_count := int((dims.x*dims.y*2 + dims.y*dims.z*2 + dims.z*dims.x*2) * 6);
    
    vertices := make([][3]f32, v_count);
    v_buff := mem.buffer_from_slice(vertices);
    
    normals := make([][3]f32, v_count);
    n_buff := mem.buffer_from_slice(normals);
    
    uvs:= make([][2]f32, v_count);
    uv_buff := mem.buffer_from_slice(uvs);
    
    
    for _, i in dims
    {
        a := int(dims[(i+1)%3]);
        b := int(dims[(i+2)%3]);
        
        for s in 0..1
        {
            cube_idx := ((i*2)+s)*4;
            orig_face := render.cube_verts[cube_idx:];
            orig_norms := render.cube_normals[cube_idx:];
            orig_uvs := render.cube_uvs[cube_idx:];
            
            face := [4][3]f32{orig_face[0], orig_face[1], orig_face[2], orig_face[3]};
            for v in &face do v = (v+1)/2;
            
            for tile in 0..<a*b
            {
                trans := [3]f32{};
                if s == 0 do trans[i] = dims[i]-1;
                trans[(i+1)%3] = f32(tile%a);
                trans[(i+2)%3] = f32(tile/a);
                for v in ([6]int{0, 1, 2, 1, 3, 2})
                {
                    append(&v_buff, face[v] + trans + offset);
                    append(&n_buff, orig_norms[v]);
                    append(&uv_buff, orig_uvs[v]);
                }
            }
        }
    }
    
    mesh: render.Mesh;
    
    mesh.vertices = vertices;
    mesh.normals = normals;
    mesh.uvs = uvs;
    
    render.compute_tangent_basis(&mesh);
    render.index_mesh(&mesh);
    render.create_mesh_vbos(&mesh);
    
    return mesh;
}
