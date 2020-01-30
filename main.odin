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
    
    window := render.init_window(768, 768, "[$float$] Hello, World!");
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

    // s := init_shader("./shader/vertex.vs", "./shader/fragment.fs");
    s := render.init_shader("./shader/vert2d.vs", "./shader/frag2d.fs");
    /* m := make_mesh("./res/suzanne.obj", true, true); */
    /* create_mesh_vbos(&m); */

    gl.ClearColor(0.0, 0.3, 0.4, 0.0);
    gl.ClearColor(0.55, 0.2, 0.3, 0.0);
    // gl.ClearColor(1, 1, 1, 1);

    vertices := [?]f32{
        -1.0, -1.0,  0.0,
         1.0, -1.0,  0.0,
        -1.0,  1.0,  0.0,
        
         1.0,  1.0,  0.0,
        -1.0,  1.0,  0.0,
         1.0, -1.0,  0.0,
    };

    uvs := [?]f32{
        0, 0,
        1, 0,
        0, 1,
        
        1, 1,
        0, 1,
        1, 0,
    };
    
    vbuff: u32;
    gl.GenBuffers(1, &vbuff);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbuff);
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices)*size_of(f32), &vertices[0], gl.STATIC_DRAW);

    uvbuff: u32;
    gl.GenBuffers(1, &uvbuff);
    gl.BindBuffer(gl.ARRAY_BUFFER, uvbuff);
    gl.BufferData(gl.ARRAY_BUFFER, len(uvs)*size_of(f32), &uvs[0], gl.STATIC_DRAW);

    texture_id := render.image_texture("./res/grass.png");
    for glfw.get_key(window.handle, glfw.KEY_ESCAPE) != glfw.PRESS &&
        !glfw.window_should_close(window.handle)
    {
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        gl.UseProgram(s.id);
        
        gl.Uniform2i(s.uniforms.resolution, i32(window.width), i32(window.height));

        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, texture_id);
        gl.Uniform1i(s.uniforms.diffuse_sampler, 0);
        
        gl.EnableVertexAttribArray(0);
        gl.BindBuffer(gl.ARRAY_BUFFER, vbuff);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 0, nil);

        gl.EnableVertexAttribArray(1);
        gl.BindBuffer(gl.ARRAY_BUFFER, uvbuff);
        gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 0, nil);

        gl.DrawArrays(gl.TRIANGLES, 0, 6);
        gl.DisableVertexAttribArray(0);
        gl.DisableVertexAttribArray(1);
        
        glfw.swap_buffers(window.handle);
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
