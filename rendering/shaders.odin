package rendering

import "core:fmt"
import "shared:gl"
import "core:os"
import "core:strings"
import "core:mem"
import "core:intrinsics"

import "../util"

Shader :: struct
{
    id: u32,
    time: os.File_Time,

    vs_filepath: string,
    fs_filepath: string,

    uniforms : map[string]i32,
    buffers  : [dynamic]u32
}

set_uniform :: proc(using s: ^Shader, name: string, val: $T)
{
    location, found := uniforms[name];
    if !found
    {
        fmt.eprintf("ERROR: Shader does not have uniform %q\n", name);
        os.exit(1);
    }

    E :: intrinsics.type_elem_type(T);
    N :: size_of(T) / size_of(E);
    when intrinsics.type_is_integer(E)
    {
        when intrinsics.type_is_unsigned(E)
        {
            when      N == 1 do gl.Uniform1ui(location, u32(val));
            else when N == 2 do gl.Uniform2ui(location, u32(val[0]), u32(val[1]));            
            else when N == 3 do gl.Uniform3ui(location, u32(val[0]), u32(val[1]), u32(val[2]));
            else when N == 4 do gl.Uniform4ui(location, u32(val[0]), u32(val[1]), u32(val[2]), u32(val[3]));
        }
        else
        {
            when      N == 1 do gl.Uniform1i(location, i32(val));
            else when N == 2 do gl.Uniform2i(location, i32(val[0]), i32(val[1]));            
            else when N == 3 do gl.Uniform3i(location, i32(val[0]), i32(val[1]), i32(val[2]));      
            else when N == 4 do gl.Uniform4i(location, i32(val[0]), i32(val[1]), i32(val[2]), i32(val[3]));
            
        }
    }
    else when intrinsics.type_is_float(E)
    {
        when      N == 1 do gl.Uniform1f(location, f32(val));
        else when N == 2 do gl.Uniform2f(location, f32(val[0]), f32(val[1]));            
        else when N == 3 do gl.Uniform3f(location, f32(val[0]), f32(val[1]), f32(val[2]));      
        else when N == 4 do gl.Uniform4f(location, f32(val[0]), f32(val[1]), f32(val[2]), f32(val[3]));
    }
    else when intrinsics.type_is_array(E)
    {
        when      N == 2 { temp := val; gl.UniformMatrix2fv(location, 1, gl.FALSE, &temp[0][0]); }
        else when N == 3 { temp := val; gl.UniformMatrix3fv(location, 1, gl.FALSE, &temp[0][0]); }
        else when N == 4 { temp := val; gl.UniformMatrix4fv(location, 1, gl.FALSE, &temp[0][0]); }
    }
}

/*
uniform :: struct
{
    name: string,
    location: i32,
    type: typeid,
}

Buffer :: struct
{
    name: string,
    location: i32,
    type: typeid,
}

Shader_Interface :: struct
{
    uniforms: map[string]Uniform,
    buffers: map[string]Buffer,
}
*/

parse_shader :: proc(using shader: ^Shader, source: []byte, buff: ^strings.Builder = nil) -> ^strings.Builder
{
    using util;

    buff := buff;
    top_level := false;
    if buff == nil
    {
        top_level = true;
        buff = new_clone(strings.make_builder());
    }
    
    file := string(source[:]);
    ident: string;
    line: string;
    for len(file) > 0
    {
        write := true;
        read_line(&file, &line);
        line_orig := line[:];
        if !top_level && strings.has_prefix(line, "#version")
        {
            write = false;
        }
        else if read_fmt(&line, "@%s%_", &ident)
        {
            write = false;
            switch ident
            {
            case "import":
                imported: string;
                if !read_string(&line, &imported)
                {
                    fmt.eprintf("ERROR: Could not read filename after @import\n");
                    os.exit(1);
                }
                
                imp_data, ok := os.read_entire_file(imported);
                if !ok
                {
                    fmt.eprintf("ERROR: Could not open @import'ed file %q\n", imported);
                    os.exit(1);
                }

                parse_shader(shader, imp_data, buff);
                
            case:
                fmt.eprintf("ERROR: Invalid attribute '@%s' in shader\n", ident);
                os.exit(1);
            }
        }
        else if read_fmt(&line, "%s%_", &ident)
        {
            switch ident
            {
            case "layout":
                loc := -1;
                name: string;
                if !read_fmt(&line, "%_(location%_=%_%d)%_in%_%^s%_%s%_;", &loc, &name)
                {
                    fmt.eprintf("ERROR: Couldn't parse shader attribute\n");
                    os.exit(1);
                }
                if len(buffers) < loc+1 do
                    resize(&buffers, loc+1);
                
            case "uniform":
                name: string;
                if !read_fmt(&line, "%_%^s%_%s%_;", &name)
                {
                    fmt.eprintf("ERROR: Couldn't parse shader uniform\n");
                    os.exit(1);
                }
                uniforms[name] = -1;
            }
        }
        
        if write
        {
            strings.write_string(buff, line_orig);
            strings.write_byte(buff, '\n');
        }
            
    }

    return buff;
}

compile_shader :: proc(filepath: string, code: []byte, kind: u32) -> u32
{
    id := gl.CreateShader(kind);
    
    result := i32(gl.FALSE);
    info_log_length: i32;

    // Compile
    fmt.printf("Compiling shader: %s\n", filepath);
    source := &code[0];
    length := i32(len(code));
    gl.ShaderSource(id, 1, &source, &length);
    gl.CompileShader(id);

    // Check
    gl.GetShaderiv(id, gl.COMPILE_STATUS, &result);
    gl.GetShaderiv(id, gl.INFO_LOG_LENGTH, &info_log_length);
    if info_log_length > 0
    {
        err_msg := make([]byte, info_log_length);
        defer delete(err_msg);
        
        gl.GetShaderInfoLog(id, info_log_length-1, nil, &err_msg[0]);
        fmt.eprintf("%s\n", transmute(cstring)&err_msg[0]);
        return 0;
    }

    return id;
}

load_shader :: proc(vs_filepath, fs_filepath: string) -> Shader
{
    vs_code, fs_code: []byte;
    ok: bool;
    if vs_code, ok = os.read_entire_file(vs_filepath); !ok
    {
        fmt.eprintf("Failed to open vertex shader '%s'\n", vs_filepath);
        return {};
    }
    if fs_code, ok = os.read_entire_file(fs_filepath); !ok
    {
        fmt.eprintf("Failed to open fragment shader '%s'\n", vs_filepath);
        return {};
    }

    // Compile
    shader := Shader{};
    shader.uniforms = make(map[string]i32);
    shader.buffers  = make([dynamic]u32);
    vs_builder := parse_shader(&shader, vs_code);
    fs_builder := parse_shader(&shader, fs_code);
    
    defer
    {
        strings.destroy_builder(vs_builder);
        strings.destroy_builder(fs_builder);
    }
    
    vs_id := compile_shader(vs_filepath, vs_builder.buf[:], gl.VERTEX_SHADER);
    fs_id := compile_shader(fs_filepath, fs_builder.buf[:], gl.FRAGMENT_SHADER);

    // Link
    fmt.println("Linking program");
    program_id := gl.CreateProgram();
    gl.AttachShader(program_id, vs_id);
    gl.AttachShader(program_id, fs_id);
    gl.LinkProgram(program_id);

    result := i32(gl.FALSE);
    info_log_length: i32;
    
    // Check
    gl.GetProgramiv(program_id, gl.LINK_STATUS, &result);
    gl.GetProgramiv(program_id, gl.INFO_LOG_LENGTH, &info_log_length);
    if info_log_length > 0
    {
        err_msg := make([]byte, info_log_length);
        defer delete(err_msg);
        
        gl.GetProgramInfoLog(program_id, info_log_length-1, nil, &err_msg[0]);
        fmt.eprintf("ERROR: %s\n", string(err_msg));
        return {};
    }

    gl.DetachShader(program_id, vs_id);
    gl.DetachShader(program_id, fs_id);

    gl.DeleteShader(vs_id);
    gl.DeleteShader(fs_id);
    
    shader.id = program_id;

    return shader;
}

init_shader :: proc(vs_filepath, fs_filepath: string) -> Shader
{
    s := load_shader(vs_filepath, fs_filepath);
    
    s.vs_filepath = strings.clone(vs_filepath);
    s.fs_filepath = strings.clone(fs_filepath);

    for name, _ in s.uniforms
    {
        cstr := strings.clone_to_cstring(name);
        defer delete(cstr);

        s.uniforms[name] = gl.GetUniformLocation(s.id, cstr);
    }
    
    vs_time, _ := os.last_write_time_by_name(vs_filepath);
    fs_time, _ := os.last_write_time_by_name(fs_filepath);

    s.time = max(vs_time, fs_time);

    return s;
}

shader_check_update :: proc(s: ^Shader) -> bool
{
    vs_time, _ := os.last_write_time_by_name(s.vs_filepath);
    fs_time, _ := os.last_write_time_by_name(s.fs_filepath);

    new_time := max(vs_time, fs_time);
    if s.time < new_time
    {
        fmt.printf("UPDATING\n");
        old := s^;
        s^ = init_shader(s.vs_filepath, s.fs_filepath);
        delete_shader(old);
        return true;
    }
    
    return false;
}

delete_shader :: proc(s: Shader)
{
    delete(s.vs_filepath);
    delete(s.fs_filepath);
    delete(s.uniforms);
    
    gl.DeleteProgram(s.id);
}
