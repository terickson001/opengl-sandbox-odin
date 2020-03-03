
package rendering

import "core:fmt"
import "shared:gl"
import "core:mem"
import "core:intrinsics"
import "core:runtime"

MAX_DEPTH :: 32;

Renderer :: struct
{
    vbuff       : u32,
    uvbuff      : u32,
    nbuff       : u32,
    layers      : [MAX_DEPTH][dynamic]Batch,
}

Render_Proc :: proc(batch: Batch);

Buffer :: struct
{
    data      : rawptr,
    count     : int,
    elem_size : int,
    stride    : int,
    location  : u32,
    is_attr   : bool,
}
make_buffer :: proc(slice: []$T, location: u32, is_attr := true) -> Buffer
{
    buff := Buffer{};
    
    buff.data      = &slice[0];
    buff.count     = len(slice);
    buff.elem_size = size_of(T);
    buff.location  = location;
    buff.is_attr   = is_attr;
    when intrinsics.type_is_array(T) do
        buff.stride = type_info_of(T).variant.(runtime.Type_Info_Array).count;
    return buff;
}

Render_Context :: struct
{
    vao: u32,
    vbos: []u32,
}

Batch :: struct
{
    shader      : ^Shader,
    texture     : ^Texture,
    render_proc : Render_Proc,
    uniforms    : map[string]rawptr,
    num_vertices: int,
    data        : [dynamic][]Buffer,
}

init_renderer :: proc() -> Renderer
{
    using r: Renderer;

    for _, i in layers do
        layers[i] = make([dynamic]Batch);

    gl.GenBuffers(3, &vbuff);
    
    return r;
}

begin_render :: proc(using renderer: ^Renderer)
{
    for _, i in layers
    {
        for _, j in layers[i] do
            delete_batch(layers[i][j]);
            
        resize(&layers[i], 0);
    }
}

delete_batch :: proc(using batch: Batch)
{
    /* for buffers in data do */
    /*     for _, i in buffers do */
    /*         free(buffers[i].data); */
    // delete(data);
    // delete(uniforms);
}

add_batch :: proc(using renderer: ^Renderer, layer: int, shader: ^Shader, texture: ^Texture, render_proc: Render_Proc, data: []Buffer)
{
    /* for b, i in layers[layer] */
    /* { */
    /*     if b.shader == shader */
    /*         && b.texture == texture */
    /*         && b.render_proc == render_proc */
    /*     { */
    /*         layers[layer][i].num_vertices += data[0].count; */
    /*         append(&layers[layer][i].data, data); */
    /*         return; */
    /*     } */
    /* } */
    batch := Batch{};
    batch.shader = shader;
    batch.texture = texture;
    batch.render_proc = render_proc;
    batch.num_vertices = data[0].count;
    append(&batch.data, data);

    append(&renderer.layers[layer], batch);
}

@private
draw_batch :: proc(using renderer: ^Renderer, using batch: ^Batch)
{
    for _, b in batch.data[0]
    {
        size := batch.data[0][b].elem_size;
        location := batch.data[0][b].location;
        gl.BindBuffer(gl.ARRAY_BUFFER, shader.buffers[location]);
        gl.BufferData(gl.ARRAY_BUFFER, num_vertices*size, nil, gl.DYNAMIC_DRAW);
        off := 0;
        for buffers in batch.data
        {
            gl.BufferSubData(gl.ARRAY_BUFFER, off, buffers[b].count*size, buffers[b].data);
            off += buffers[b].count * size;
        }

        if batch.data[0][b].is_attr
        {
            gl.EnableVertexAttribArray(u32(location));
            gl.VertexAttribPointer(u32(location), i32(batch.data[0][b].stride), gl.FLOAT, gl.FALSE, 0, nil);
        }
    }

    gl.UseProgram(shader.id);
    
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(texture.type, texture.diffuse);

    gl.Uniform2i(shader.uniforms["resolution"], 1024, 768);//shader_data.resolution.x, shader_data.resolution.y);
    gl.Uniform1i(shader.uniforms["diffuse_sampler"], 0);
    
    /* if blending */
    /* { */
        gl.Enable(gl.BLEND);
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    /* } */

    /* vertex_count := 0; */
    /* if len(vertices) > 0 do vertex_count = max(len(vertices)/v_stride); */
    /* if len(uvs) > 0 do      vertex_count = max(len(uvs)     /uv_stride); */
    /* if len(normals) > 0 do  vertex_count = max(len(normals) /n_stride); */
    
    gl.DrawArrays(gl.TRIANGLES, 0, i32(batch.num_vertices));

    /* if blending          do gl.Disable(gl.BLEND); */
    gl.Disable(gl.BLEND);

    for _, b in batch.data[0]
    {
        location := batch.data[0][b].location;
        if batch.data[0][b].is_attr do
            gl.DisableVertexAttribArray(location);
    }
    /* if len(vertices) > 0 do gl.DisableVertexAttribArray(0); */
    /* if len(uvs) > 0      do gl.DisableVertexAttribArray(1); */
    /* if len(normals) > 0  do gl.DisableVertexAttribArray(2); */
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
