
package rendering

import "core:fmt"
import "shared:gl"
import "core:mem"

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
    vertices    : []f32,
    uvs         : []f32,
    normals     : []f32,
    
    v_stride    : int,
    uv_stride   : int,
    n_stride    : int,
}

Batch :: struct
{
    shader          : Shader,
    texture         : Texture,
    blending        : bool,
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
    for _, i in layers
    {
        for _, j in layers[i]
        {
            delete(layers[i][j].vertices);
            delete(layers[i][j].uvs);
            delete(layers[i][j].normals);
        }
            
        resize(&layers[i], 0);
    }
}

add_batch :: proc(renderer: ^Renderer, layer: int, shader: Shader, tex: Texture, blending: bool, verts: [][$A]f32, uvs: [][$B]f32, norms: [][$C]f32)
{
    batch := Batch{};
    batch.shader = shader;
    batch.texture = tex;
    batch.blending = blending;
    
    batch.vertices = mem.slice_data_cast([]f32, verts);
    batch.uvs      = mem.slice_data_cast([]f32, uvs);
    batch.normals  = mem.slice_data_cast([]f32, norms);
    
    batch.v_stride  = A;
    batch.uv_stride = B;
    batch.n_stride  = C;

    append(&renderer.layers[layer], batch);;
}

@private
draw_batch :: proc(using renderer: ^Renderer, using batch: ^Batch)
{
    if len(vertices) > 0
    {
        gl.BindBuffer(gl.ARRAY_BUFFER, vbuff);
        gl.BufferData(gl.ARRAY_BUFFER, len(vertices)*size_of(f32), &vertices[0], gl.STATIC_DRAW);
    }

    if len(uvs) > 0
    {
        gl.BindBuffer(gl.ARRAY_BUFFER, uvbuff);
        gl.BufferData(gl.ARRAY_BUFFER, len(uvs)*size_of(f32), &uvs[0], gl.STATIC_DRAW);
    }

    if len(normals) > 0
    {
        gl.BindBuffer(gl.ARRAY_BUFFER, nbuff);
        gl.BufferData(gl.ARRAY_BUFFER, len(normals)*size_of(f32), &normals[0], gl.STATIC_DRAW);
    }

    gl.UseProgram(shader.id);
    
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(texture.type, texture.diffuse);

    gl.Uniform2i(shader.uniforms.resolution, shader_data.resolution.x, shader_data.resolution.y);
    gl.Uniform1i(shader.uniforms.diffuse_sampler, 0);

    if len(vertices) > 0
    {
        gl.EnableVertexAttribArray(0);
        gl.BindBuffer(gl.ARRAY_BUFFER, vbuff);
        gl.VertexAttribPointer(0, i32(v_stride), gl.FLOAT, gl.FALSE, 0, nil);
    }

    if len(uvs) > 0
    {
        gl.EnableVertexAttribArray(1);
        gl.BindBuffer(gl.ARRAY_BUFFER, uvbuff);
        gl.VertexAttribPointer(1, i32(uv_stride), gl.FLOAT, gl.FALSE, 0, nil);
    }

    if len(uvs) > 0
    {
        gl.EnableVertexAttribArray(2);
        gl.BindBuffer(gl.ARRAY_BUFFER, nbuff);
        gl.VertexAttribPointer(2, i32(n_stride), gl.FLOAT, gl.FALSE, 0, nil);
    }
    
    if blending
    {
        gl.Enable(gl.BLEND);
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    }

    vertex_count := 0;
    if len(vertices) > 0 do vertex_count = max(len(vertices)/v_stride);
    if len(uvs) > 0 do      vertex_count = max(len(uvs)     /uv_stride);
    if len(normals) > 0 do  vertex_count = max(len(normals) /n_stride);
    
    gl.DrawArrays(gl.TRIANGLES, 0, i32(vertex_count));

    if blending do          gl.Disable(gl.BLEND);
    if len(vertices) > 0 do gl.DisableVertexAttribArray(0);
    if len(uvs) > 0 do      gl.DisableVertexAttribArray(1);
    if len(normals) > 0 do  gl.DisableVertexAttribArray(2);
}

draw_layer :: proc(using renderer: ^Renderer, idx: int)
{
    for _, b in layers[idx] do
        draw_batch(renderer, &layers[idx][b]); 
}

draw_all :: proc(using renderer: ^Renderer)
{
    for _, i in layers do
        draw_layer(renderer, i);
}
