package rendering

import "shared:gl"

debug_texture :: proc(shader: ^Shader, texture: u32)
{
    verts := [?][3]f32{
        {-50, -50, 0},
        { 50, -50, 0},
        { 50,  50, 0},
        
        {-50, -50, 0},
        { 50,  50, 0},
        {-50,  50, 0},
    };
    
    uvs := [?][2]f32{
        {0, 0},
        {1, 0},
        {1, 1},
        
        {0, 0},
        {1, 1},
        {0, 1},
    };
    
    vao: u32;
    gl.GenVertexArrays(1, &vao);
    gl.BindVertexArray(vao);
    
    vbuff, uvbuff: u32;
    gl.GenBuffers(1, &vbuff);
    gl.EnableVertexAttribArray(0);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbuff);
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 0, nil);
    gl.BufferData(gl.ARRAY_BUFFER, 6*size_of([3]f32), &verts[0], gl.STATIC_DRAW);
    
    gl.GenBuffers(1, &uvbuff);
    gl.EnableVertexAttribArray(1);
    gl.BindBuffer(gl.ARRAY_BUFFER, uvbuff);
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 0, nil);
    gl.BufferData(gl.ARRAY_BUFFER, 6*size_of([2]f32), &uvs[0], gl.STATIC_DRAW);
    
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D, texture);
    set_uniform(shader, "diffuse_sampler", 0);
    
    gl.DrawArrays(gl.TRIANGLES, 0, 6);
    /*
        gl.DeleteBuffers(1, &vbuff);
        gl.DeleteBuffers(1, &uvbuff);
        gl.DeleteVertexArrays(1, &vao);
    */
}

debug_cubemap :: proc(shader: ^Shader, texture: u32)
{
    
}