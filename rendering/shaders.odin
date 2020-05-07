package rendering

import "core:fmt"
import "shared:gl"
import "core:os"
import "core:strings"
import "core:mem"
import "core:intrinsics"
import "core:runtime"

import "../util"

Shader :: struct
{
    id: u32,
    time: os.File_Time,
    
    filepath: string,
    
    version: string,
    
    uniforms : map[string]i32,
    buffers  : [dynamic]u32
}

set_uniform :: proc(using s: ^Shader, name: string, val: $T)
{
    location, found := s.uniforms[name];
    if !found
    {
        fmt.eprintf("ERROR: Shader does not have uniform %q\n", name);
        os.exit(1);
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
        when      N == 2 { temp := val; gl.UniformMatrix2fv(location, 1, gl.FALSE, &temp[0][0]); }
        else when N == 3 { temp := val; gl.UniformMatrix3fv(location, 1, gl.FALSE, &temp[0][0]); }
        else when N == 4 { temp := val; gl.UniformMatrix4fv(location, 1, gl.FALSE, &temp[0][0]); }
    }
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
    if !ok do
        panic("Interface block not associated with a source shader");
    
    is_out := interface.from_kind == p.current;
    if is_out do strings.write_string(buff, "out ");
    else      do strings.write_string(buff, "in ");
    
    strings.write_string(buff, fmt.tprintf("%s ", name));
    strings.write_string(buff, interface.block);
    strings.write_byte(buff, ' ');
    
    if is_out do strings.write_string(buff, interface.out_name);
    else      do strings.write_string(buff, interface.in_name);
    
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
                if current > .Vertex do
                    panic("All vertex shader chunks must be first in file");
                if current != .Vertex do
                    strings.write_string(buff, fmt.tprintf("#version %s\n", version));
                current = .Vertex;
                
                case "geometry":
                if current > .Geometry do
                    panic("All geometry shader chunks must be after the vertex shader and before the fragment shader");
                if current != .Geometry
                {
                    if current != nil
                    {
                        indices[current] = {start, len(buff.buf)};
                        start = len(buff.buf);
                    }
                    strings.write_string(buff, fmt.tprintf("#version %s\n", version));
                    current = .Geometry;
                    write_interface(p);
                }
                
                case "fragment":
                if current > .Fragment do
                    panic("All fragment shader chunks must be last in file");
                
                if current != .Fragment
                {
                    if current != nil
                    {
                        indices[current] = {start, len(buff.buf)};
                        start = len(buff.buf);
                    }
                    strings.write_string(buff, fmt.tprintf("#version %s\n", version));
                    current = .Fragment;
                    write_interface(p);
                }
                
                case "interface":
                interface.from_kind = current;
                read_fmt(&file, "(%>%s%>,%>%s%>)%>%S{}", &interface.out_name, &interface.in_name, &interface.block);
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
                case "layout":
                loc := -1;
                name: string;
                if !read_fmt(&file, "%_(location%_=%_%d)%_in%_%^s%_%s%_;%>", &loc, &name)
                {
                    fmt.eprintf("ERROR: Couldn't parse shader attribute\n");
                    os.exit(1);
                }
                if len(buffers) < loc+1 do
                    resize(&buffers, loc+1);
                
                case "uniform":
                name: string;
                if !read_fmt(&file, "%_%^s%_%s%_;%>", &name)
                {
                    fmt.eprintf("ERROR: Couldn't parse shader uniform\n");
                    os.exit(1);
                }
                
                temp := strings.clone(name);
                uniforms[temp] = -1;
                
                case:
                read_line(&file, nil);
            }
        }
        else
        {
            read_line(&file, nil);
        }
        
        if write do
            strings.write_string(buff, line_start[:len(line_start)-len(file)]);
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
    
    for name, _ in shader.uniforms
    {
        cstr := strings.clone_to_cstring(name);
        defer delete(cstr);
        
        shader.uniforms[name] = gl.GetUniformLocation(shader.id, cstr);
    }
    
    if filepath != "" do
        shader.time, _ = os.last_write_time_by_name(filepath);
    
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
