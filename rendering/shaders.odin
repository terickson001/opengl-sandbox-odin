package rendering

using import "core:fmt"
import "shared:gl"
import "core:os"
import "core:strings"
import "core:mem"
import "core:reflect"

Shader :: struct
{
    id: u32,
    time: os.File_Time,

    vs_filepath: string,
    gs_filepath: string,
    fs_filepath: string,

    uniforms: struct
    {
        resolution:       i32,
        px_range:         i32,

        M:                i32,
        V:                i32,
        P:                i32,
        MVP:              i32,
        VP:               i32,

        diffuse_sampler:  i32,
        normal_sampler:   i32,
        specular_sampler: i32,

        light_position_m: i32,
        light_color:      i32,
        light_power:      i32,
    },
}

compile_shader :: proc(filepath: string, kind: u32) -> u32
{
    id := gl.CreateShader(kind);
    code: []byte;
    ok: bool;
    
    if code, ok = os.read_entire_file(filepath); !ok
    {
        eprintf("Failed to open shader '%s'\n", filepath);
        return 0;
    }
    
    result := i32(gl.FALSE);
    info_log_length: i32;

    // Compile
    printf("Compiling shader: %s\n", filepath);
    source := &code[0];
    gl.ShaderSource(id, 1, &source, nil);
    gl.CompileShader(id);

    // Check
    gl.GetShaderiv(id, gl.COMPILE_STATUS, &result);
    gl.GetShaderiv(id, gl.INFO_LOG_LENGTH, &info_log_length);
    if info_log_length > 0
    {
        err_msg := make([]byte, info_log_length);
        defer delete(err_msg);
        
        gl.GetShaderInfoLog(id, info_log_length-1, nil, &err_msg[0]);
        eprintf("%s\n", err_msg);
        return 0;
    }

    return id;
}

load_shader :: proc(vs_filepath, fs_filepath: string) -> u32
{
    vs_code, fs_code: []byte;
    if vs_code, ok := os.read_entire_file(vs_filepath); !ok
    {
        eprintf("Failed to open vertex shader '%s'\n", vs_filepath);
        return 0;
    }
    if fs_code, ok := os.read_entire_file(fs_filepath); !ok
    {
        eprintf("Failed to open fragment shader '%s'\n", vs_filepath);
        return 0;
    }

    // Compile
    vs_id := compile_shader(vs_filepath, gl.VERTEX_SHADER);
    fs_id := compile_shader(fs_filepath, gl.FRAGMENT_SHADER);

    // Link
    println("Linking program");
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
        eprintf("%s\n", err_msg);
        return 0;
    }

    gl.DetachShader(program_id, vs_id);
    gl.DetachShader(program_id, fs_id);

    gl.DeleteShader(vs_id);
    gl.DeleteShader(fs_id);

    delete(vs_code);
    delete(fs_code);

    return program_id;
}

init_shader :: proc(vs_filepath, fs_filepath: string) -> Shader
{
    s := Shader{};
    s.id = load_shader(vs_filepath, fs_filepath);
    
    s.vs_filepath = strings.clone(vs_filepath);
    s.fs_filepath = strings.clone(fs_filepath);

    uniform_names := reflect.struct_field_names(type_of(s.uniforms));
    uniforms := transmute([]i32)(mem.Raw_Slice{&s.uniforms, size_of(s.uniforms)/size_of(i32)});
    for name, i in uniform_names
    {
        cstr := strings.clone_to_cstring(name);
        defer delete(cstr);

        uniforms[i] = gl.GetUniformLocation(s.id, cstr);
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

    gl.DeleteProgram(s.id);
}
