
package rendering

import "core:fmt"
import "shared:gl"
import "core:mem"
import "core:intrinsics"
import "core:runtime"

/* MAX_DEPTH :: 32; */

/* Renderer :: struct */
/* { */
/*     vbuff       : u32, */
/*     uvbuff      : u32, */
/*     nbuff       : u32, */
/*     layers      : [MAX_DEPTH][dynamic]Batch, */
/* } */

/* Render_Proc :: proc(batch: Batch); */

/* Buffer :: struct */
/* { */
/*     data      : rawptr, */
/*     count     : int, */
/*     elem_size : int, */
/*     stride    : int, */
/*     location  : u32, */
/*     is_attr   : bool, */
/* } */
/* make_buffer :: proc(slice: []$T, location: u32, is_attr := true) -> Buffer */
/* { */
/*     buff := Buffer{}; */
    
/*     buff.data      = &slice[0]; */
/*     buff.count     = len(slice); */
/*     buff.elem_size = size_of(T); */
/*     buff.location  = location; */
/*     buff.is_attr   = is_attr; */
/*     when intrinsics.type_is_array(T) do */
/*         buff.stride = type_info_of(T).variant.(runtime.Type_Info_Array).count; */
/*     return buff; */
/* } */

Context :: struct
{
    vao :   u32,
    vbo : []u32,
    sbo : []u32,
    ebo :   u32,
}

make_context :: proc(num_vbos: u32, num_sbos: u32, has_ebo := false) -> (ctx: Context)
{
    using ctx;
    
    gl.GenVertexArrays(1, &vao);
    
    if num_vbos > 0
    {
        vbo = make([]u32, num_vbos);
        for _, i in vbo do vbo[i] = ~u32(0);
    }
    
    if num_sbos > 0
    {
        sbo = make([]u32, num_sbos);
        gl.GenBuffers(i32(num_sbos), &sbo[0]);
    }

    if has_ebo do
        gl.GenBuffers(1, &ebo);
    
    return ctx;
}

bind_context :: proc(using ctx: Context)
{
    gl.BindVertexArray(vao);
}

@private
gl_type :: proc($T: typeid) -> u32
{
    switch T
    {
        case f64: return gl.DOUBLE;
        case f32: return gl.FLOAT;
        
        case u32: return gl.UNSIGNED_INT;
        case u16: return gl.UNSIGNED_SHORT;
        case u8:  return gl.UNSIGNED_BYTE;
    }
}

init_vbo :: proc{init_vbo_arr, init_vbo_basic};
init_vbo_arr :: proc(using ctx: Context, vbo_idx: int, $T: typeid/[$N]$V)
{
    gl.GenBuffers(1, &vbo[vbo_idx]);
    gl.EnableVertexAttribArray(u32(vbo_idx));
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo[vbo_idx]);
    
    type := gl_type(V);
    stride := N;
    
    gl.VertexAttribPointer(u32(vbo_idx), stride, type, gl.FALSE, 0, nil);
}
init_vbo_basic :: proc(using ctx: Context, vbo_idx: int, $T: typeid)
{
    gl.GenBuffers(1, &vbo[vbo_idx]);
    gl.EnableVertexAttribArray(u32(vbo_idx));
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo[vbo_idx]);
    
    type := gl_type(T);
    stride := i32(1);
    
    gl.VertexAttribPointer(u32(vbo_idx), stride, type, gl.FALSE, 0, nil);
}


update_vbo :: proc(using ctx: Context, vbo_idx: int, data: []$T)
{
    if vbo[vbo_idx] == ~u32(0)
    {
        gl.GenBuffers(1, &vbo[vbo_idx]);
        gl.EnableVertexAttribArray(u32(vbo_idx));
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo[vbo_idx]);

        type := u32(gl.FLOAT);
        stride := i32(1);
        when intrinsics.type_is_array(T)
        {
            stride = len(T);
            when      type_of(data[0]) == f32 do type = gl.FLOAT;
            else when type_of(data[0]) == u8  do type = gl.UNSIGNED_BYTE;
        }
        else
        {
            switch T
            {
                case f32: type = gl.FLOAT;
                case u8:  type = gl.UNSIGNED_BYTE;
            }
        }
        gl.VertexAttribPointer(u32(vbo_idx), stride, type, gl.FALSE, 0, nil);
    }
    else
    {
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo[vbo_idx]);
    }
    
    gl.BufferData(gl.ARRAY_BUFFER, len(data)*size_of(T), &data[0], gl.STATIC_DRAW);
}

update_ebo :: proc(using ctx: Context, data: []u16)
{
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(data)*size_of(u16), &data[0], gl.STATIC_DRAW);
}

delete_context :: proc(using ctx: Context)
{
    gl.DeleteBuffers(i32(len(vbo)), &vbo[0]);
    delete(vbo);
}
