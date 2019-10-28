package main

using import "core:fmt"
using import "core:math"
import "core:os"
import "shared:gl"
import "shared:glfw"

import "rendering"
import "util"

main :: proc()
{
    init_glfw();
    defer glfw.terminate();
    
    window := init_window(1024, 768, "[$float$] Hello, World!");
    glfw.make_context_current(window.handle);

    init_gl();
    
    gl.Enable(gl.DEPTH_TEST);
    gl.DepthFunc(gl.LESS);

    gl.Enable(gl.CULL_FACE);
    gl.Enable(gl.MULTISAMPLE);

    glfw.set_input_mode(window.handle, glfw.CURSOR, int(glfw.CURSOR_DISABLED));

    vao : u32;
    gl.GenVertexArrays(1, &vao);
    gl.BindVertexArray(vao);

    gl.ClearColor(0.0, 0.3, 0.4, 0.0);

    for glfw.get_key(window.handle, glfw.KEY_ESCAPE) != glfw.PRESS &&
        !glfw.window_should_close(window.handle)
    {
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        
        glfw.swap_buffers(window.handle);
        glfw.poll_events();
    }
}

init_glfw :: proc()
{
    if !glfw.init() do
        eprintf("Failed to initialize GLFW\n");
    
    glfw.window_hint(glfw.SAMPLES, 4);
    glfw.window_hint(glfw.CONTEXT_VERSION_MAJOR, 4);
    glfw.window_hint(glfw.CONTEXT_VERSION_MINOR, 3);
    glfw.window_hint(glfw.OPENGL_FORWARD_COMPAT, gl.TRUE);
    glfw.window_hint(glfw.OPENGL_PROFILE, int(glfw.OPENGL_CORE_PROFILE));
    glfw.window_hint(glfw.DEPTH_BITS, 24);
    println("GLFW initialized");
}

init_gl :: proc()
{
    gl.load_up_to(3, 3, glfw.set_proc_address);
    println("GL initialized");
}

Window :: struct
{
    width, height : int,
    handle        : glfw.Window_Handle,
}

init_window :: proc(w, h : int, title : string) -> Window
{
    win: Window;
    win.width  = w;
    win.height = h;
    win.handle = glfw.create_window(w, h, title, nil, nil);
    if win.handle == nil
    {
        eprintf("Failed to open GLFW window\n");
        glfw.terminate();
        os.exit(1);
    }
    
    return win;
}
