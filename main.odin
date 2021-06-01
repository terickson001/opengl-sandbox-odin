package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:math/linalg"
import "core:time"
import rt "core:runtime"
import "core:sort"

import "core:thread"

import "shared:gl"
import "shared:glfw"
import "shared:image"
import gfnt "shared:gl_font"

import core "engine"

import "engine/control"
import "engine/gui"
import "engine/util"
import "engine/profile"

import "shared:compress/zlib"
// import "shared:profile"

// @todo: Ambient Occlusion
// @todo: Directional Lights
// @todo: Image Based Lighting
// @todo: Support new mesh formats
// @todo: Animations

POLL_INTERVAL :: 1000/60;
glfw_poll :: proc()
{
    for {
        glfw.poll_events();
        time.sleep(POLL_INTERVAL);
    }
}

main :: proc()
{
    using core;
    
    init_glfw();
    defer glfw.terminate();
    
    window := init_window(1024, 768, "[$float$] Hello, World!");
    glfw.make_context_current(window.handle);
    
    init_gl();
    
    glfw.set_key_callback         (window.handle, control.update_keystate);
    glfw.set_mouse_button_callback(window.handle, control.update_mousebuttons);
    glfw.set_cursor_pos_callback  (window.handle, control.update_mousepos);
    glfw.set_scroll_callback      (window.handle, control.update_mousescroll);
    glfw.set_char_callback        (window.handle, control.keyboard_char_callback);
    control.KEYBOARD.text_buffer = new([dynamic]byte);
    control.KEYBOARD.text_buffer^ = make([dynamic]byte);
    
    gl.Enable(gl.DEPTH_TEST);
    gl.DepthFunc(gl.LESS);
    
    gl.Enable(gl.CULL_FACE);
    gl.CullFace(gl.BACK);
    gl.Enable(gl.MULTISAMPLE);
    gl.FrontFace(gl.CCW);
    
    glfw.set_input_mode(window.handle, glfw.CURSOR, int(glfw.CURSOR_DISABLED));
    glfw.set_cursor_pos(window.handle, f64(window.width/2), f64(window.height/2));
    glfw.poll_events();
    
    global_sampler_map = util.make_bitmap(2048);
    for _ in 0..6 do aquire_sampler();
    
    global_catalog = make_catalog();
    suzanne_mat := make_material(catalog_get_texture(&global_catalog, "res/rustediron2_basecolor.png"),
                                 catalog_get_texture(&global_catalog, "res/rustediron2_normal.png"),
                                 catalog_get_texture(&global_catalog, "res/rustediron2_metallic.png"),
                                 catalog_get_texture(&global_catalog, "res/rustediron2_roughness.png"),
                                 );
    
    suzanne_m := catalog_get_mesh(&global_catalog, "res/suzanne.obj");
    
    cube := catalog_get_mesh(&global_catalog, "res/cube.fbx");
    
    wall_mesh := gen_wall({8, 8, 1});
    
    cobble := make_material(
                            catalog_get_texture(&global_catalog, "res/slso_brick_variants.png"),
                            catalog_get_texture(&global_catalog, "res/slso_brick_normal.png"),
                            catalog_get_texture(&global_catalog, "res/slso_brick_specular.png"),
                            );
    
    scn := make_scene();
    scene_add_entity(&scn, make_entity("suzanne", suzanne_m, &suzanne_mat, {0, 0, 0}, {0, 0, -1}, {0.5, 0.5, 0.5}));
    scene_add_entity(&scn, make_entity("wall_back",   &wall_mesh, &cobble, { 0,     0,    -4.5}, { 0,  0, -1}));
    scene_add_entity(&scn, make_entity("wall_left",   &wall_mesh, &cobble, {-4.5,   0,     0},   { 1,  0,  0}));
    scene_add_entity(&scn, make_entity("wall_right",  &wall_mesh, &cobble, { 4.5,   0,     0},   {-1,  0,  0}));
    scene_add_entity(&scn, make_entity("wall_front",  &wall_mesh, &cobble, { 0,     0,     4.5}, { 0,  0,  1}));
    scene_add_entity(&scn, make_entity("wall_bottom", &wall_mesh, &cobble, { 0,    -4.5,   0},   { 0,  1,  0}));
    scene_add_entity(&scn, make_entity("wall_top",    &wall_mesh, &cobble, { 0,     4.5,   0},   { 0, -1,  0}));
    
    
    shader := catalog_get_shader(&global_catalog, "shader/3d.glsl");
    shader_2d := catalog_get_shader(&global_catalog, "shader/2d.glsl");
    text_shader := catalog_get_shader(&global_catalog, "shader/text.glsl");
    depth_shader := catalog_get_shader(&global_catalog, "shader/depth.glsl");
    
    gl.ClearColor(0.0, 0.3, 0.4, 0.0);
    
    sprite := load_sprite("res/adventurer.sprite");
    sprite_set_anim(&sprite, "running");
    adventurer := make_entity_2d(&sprite, [2]f32{f32(window.width)/2-160, f32(window.height)/2-160}, [2]f32{10,10});
    
    sizes := [?]int{72, 68, 64, 60, 56, 52, 48, 44, 40, 36, 32, 28, 24, 20, 16, 12};
    codepoints: [95]rune;
    for i in 0..<95 do codepoints[i] = rune(32+i);
    
    font, font_ok := gfnt.init_from_ttf_gl("res/font/OpenSans-Regular.ttf", "OpenSans", false, sizes[:], codepoints[:]);
    if !font_ok do return;
    defer gfnt.destroy_gl(font);
    gfnt.colors[0] = gfnt.Vec4{1, 1, 1, 1}; // white
    gfnt.colors[1] = gfnt.Vec4{0, 0, 0, 1}; // black
    gfnt.update_colors(0, 5);
    
    last_time := glfw.get_time();
    current_time: f64;
    dt: f32;
    
    time_step := f32(1.0/144.0);
    
    nb_frames  := 0;
    accum_time := 0.0;
    fps_buf: [8]byte;
    fps_str: string;
    
    view_mat: [4][4]f32;
    cam_pos := [3]f32{0, 2, 0};
    scn.camera = make_camera(cam_pos, cam_pos*-1, 3.0, 0.15);
    scn.camera.projection = cast([4][4]f32)linalg.matrix4_perspective(
                                                                      linalg.radians(f32(75.0)),
                                                                      f32(window.width) / f32(window.height),
                                                                      0.1, 100
                                                                      );
    
    init_point_depth_maps();
    
    /*
        lights := [?]Light{
            make_light({ 0,  0,  3}, {209.0/255,  75.0/255,  75.0/255}),
            make_light({ 0,  0,  3}, { 94.0/255, 209.0/255,  75.0/255}),
            make_light({ 0,  0,  3}, {75.0/255,  209.0/255, 202.0/255}),
            make_light({ 0,  0,  3}, {84.0/255,   75.0/255, 209.0/255}),
        };
    */
    
    
    lights := [?]Light{
        make_light({ 0,  0,  3}, {1, 0, 0}),
        make_light({ 0,  0,  3}, {0, 1, 0}),
        make_light({ 0,  0,  3}, {0, 0, 1}),
        make_light({ 0,  0,  3}, {1, 0, 0}),
    };
    
    for light in &lights
    {
        add_light(&light);
    }
    light_pow_base := f32(3);
    
    
    gui_ctx, gui_state := init_gui(window);
    gui_ctx.style.font = cast(rawptr)&font;
    
    gui_render_ctx := make_render_context(2, 0);
    
    init_editor(&gui_ctx);
    profile.init_window(&gui_ctx);
    
    tileset := load_tileset("res/test.tileset");
    tilemap := load_tilemap("res/test.tilemap");
    init_tile_variants(&tilemap, &tileset);
    
    gl.UseProgram(shader.id);
    set_uniform(shader, "exposure", 1.0);
    
    // thread.run(glfw_poll);
    
    point_light_time: u64;
    main_draw_time: u64;
    
    mouse_ray: Ray;
    updated: bool;
    for glfw.get_key(window.handle, glfw.KEY_ESCAPE) != glfw.PRESS &&
        !glfw.window_should_close(window.handle)
    {
        updated = false;
        accum_time += f64(dt);
        for dt > time_step
        {
            nb_frames += 1;
            updated = true;
            if control.key_pressed('[')
            {
                toggle_camera(window, &scn.camera);
                toggle_editor();
            }
            if control.key_pressed('P')
            {
                profile.toggle_window();
            }
            update_camera(window, &scn.camera, time_step);
            
            update_gui_inputs(&gui_ctx, f64(time_step));
            gui.begin(&gui_ctx);
            // do_gui(&gui_state, &gui_ctx, window);
            {
                if control.key_pressed('E') 
                {
                    open_spawn_menu(window, &gui_ctx, &scn);
                }
                update_editor(window, &gui_ctx, &scn);
                profile.do_window(&gui_ctx);
            }
            gui.end(&gui_ctx);
            
            update_entity_2d(&adventurer, time_step);
            
            size := adventurer.sprite.dim * adventurer.scale;
            h := f32(window.height)-size.y;
            w := f32(window.width)-size.x;
            adventurer.pos.y =  math.sin(f32(current_time)*4)*(h/8)+h/2;
            adventurer.pos.x =  math.cos(f32(current_time)*4)*-1*(w/8)+w/2;
            
            for light, i in &lights
            {
                light.power = light_pow_base + math.sin(f32(current_time))*(light_pow_base/2);
                
                light.pos.x =  math.sin(f32(current_time)+math.PI/16*f32(i))*1;
                light.pos.z =  math.cos(f32(current_time)+math.PI/16*f32(i))*1;
            }
            dt -= time_step;
        }
        
        if accum_time >= 1.0
        {
            fps_str = fmt.bprintf(fps_buf[:], "%.0f", f64(nb_frames)/accum_time);
            nb_frames = 0;
            accum_time = 0;
        }
        
        updated = true;
        // Only draw if content has been updated
        if updated
        {
            nb_frames += 1;
            scn.camera.view = get_camera_view(scn.camera);
            
            profile.gl_start_timer("Depth Pass");
            start_point_depth_pass(depth_shader);
            for light in lights
            {
                setup_point_light_pass(light, depth_shader);
                scene_render(&scn, depth_shader);
            }
            
            gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
            gl.Viewport(0, 0, i32(window.width), i32(window.height));
            
            profile.gl_end_timer();
            profile.gl_start_timer("Main Render");
            
            gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
            gl.UseProgram(shader.id);
            set_uniform(shader, "V", scn.camera.view);
            set_uniform(shader, "P", scn.camera.projection);
            set_uniform(shader, "eye_position_m", scn.camera.pos);
            set_uniform(shader, "lights", lights);
            set_uniform(shader, "resolution", window.res);
            set_uniform(shader, "point_depth_maps", 6);
            gl.ActiveTexture(gl.TEXTURE6);
            gl.BindTexture(gl.TEXTURE_CUBE_MAP_ARRAY, point_depth_maps);
            
            scene_render(&scn, shader);
            
            gl.Clear(gl.DEPTH_BUFFER_BIT);
            draw_gizmo(shader);
            
            /* 2D */
            gl.UseProgram(shader_2d.id);
            set_uniform(shader_2d, "resolution", window.res);
            debug_texture(shader, suzanne_mat.albedo.(^Texture).id);
            gfnt.set_state();
            {
                _, fps_w, _ := gfnt.parse_string_noallocate(&font, string(fps_str[:]), 24, nil);
                gfnt.draw_string(&font, 24, {f32(window.width) - fps_w, 0}, 0, string(fps_str[:]));
            }
            
            gl.Enable(gl.BLEND);
            gl.DepthMask(gl.FALSE);
            gl.Disable(gl.DEPTH_TEST);
            {
                // draw_entity_2d(shader_2d, &adventurer);
                // draw_tilemap(shader_2d, &adventurer.sprite.ctx, &tilemap, [2]f32{0, 0}, [2]f32{64, 64});
                draw_gui(&gui_ctx, shader_2d, text_shader, &gui_render_ctx, &font, gui_state.palette);
            }
            gl.Enable(gl.CULL_FACE);
            gl.Disable(gl.BLEND);
            gl.DepthMask(gl.TRUE);
            gl.Enable(gl.DEPTH_TEST);
            
            profile.gl_end_timer();
            profile.gl_end_frame();
            
            glfw.swap_buffers(window.handle);
        }
        
        // fmt.printf("DEPTH PASS: %.2fms\n", f64(profile.gl_get_result("Depth Pass")) / 1000000.0);
        // fmt.printf("MAIN PASS : %.2fms\n", f64(profile.gl_get_result("Main Render")) / 1000000.0);
        current_time = glfw.get_time();
        dt += f32(current_time - last_time);
        last_time = current_time;
        
        glfw.poll_events();
        catalog_check_updates(&global_catalog);
    }
}

init_glfw :: proc()
{
    if !glfw.init() 
    {
        fmt.eprintf("Failed to initialize GLFW\n");
    }
    
    glfw.window_hint(glfw.SAMPLES, 4);
    glfw.window_hint(glfw.CONTEXT_VERSION_MAJOR, 4);
    glfw.window_hint(glfw.CONTEXT_VERSION_MINOR, 5);
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
