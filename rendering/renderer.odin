
package rendering

import "core:fmt"
import "shared:gl"
import "core:mem"
import "core:intrinsics"
import "core:runtime"

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
    
    if has_ebo 
    {
        gl.GenBuffers(1, &ebo);
    }
    
    return ctx;
}

bind_context :: proc(using ctx: ^Context)
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
        
        case i32: return gl.INT;
        case i16: return gl.SHORT;
        case i8:  return gl.BYTE;
    }
}

init_vbo :: proc{init_vbo_array, init_vbo_basic};
init_vbo_array :: proc(using ctx: ^Context, vbo_idx: int, $T: typeid/[$N]$V)
{
    gl.GenBuffers(1, &vbo[vbo_idx]);
    gl.EnableVertexAttribArray(u32(vbo_idx));
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo[vbo_idx]);
    
    type := gl_type(V);
    stride := N;
    
    gl.VertexAttribPointer(u32(vbo_idx), stride, type, gl.FALSE, 0, nil);
}
init_vbo_basic :: proc(using ctx: ^Context, vbo_idx: int, $T: typeid)
{
    gl.GenBuffers(1, &vbo[vbo_idx]);
    gl.EnableVertexAttribArray(u32(vbo_idx));
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo[vbo_idx]);
    
    type := gl_type(T);
    stride := i32(1);
    
    gl.VertexAttribPointer(u32(vbo_idx), stride, type, gl.FALSE, 0, nil);
}


update_vbo :: proc(using ctx: ^Context, vbo_idx: int, data: []$T)
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

update_ebo :: proc(using ctx: ^Context, data: []u16)
{
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(data)*size_of(u16), &data[0], gl.STATIC_DRAW);
}

delete_context :: proc(using ctx: ^Context)
{
    if vbo != nil
    {
        gl.DeleteBuffers(i32(len(vbo)), &vbo[0]);
        delete(vbo);
    }
    
    if sbo != nil
    {
        gl.DeleteBuffers(i32(len(sbo)), &sbo[0]);
        delete(sbo);
    }
    
    if ebo != ~u32(0) 
    {
        gl.DeleteBuffers(1, &ebo);
    }
}
