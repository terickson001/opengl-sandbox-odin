package main

import "core:fmt"
import "core:math"
import "core:os"
import "shared:gl"
import "shared:glfw"

import render "rendering"

main :: proc()
{
    init_glfw();
    defer glfw.terminate();
    
    window := render.init_window(1024, 768, "[$float$] Hello, World!");
    glfw.make_context_current(window.handle);

    init_gl();
    
    gl.Enable(gl.DEPTH_TEST);
    gl.DepthFunc(gl.LESS);

    gl.Enable(gl.CULL_FACE);
    gl.Enable(gl.MULTISAMPLE);

    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    // glfw.set_input_mode(window.handle, glfw.CURSOR, int(glfw.CURSOR_DISABLED));
    
    vao: u32;
    gl.GenVertexArrays(1, &vao);
    gl.BindVertexArray(vao);

    s := render.init_shader("./shader/vert2d.vs", "./shader/frag2d.fs");
    text_shader := render.init_shader("./shader/text.vs", "./shader/text.fs");
    // gl.ClearColor(0.0, 0.3, 0.4, 0.0);
    gl.ClearColor(0.55, 0.2, 0.3, 0.0);

    sprite := render.load_sprite("./res/adventurer.sprite");
    render.sprite_set_anim(&sprite, "running");
    adventurer := render.make_entity_2d(&sprite, [2]f32{512-160, 384-160}, [2]f32{10,10});

    font := render.load_font("./res/font/OpenSans-Regular");
    test_str := "Hello, World!";
    
    last_time := glfw.get_time();
    current_time: f64;
    dt: f32;

    time_step := 1.0/144.0;
    
    nb_frames := 0;
    accum_time := 0.0;
    
    for glfw.get_key(window.handle, glfw.KEY_ESCAPE) != glfw.PRESS &&
        !glfw.window_should_close(window.handle)
    {
        for dt > time_step
        {
            gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

            render.draw_entity_2d(s, &adventurer);

            gl.Enable(gl.BLEND);
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
            w := render.get_text_width(font, test_str, 24);
            render.draw_text(text_shader, font, test_str, {f32(window.width)-w, f32(window.height-24)}, 24);
            gl.Disable(gl.BLEND);
            glfw.swap_buffers(window.handle);
            
            dt -= time_step;
        }
        
        current_time = glfw.get_time();
        dt += f32(current_time - last_time);
        last_time = current_time;
        
        glfw.poll_events();
    }
}

init_glfw :: proc()
{
    if !glfw.init() do
        fmt.eprintf("Failed to initialize GLFW\n");
    
    glfw.window_hint(glfw.SAMPLES, 4);
    glfw.window_hint(glfw.CONTEXT_VERSION_MAJOR, 4);
    glfw.window_hint(glfw.CONTEXT_VERSION_MINOR, 3);
    glfw.window_hint(glfw.OPENGL_FORWARD_COMPAT, gl.TRUE);
    glfw.window_hint(glfw.OPENGL_PROFILE, int(glfw.OPENGL_CORE_PROFILE));
    glfw.window_hint(glfw.DEPTH_BITS, 24);
    fmt.println("GLFW initialized");
}

init_gl :: proc()
{
    gl.load_up_to(4, 3, glfw.set_proc_address);
    fmt.println("GL initialized");
}
