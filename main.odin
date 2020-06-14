package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:math/linalg"

import "shared:gl"
import "shared:glfw"
import gfnt "shared:gl_font"

import render "rendering"
import "control"
import "gui"
import "util"
import "asset"

// @todo: Asset Hot-Loading
// @todo: Global Illumination
// @todo: Support new mesh formats
// @todo: Animations
// @todo: Models with multiple materials
// @todo: Mesh Voxelization/Pixelization

Gui_State :: struct
{
    window: gui.Window,
    palette: render.Texture,
    
    slider_value: f32,
    text_buffer: gui.Text_Buffer,
}

main :: proc()
{
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
    gl.Enable(gl.MULTISAMPLE);
    
    glfw.set_input_mode(window.handle, glfw.CURSOR, int(glfw.CURSOR_DISABLED));
    glfw.set_cursor_pos(window.handle, f64(window.width/2), f64(window.height/2));
    glfw.poll_events();
    
    suzanne_m := render.make_mesh("./res/suzanne.obj", true, false);
    render.create_mesh_vbos(&suzanne_m);
    suzanne_t := render.load_texture("./res/grass.png");
    suzanne   := render.make_entity(&suzanne_m, &suzanne_t, {0, 0, 0}, {0, 0, -1});
    
    cube := render.prim_cube();
    cobble := render.load_texture("./res/cobble.png");
    block := render.make_entity(&cube, &cobble, {0, -2, 0}, {0, 0, -1});
    
    catalog := asset.make_catalog();
    asset.load(&catalog, "./shader/3d.glsl");
    asset.load(&catalog, "./shader/2d.glsl");
    asset.load(&catalog, "./shader/text.glsl");
    shader := asset.get_shader(&catalog, "3d.glsl");
    shader_2d := asset.get_shader(&catalog, "2d.glsl");
    text_shader := asset.get_shader(&catalog, "text.glsl");
    
    
    gl.ClearColor(0.0, 0.3, 0.4, 0.0);
    // gl.ClearColor(0.55, 0.2, 0.3, 0.0);
    
    sprite := render.load_sprite("./res/adventurer.sprite");
    render.sprite_set_anim(&sprite, "running");
    adventurer := render.make_entity_2d(&sprite, [2]f32{512-160, 384-160}, [2]f32{10,10});
    
    // font := render.load_font("./res/font/OpenSans-Regular");
    sizes := [?]int{72, 68, 64, 60, 56, 52, 48, 44, 40, 36, 32, 28, 24, 20, 16, 12};
	codepoints: [95]rune;
	for i in 0..<95 do codepoints[i] = rune(32+i);
	
	font, font_ok := gfnt.init_from_ttf_gl("./res/font/OpenSans-Regular.ttf", "OpenSans", false, sizes[:], codepoints[:]);
	if !font_ok do
		return;
    defer gfnt.destroy_gl(font);
    gfnt.colors[0] = gfnt.Vec4{1, 1, 1, 1}; // white
    gfnt.colors[1] = gfnt.Vec4{0, 0, 0, 1}; // black
    gfnt.update_colors(0, 5);
    
    test_str := "Hello, World!";
    
    last_time := glfw.get_time();
    current_time: f64;
    dt: f32;
    
    time_step := f32(1.0/144.0);
    
    nb_frames  := 0;
    accum_time := 0.0;
    fps_buf: [8]byte;
    fps_str: string;
    
    projection_mat := cast([4][4]f32)linalg.matrix4_perspective(
                                                                linalg.radians(50),
                                                                f32(window.width) / f32(window.height),
                                                                0.1, 100
                                                                );
    
    view_mat: [4][4]f32;
    cam_pos := [3]f32{0, 0, 7};
    camera := render.make_camera(cam_pos, cam_pos*-1, 3.0, 0.15);
    
    light_pos := [3]f32{0, 5, 4};
    light_col := [3]f32{1, 1, 1};
    light_pow := f32(50.0);
    
    gui_ctx, gui_state := init_gui(window);
    gui_ctx.style.font = cast(rawptr)&font;
    
    gui_render_ctx := render.make_context(2, 0);
    
    updated: bool;
    for glfw.get_key(window.handle, glfw.KEY_ESCAPE) != glfw.PRESS &&
        !glfw.window_should_close(window.handle)
    {
        updated = false;
        for dt > time_step
        {
            updated = true;
            
            nb_frames += 1;
            accum_time += f64(dt);
            if accum_time >= 1.0
            {
                fps_str = fmt.bprintf(fps_buf[:], "%d", nb_frames);
                nb_frames = 0;
                accum_time -= 1.0;
            }
            
            render.update_camera(window, &camera, time_step);
            do_gui(&gui_state, &gui_ctx, window, f64(time_step));
            
            render.update_entity_2d(&adventurer, time_step);
            
            
            size := adventurer.sprite.dim * adventurer.scale;
            h := f32(window.height)-size.y;
            w := f32(window.width)-size.x;
            adventurer.pos.y =  math.sin(f32(current_time)*4)*(h/8)+h/2;
            adventurer.pos.x =  math.cos(f32(current_time)*4)*-1*(w/8)+w/2;
            
            
            dt -= time_step;
        }
        
        // Only draw if content has been updated
        if updated
        {
            gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
            view_mat = render.get_camera_view(camera);
            
            gl.UseProgram(shader.id);
            render.set_uniform(shader, "V", view_mat);
            render.set_uniform(shader, "P", projection_mat);
            render.set_uniform(shader, "light_position_m", light_pos);
            render.set_uniform(shader, "light_color", light_col);
            render.set_uniform(shader, "light_power", light_pow);
            
            // suzanne.dir   = linalg.normalize(camera.dir*{1,0,1});
            render.draw_entity(shader, suzanne);
            
            
            render.draw_entity(shader, block);
            
            /* 2D */
            gl.UseProgram(shader_2d.id);
            render.set_uniform(shader_2d, "resolution", window.res);
            render.draw_entity_2d(shader_2d, &adventurer);
            
            gl.Disable(gl.DEPTH_TEST);
            gl.DepthMask(gl.FALSE);
            gl.Enable(gl.BLEND);
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
            {
                gfnt.set_state();
                at := [2]f32{0.0, 1.0};
                num, dx, dy := gfnt.draw_string(&font, 24, at, 0, test_str);
                // at.y += (test_str == "" ? 10.0 : dy);
                
                _, fps_w, _ := gfnt.parse_string_noallocate(&font, string(fps_str[:]), 24, nil);
                gfnt.draw_string(&font, 24, {f32(window.width)-fps_w, f32(window.height-24)}, 0, string(fps_str[:]));
                /*
                                render.draw_text(text_shader, &font, string(fps_str[:]),
                                                 ,
                                                 24);
                                */
                
                draw_gui(&gui_ctx, shader_2d, text_shader, &gui_render_ctx, &font, gui_state.palette);
            }
            gl.Disable(gl.BLEND);
            gl.DepthMask(gl.TRUE);
            gl.Enable(gl.DEPTH_TEST);
            
            glfw.swap_buffers(window.handle);
        }
        
        current_time = glfw.get_time();
        dt += f32(current_time - last_time);
        last_time = current_time;
        
        glfw.poll_events();
        asset.check_updates(&catalog);
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

init_gui :: proc(win: render.Window) -> (gui.Context, Gui_State)
{
    ctx := gui.init();
    {
        using ctx;
        using glfw.Key;
        
        ctx.get_text_width = gui_text_width;
        
        key_map[.Enter]  = int(KEY_ENTER);
        key_map[.Backspace]  = int(KEY_BACKSPACE);
        key_map[.Delete]  = int(KEY_DELETE);
        
        key_map[.LShift] = int(KEY_LEFT_SHIFT);
        key_map[.LCtrl]  = int(KEY_LEFT_CONTROL);
        key_map[.LAlt]   = int(KEY_LEFT_ALT);
        key_map[.LSuper] = int(KEY_LEFT_SUPER);
        
        key_map[.RShift] = int(KEY_RIGHT_SHIFT);
        key_map[.RCtrl]  = int(KEY_RIGHT_CONTROL);
        key_map[.RAlt]   = int(KEY_RIGHT_ALT);
        key_map[.RSuper] = int(KEY_RIGHT_SUPER);
        
        key_map[.Left]   = int(KEY_LEFT);
        key_map[.Right]  = int(KEY_RIGHT);
        key_map[.Up]     = int(KEY_UP);
        key_map[.Down]   = int(KEY_DOWN);
        
        key_map[.Home]   = int(KEY_HOME);
        key_map[.End]    = int(KEY_END);
        
        key_map[.A]      = int(KEY_A);
        key_map[.C]      = int(KEY_C);
        key_map[.X]      = int(KEY_X);
        key_map[.V]      = int(KEY_V);
        
        display.width  = f32(win.width);
        display.height = f32(win.height);
    }
    
    state := Gui_State{};
    {
        using state;
        
        window = gui.init_window(&ctx, "A Window", {256, 100, 412, 110});
        palette = render.texture_palette(ctx.style.colors[:], false);
        
        slider_value = 50;
        text_buffer.backing = make([]byte, 128);
    }
    return ctx, state;
}

do_gui :: proc(state: ^Gui_State, ctx: ^gui.Context, win: render.Window, dt: f64)
{
    ctx.ctrl.mouse = {control.mouse_down(0), control.mouse_down(1), control.mouse_down(2)};
    ctx.ctrl.cursor = control.get_mouse_pos();
    for k, i in control.KEYBOARD.keys do
        ctx.ctrl.keys_down[i+32] = k == .Pressed || k == .Down || k == .Repeat;
    gui.buffer_append(&ctx.ctrl.input_buf, string(control.KEYBOARD.text_buffer[:]));
    resize(control.KEYBOARD.text_buffer, 0);
    
    ctx.delta_time = dt;
    gui.begin(ctx);
    
    if .Active in gui.window(ctx, &state.window, {})
    {
        gui.row(ctx, 3, {70, -70, 0}, 0);
        
        gui.label(ctx, "Row 1:", {});
        if .Submit in gui.button(ctx, "Reset", 0, {}) do
            state.slider_value = 50;
        if .Submit in gui.button(ctx, "+5", 0, {}) do
            state.slider_value += 5;
        
        gui.label(ctx, "Row 2:", {});
        gui.slider(ctx, "Slider 1", &state.slider_value, "%.1f", 0, 100, 0, {});
        if .Submit in gui.button(ctx, "-5", 0, {}) do
            state.slider_value -= 5;
        
        gui.row(ctx, 2, {-100, 0}, 0);
        gui.text_input(ctx, "Text input", &state.text_buffer, {.Left});
        gui.number_input(ctx, "Number input", &state.slider_value, "%.1f", 0, 100, 0, {});
        gui.window_end(ctx);
    }
    
    gui.end(ctx);
}

draw_gui :: proc(ctx: ^gui.Context, sgen, stext: ^render.Shader, render_ctx: ^render.Context, font: ^gfnt.Font, palette: render.Texture)
{
    draw: gui.Draw;
    for gui.next_draw(ctx, &draw)
    {
        #partial switch d in draw.variant
        {
            case gui.Draw_Rect:
            draw_rect(sgen, render_ctx, d.rect, draw.layer, d.color_id, palette);
            
            case gui.Draw_Text:
            gfnt.set_state();
            draw_text(stext, d.pos, font, d.text, d.size, draw.layer, d.color_id);
        }
    }
}

draw_text :: proc(s: ^render.Shader, pos: [2]f32, font: ^gfnt.Font, text: string, size: f32, layer: int, color_id: gui.Color_ID)
{
    sz := font_nearest_size(font, int(size));
    gfnt.draw_string(font, sz, {pos.x, pos.y}, 0, text);
}

draw_rect :: proc(s: ^render.Shader, ctx: ^render.Context, rect: gui.Rect, layer: int, color_id: gui.Color_ID, palette: render.Texture)
{
    using rect := rect;
    
    vertices := [6][2]f32{};
    uvs      := [6][2]f32{};
    
    y = 768 - y - h;
    
    vertices[0] = {x,   y};
    vertices[1] = {x+w, y+h};
    vertices[2] = {x,   y+h};
    
    vertices[3] = {x,   y};
    vertices[4] = {x+w, y};
    vertices[5] = {x+w, y+h};
    
    c_uv := render.texture_palette_index(palette, int(color_id));
    uv_size := 1/f32(palette.info.width);
    uvs[0] = c_uv;
    uvs[1] = {c_uv.x + uv_size, c_uv.y + uv_size};
    uvs[2] = {c_uv.x,           c_uv.y + uv_size};
    
    uvs[3] = c_uv;
    uvs[4] = {c_uv.x + uv_size, c_uv.y};
    uvs[5] = {c_uv.x + uv_size, c_uv.y + uv_size};
    
    gl.UseProgram(s.id);
    
    
    render.bind_context(ctx);
    render.update_vbo(ctx, 0, vertices[:]);
    render.update_vbo(ctx, 1, uvs[:]);
    
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D, palette.diffuse);
    
    gl.DrawArrays(gl.TRIANGLES, 0, 6);
}

gui_text_width :: proc(font: rawptr, text: string, size: int) -> f32
{
    sz := font_nearest_size(cast(^gfnt.Font)font, size);
    _, dx, _ := gfnt.parse_string_noallocate(cast(^gfnt.Font)font, text, sz, nil);
    return dx;
}

font_nearest_size :: proc(font: ^gfnt.Font, size: int) -> int
{
    out := int((size+2)/4)*4;
    
    largest := cast(int)font.size_metrics[0].size;
    smallest := cast(int)font.size_metrics[len(font.size_metrics)-1].size;
    out = min(max(out, smallest), largest);
    return out;
}