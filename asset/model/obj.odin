package model

import "../../util"
import "core:os"
import "core:fmt"

load_obj_from_mem :: proc(data: []byte) -> Mesh
{
    file := string(data);
    m := Mesh{};
    
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
