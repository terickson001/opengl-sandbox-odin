
package rendering

import "core:fmt"
import "shared:gl"

MAX_DEPTH :: 32;

Renderer :: struct
{
    shader_data : Shader_Data,
    vbuff       : u32,
    uvbuff      : u32,
    nbuff       : u32,
    layers      : [MAX_DEPTH][dynamic]Batch,
}

Tri_Data :: struct
{
    vertices    : [][3]f32,
    uvs         : [][2]f32,
    normals     : [][3]f32,
}

Batch :: struct
{
    shader          : Shader,
    texture         : Texture,
    using triangles : Tri_Data,
}

init_renderer :: proc() -> Renderer
{
    using r: Renderer;

    for _, i in layers do
        layers[i] = make([dynamic]Batch);

    return r;
}

begin_render :: proc(using renderer: ^Renderer)
{
    for _, i in layers do
        resize(&layers[i], 0);
}

@private
draw_batch :: proc(using renderer: ^Renderer, using batch: ^Batch)
{
    if len(vertices) > 0
    {
        gl.BindBuffer(gl.ARRAY_BUFFER, vbuff);
        gl.BufferData(gl.ARRAY_BUFFER, 6*size_of([3]f32), &vertices[0], gl.STATIC_DRAW);
    }

    if len(uvs) > 0
    {
        gl.BindBuffer(gl.ARRAY_BUFFER, uvbuff);
        gl.BufferData(gl.ARRAY_BUFFER, 6*size_of([2]f32), &uvs[0], gl.STATIC_DRAW);
    }

    gl.UseProgram(shader.id);
    
    gl.ActiveTexture(gl.TEXTURE0);
    // gl.BindTexture(texture.type, texture.diffuse);

    gl.Uniform2iv(shader.uniforms.resolution, 2, &shader_data.resolution[0]);
    gl.Uniform1i(shader.uniforms.diffuse_sampler, 0);

    gl.EnableVertexAttribArray(0);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbuff);
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 0, nil);

    gl.EnableVertexAttribArray(1);
    gl.BindBuffer(gl.ARRAY_BUFFER, uvbuff);
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 0, nil);

    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    gl.DrawArrays(gl.TRIANGLES, 0, 6);
    
    gl.Disable(gl.BLEND);

    gl.DisableVertexAttribArray(0);
    gl.DisableVertexAttribArray(1);
}

draw_layer :: proc(using renderer: ^Renderer)
{
    
}
