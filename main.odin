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

import render "rendering"
import "control"
import "gui"
import "util"
import "asset"
import "asset/model"
import "edit"
import "scene"
import "entity"

import "shared:compress/zlib"
import "shared:profile"

// @todo: Global Illumination
// @todo: Shadow Mapping
// @todo: Support new mesh formats
// @todo: Animations

main :: proc()
{
    when ODIN_DEBUG do profile.scoped_zone();
    
    init_glfw();
    defer glfw.terminate();
    
    window := render.init_window(1024, 768, "[$float$] Hello, World!");
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
    
    // catalog := asset.make_catalog();
    asset.global_catalog = asset.make_catalog();
    suzanne_mat := render.make_material(asset.get_texture(&asset.global_catalog, "res/rustediron2_basecolor.png"),
                                        asset.get_texture(&asset.global_catalog, "res/rustediron2_normal.png"),
                                        asset.get_texture(&asset.global_catalog, "res/rustediron2_metallic.png"),
                                        asset.get_texture(&asset.global_catalog, "res/rustediron2_roughness.png"),
                                        );
    
    suzanne_m := asset.get_mesh(&asset.global_catalog, "res/suzanne.obj");
    
    cube := asset.get_mesh(&asset.global_catalog, "res/cube.fbx");
    
    wall_mesh := gen_wall({8, 8, 1});
    
    cobble := render.make_material(
                                   asset.get_texture(&asset.global_catalog, "res/slso_brick_variants.png"),
                                   asset.get_texture(&asset.global_catalog, "res/slso_brick_normal.png"),
                                   asset.get_texture(&asset.global_catalog, "res/slso_brick_specular.png"),
                                   );
    // dds := render.load_texture("res/cube2.DDS");
    
    scn := scene.make_scene();
    scene.add_entity(&scn, entity.make_entity("suzanne", suzanne_m, &suzanne_mat, {0, 0, 2}, {0, 0, -1}));
    scene.add_entity(&scn, entity.make_entity("wall_back",   &wall_mesh, &cobble, { 0,     0,    -4.5}, { 0,  0, -1}));
    scene.add_entity(&scn, entity.make_entity("wall_left",   &wall_mesh, &cobble, {-4.5,   0,     0},   { 1,  0,  0}));
    scene.add_entity(&scn, entity.make_entity("wall_right",  &wall_mesh, &cobble, { 4.5,   0,     0},   {-1,  0,  0}));
    scene.add_entity(&scn, entity.make_entity("wall_front",  &wall_mesh, &cobble, { 0,     0,     4.5}, { 0,  0,  1}));
    scene.add_entity(&scn, entity.make_entity("wall_bottom", &wall_mesh, &cobble, { 0,    -4.5,   0},   { 0,  1,  0}));
    scene.add_entity(&scn, entity.make_entity("wall_top",    &wall_mesh, &cobble, { 0,     4.5,   0},   { 0, -1,  0}));
    
    
    shader := asset.get_shader(&asset.global_catalog, "shader/3d.glsl");
    shader_2d := asset.get_shader(&asset.global_catalog, "shader/2d.glsl");
    text_shader := asset.get_shader(&asset.global_catalog, "shader/text.glsl");
    depth_shader := asset.get_shader(&asset.global_catalog, "shader/depth.glsl");
    
    gl.ClearColor(0.0, 0.3, 0.4, 0.0);
    
    sprite := render.load_sprite("res/adventurer.sprite");
    render.sprite_set_anim(&sprite, "running");
    adventurer := entity.make_entity_2d(&sprite, [2]f32{f32(window.width)/2-160, f32(window.height)/2-160}, [2]f32{10,10});
    
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
    scene.add_camera(&scn, render.make_camera(cam_pos, cam_pos*-1, 3.0, 0.15));
    scn.camera.projection = cast([4][4]f32)linalg.matrix4_perspective(
                                                                      linalg.radians(f32(75.0)),
                                                                      f32(window.width) / f32(window.height),
                                                                      0.1, 100
                                                                      );
    
    light := render.Light{};
    light.pos = [3]f32{0, 0, 0};
    // block_id := scene.add_entity(&scn, entity.make_entity("block", cube, &dds, light_pos-{0.5, 0.5, 0.5}, {0, 0, -1}));
    light.color = [3]f32{0.8, 170.0/255, 94.0/255};
    light_pow_base := f32(1.0);
    render.init_shadowmap(&light, 2048);
    
    gui_ctx, gui_state := init_gui(window);
    gui_ctx.style.font = cast(rawptr)&font;
    
    gui_render_ctx := render.make_context(2, 0);
    
    edit.init_editor(&gui_ctx);
    
    tileset := render.load_tileset("res/test.tileset");
    tilemap := render.load_tilemap("res/test.tilemap");
    render.init_variants(&tilemap, &tileset);
    
    mouse_ray: entity.Ray;
    updated: bool;
    for glfw.get_key(window.handle, glfw.KEY_ESCAPE) != glfw.PRESS &&
        !glfw.window_should_close(window.handle)
    {
        updated = false;
        for dt > time_step
        {
            updated = true;
            
            if control.key_pressed('[')
            {
                render.toggle_camera(window, &scn.camera);
                edit.toggle_editor();
            }
            render.update_camera(window, &scn.camera, time_step);
            
            update_gui_inputs(&gui_ctx, f64(time_step));
            gui.begin(&gui_ctx);
            do_gui(&gui_state, &gui_ctx, window);
            {
                if control.key_pressed('E') 
                {
                    edit.open_spawn_menu(window, &gui_ctx, &scn);
                }
                edit.update_editor(window, &gui_ctx, &scn);
            }
            gui.end(&gui_ctx);
            
            entity.update_entity_2d(&adventurer, time_step);
            
            size := adventurer.sprite.dim * adventurer.scale;
            h := f32(window.height)-size.y;
            w := f32(window.width)-size.x;
            adventurer.pos.y =  math.sin(f32(current_time)*4)*(h/8)+h/2;
            adventurer.pos.x =  math.cos(f32(current_time)*4)*-1*(w/8)+w/2;
            
            light.pow = light_pow_base + math.sin(f32(current_time))*(light_pow_base);
            /*
                        light.pos.y =  math.sin(f32(current_time)*2)*4;
                        light.pos.x =  math.cos(f32(current_time)*2)*4;
                        light.pos.z =  math.cos((f32(current_time)*2))*4;
            */
            // scn.entities[block_id].pos = light_pos-{0.5, 0.5, 0.5};
            dt -= time_step;
        }
        
        // Only draw if content has been updated
        nb_frames += 1;
        accum_time += f64(dt);
        if accum_time >= 1.0
        {
            fps_str = fmt.bprintf(fps_buf[:], "%d", nb_frames);
            nb_frames = 0;
            accum_time -= 1.0;
        }
        
        if updated
        {
            
            scn.camera.view = render.get_camera_view(scn.camera);
            
            render.setup_shadowmap(light, depth_shader);
            scene.render(&scn, depth_shader);
            
            gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
            gl.Viewport(0, 0, i32(window.width), i32(window.height));
            gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
            gl.UseProgram(shader.id);
            render.set_uniform(shader, "V", scn.camera.view);
            render.set_uniform(shader, "P", scn.camera.projection);
            render.set_uniform(shader, "eye_position_m", scn.camera.pos);
            render.set_uniform(shader, "light_position_m", light.pos);
            render.set_uniform(shader, "light_color", light.color);
            render.set_uniform(shader, "light_power", light.pow);
            render.set_uniform(shader, "resolution", window.res);
            gl.ActiveTexture(gl.TEXTURE5);
            gl.BindTexture(gl.TEXTURE_CUBE_MAP, light.shadowmap.tex);
            render.set_uniform(shader, "depth_map", 5);
            render.set_uniform(shader, "light_extent", light.extent);
            
            scene.render(&scn, shader);
            
            /* 2D */
            gl.UseProgram(shader_2d.id);
            render.set_uniform(shader_2d, "resolution", window.res);
            render.debug_texture(shader, suzanne_mat.albedo.(^render.Texture).id);
            gfnt.set_state();
            {
                _, fps_w, _ := gfnt.parse_string_noallocate(&font, string(fps_str[:]), 24, nil);
                gfnt.draw_string(&font, 24, {f32(window.width) - fps_w, 0}, 0, string(fps_str[:]));
            }
            
            gl.Disable(gl.CULL_FACE);
            gl.Enable(gl.BLEND);
            gl.DepthMask(gl.FALSE);
            gl.Disable(gl.DEPTH_TEST);
            {
                // render.draw_entity_2d(shader_2d, &adventurer);
                // render.draw_tilemap(shader_2d, &adventurer.sprite.ctx, &tilemap, [2]f32{0, 0}, [2]f32{64, 64});
                draw_gui(&gui_ctx, shader_2d, text_shader, &gui_render_ctx, &font, gui_state.palette);
            }
            gl.Enable(gl.CULL_FACE);
            gl.Disable(gl.BLEND);
            gl.DepthMask(gl.TRUE);
            gl.Enable(gl.DEPTH_TEST);
            
            gl.UseProgram(shader.id);
            gl.Clear(gl.DEPTH_BUFFER_BIT);
            edit.draw_gizmo(shader);
            
            glfw.swap_buffers(window.handle);
        }
        
        current_time = glfw.get_time();
        dt += f32(current_time - last_time);
        last_time = current_time;
        
        glfw.poll_events();
        asset.check_updates(&asset.global_catalog);
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
