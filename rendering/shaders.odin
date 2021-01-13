package rendering

import "core:fmt"
import "shared:gl"
import "core:os"
import "core:strings"
import "core:mem"
import "core:intrinsics"
import "core:runtime"
import oparse "core:odin/parser"
import oast "core:odin/ast"
import "../util"

Shader :: struct
{
    id: u32,
    time: os.File_Time,
    
    filepath: string,
    
    version: string,
    
    uniforms : map[string]i32,
    ubos     : map[string]u32,
}

set_uniform :: proc(using s: ^Shader, name: string, val: $T, loc := #caller_location)
{
    location, found := s.uniforms[name];
    if !found
    {
        // fmt.eprintf("%#v: ERROR: Shader does not have uniform %q\n", loc, name);
        // os.exit(1);
        return;
    }
    
    E :: intrinsics.type_elem_type(T);
    N :: size_of(T) / size_of(E);
    when intrinsics.type_is_integer(E) || intrinsics.type_is_boolean(E) || intrinsics.type_is_enum(E)
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
        S :: intrinsics.type_elem_type(E);
        when intrinsics.type_is_array(S) // Array of Matrices
        {
            
            M :: size_of(E) / size_of(S); // Matrix Dims
            when      M == 2 { temp := val; gl.UniformMatrix2fv(location, N, gl.FALSE, &temp[0][0][0]); }
            else when M == 3 { temp := val; gl.UniformMatrix3fv(location, N, gl.FALSE, &temp[0][0][0]); }
            else when M == 4 { temp := val; gl.UniformMatrix4fv(location, N, gl.FALSE, &temp[0][0][0]); }
        }
        else
        {
            when      N == 2 { temp := val; gl.UniformMatrix2fv(location, 1, gl.FALSE, &temp[0][0]); }
            else when N == 3 { temp := val; gl.UniformMatrix3fv(location, 1, gl.FALSE, &temp[0][0]); }
            else when N == 4 { temp := val; gl.UniformMatrix4fv(location, 1, gl.FALSE, &temp[0][0]); }
        }
    }
}

set_uniform_block :: proc(using s: ^Shader, name: string, val: $T, loc := #caller_location)
{
    val := val;
    
    location, found := s.uniforms[name];
    if !found
    {
        
        fmt.eprintf("%#v: ERROR: Shader does not have uniform %q\n", loc, name);
        //os.exit(1);
        
        return;
    }
    
    ubo, ok := s.ubos[name];
    if !ok
    {
        gl.GenBuffers(1, &ubo);
        gl.BindBuffer(gl.UNIFORM_BUFFER, ubo);
        gl.BufferData(gl.UNIFORM_BUFFER, size_of(T), nil, gl.STATIC_DRAW);
    }
    else
    {
        gl.BindBuffer(gl.UNIFORM_BUFFER, ubo);
    }
    
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(T), &val);
    gl.BindBuffer(gl.UNIFORM_BUFFER, 0);
}

Shader_Kind :: enum
{
    _,
    Vertex,
    Geometry,
    Fragment,
}

gl_shader_kind :: proc(k: Shader_Kind) -> u32
{
    switch k
    {
        case .Vertex:   return gl.VERTEX_SHADER;
        case .Geometry: return gl.GEOMETRY_SHADER;
        case .Fragment: return gl.FRAGMENT_SHADER;
        case: return 0;
    }
}

Shader_Parser :: struct
{
    using shader: ^Shader,
    
    current: Shader_Kind,
    interface: struct
    {
        from_kind: Shader_Kind,
        out_name : string,
        in_name  : string,
        block    : string,
    },
    indices: [Shader_Kind][2]int,
    start: int,
    buff: ^strings.Builder,
}

@(private="file")
write_interface :: proc(using p: ^Shader_Parser)
{
    if interface.from_kind == nil do return;
    
    name, ok := fmt.enum_value_to_string(interface.from_kind);
    if !ok 
    {
        panic("Interface block not associated with a source shader");
    }
    
    strings.write_string(buff, fmt.tprintf("struct interface_t %s;\n", interface.block));
    
    is_out := interface.from_kind == p.current;
    if is_out do strings.write_string(buff, "out ");
    else      do strings.write_string(buff, "in ");
    
    strings.write_string(buff, fmt.tprintf("interface_t %s", interface.out_name));
    if !is_out && p.current == .Geometry 
    {
        strings.write_string(buff, "[]");
    }
    strings.write_string(buff, ";\n");
    
    if !is_out do interface = {};
}

parse_shader :: proc(using p: ^Shader_Parser, path: string, source: []byte)
{
    using util;
    
    top_level := false;
    if buff == nil
    {
        top_level = true;
        buff = new_clone(strings.make_builder());
    }
    
    file := string(source[:]);
    ident: string;
    for len(file) > 0
    {
        write := true;
        line_start := file[:];
        
        if read_fmt(&file, "@%s%>", &ident)
        {
            write = false;
            switch ident
            {
                case "import":
                imported: string;
                if !read_filepath(&file, &imported)
                {
                    fmt.eprintf("ERROR: Could not read filename after @import\n");
                    os.exit(1);
                }
                
                path := fmt.aprintf("%s/%s", util.dir(path), imported);
                imp_data, ok := os.read_entire_file(path);
                if !ok
                {
                    fmt.eprintf("ERROR: Could not open @import'ed file %q\n", imported);
                    os.exit(1);
                }
                
                parse_shader(p, path, imp_data);
                delete(path);
                
                case "version":
                read_line(&file, &version);
                
                case "vertex":
                if current > .Vertex 
                {
                    panic("All vertex shader chunks must be first in file");
                }
                if current != .Vertex 
                {
                    strings.write_string(buff, fmt.tprintf("#version %s\n", version));
                }
                current = .Vertex;
                
                case "geometry":
                if current > .Geometry 
                {
                    panic("All geometry shader chunks must be after the vertex shader and before the fragment shader");
                }
                if current != .Geometry
                {
                    if current != nil
                    {
                        indices[current] = {start, len(buff.buf)};
                        start = len(buff.buf);
                    }
                    strings.write_string(buff, fmt.tprintf("#version %s\n", version));
                    current = .Geometry;
                    //write_interface(p);
                }
                
                case "fragment":
                if current > .Fragment 
                {
                    panic("All fragment shader chunks must be last in file");
                }
                
                if current != .Fragment
                {
                    if current != nil
                    {
                        indices[current] = {start, len(buff.buf)};
                        start = len(buff.buf);
                    }
                    strings.write_string(buff, fmt.tprintf("#version %s\n", version));
                    current = .Fragment;
                    //write_interface(p);
                }
                
                case "out":
                interface.from_kind = current;
                read_fmt(&file, "%>%W%>%S{};", &interface.out_name, &interface.block);
                write_interface(p);
                
                case "in":
                read_fmt(&file, "%>%W%>;", &interface.in_name);
                write_interface(p);
                
                case "inout":
                new_out_name: string;
                old_block := interface.block;
                read_fmt(&file, "%>%W%>%W%>;", &interface.in_name, &new_out_name);
                write_interface(p);
                interface.from_kind = .Geometry;
                interface.block = old_block;
                interface.out_name = new_out_name;
                write_interface(p);
                
                case:
                fmt.eprintf("ERROR: Invalid attribute '@%s' in shader\n", ident);
                os.exit(1);
            }
        }
        else if read_fmt(&file, "%s%_", &ident)
        {
            switch ident
            {
                /*
                                case "uniform":
                                name: string;
                                if !read_fmt(&file, "%_%^s%_%s%_", &name)
                                {
                                    fmt.eprintf("ERROR: Couldn't parse shader uniform\n");
                                    os.exit(1);
                                }
                                
                                temp := strings.clone(name);
                                uniforms[temp] = -1;
                */
                
                case:
                read_line(&file, nil);
            }
        }
        else
        {
            read_line(&file, nil);
        }
        
        if write 
        {
            strings.write_string(buff, line_start[:len(line_start)-len(file)]);
        }
    }
    indices[current] = {start, len(buff.buf)};
}

compile_shader :: proc(name: string, code: []byte, kind: u32) -> u32
{
    id := gl.CreateShader(kind);
    
    result := i32(gl.FALSE);
    info_log_length: i32;
    
    // Compile
    fmt.printf("Compiling shader: %s\n", name);
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

load_shader_from_mem :: proc(code: []byte, filepath := string{}) -> Shader
{
    // Parse
    shader := Shader{};
    parser := Shader_Parser{shader=&shader, current=nil};
    
    shader.uniforms = make(map[string]i32);
    parse_shader(&parser, filepath, code);
    
    defer strings.destroy_builder(parser.buff);
    
    // Compile
    program_id := gl.CreateProgram();
    
    separate: [Shader_Kind][]byte;
    compiled: [Shader_Kind]u32;
    for k in Shader_Kind
    {
        start, end := expand_to_tuple(parser.indices[k]);
        separate[k] = parser.buff.buf[start:end];
        if len(separate[k]) != 0
        {
            // fmt.printf("%v: %s\n", k, string(separate[k]));
            compiled[k] = compile_shader(fmt.tprintf("%s:%v", filepath, k), separate[k], gl_shader_kind(k));
            gl.AttachShader(program_id, compiled[k]);
        }
    }
    
    // Link
    fmt.println("Linking program");
    gl.LinkProgram(program_id);
    
    // Check
    result := i32(gl.FALSE);
    info_log_length: i32;
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
    
    for shader_id in compiled
    {
        if shader_id == 0 do continue;
        gl.DetachShader(program_id, shader_id);
        gl.DeleteShader(shader_id);
    }
    
    shader.id = program_id;
    
    // Initialize
    
    shader.filepath = strings.clone(filepath);
    
    // Get Uniforms
    n_uniforms: i32;
    gl.GetProgramiv(shader.id, gl.ACTIVE_UNIFORMS, &n_uniforms);
    
    if n_uniforms > 0 do reserve(&shader.uniforms, int(n_uniforms));
    
    for i in 0..<n_uniforms
    {
        strlen: i32;
        cstr: [256]u8;
        kind: u32;
        size: i32;
        gl.GetActiveUniform(shader.id, u32(i), 256, &strlen, &size, &kind, &cstr[0]);
        
        loc := gl.GetUniformLocation(shader.id, cstring(&cstr[0]));
        name := strings.clone(string(cstr[:strlen]));
        shader.uniforms[name] = loc;
    }
    
    if filepath != "" 
    {
        shader.time, _ = os.last_write_time_by_name(filepath);
    }
    
    return shader;
}

load_shader :: proc(filepath: string) -> Shader
{
    code, ok := os.read_entire_file(filepath);
    if !ok
    {
        fmt.eprintf("Failed to open shader %q\n", filepath);
        return {};
    }
    
    shader :=  load_shader_from_mem(code, filepath);
    
    return shader;
}

shader_check_update :: proc(s: ^Shader) -> bool
{
    new_time, _ := os.last_write_time_by_name(s.filepath);
    if s.time < new_time
    {
        old := s^;
        s^ = load_shader(s.filepath);
        delete_shader(old);
        return true;
    }
    
    return false;
}

delete_shader :: proc(s: Shader)
{
    delete(s.filepath);
    delete(s.uniforms);
    
    gl.DeleteProgram(s.id);
}