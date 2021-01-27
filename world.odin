package main

import "core:math/rand"
import "core:mem"
import "core:fmt"

import core "engine"

gen_wall :: proc(dims: [3]f32) -> core.Mesh
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
            orig_face := core.cube_verts[cube_idx:];
            orig_norms := core.cube_normals[cube_idx:];
            orig_uvs := core.cube_uvs[cube_idx:];
            
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
    
    mesh: core.Mesh;
    
    mesh.vertices = vertices;
    mesh.normals = normals;
    mesh.uvs = uvs;
    
    core.compute_tangent_basis(&mesh);
    core.index_mesh(&mesh);
    core.create_mesh_vbos(&mesh);
    
    return mesh;
}
