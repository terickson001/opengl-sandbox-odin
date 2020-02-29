package main

import "core:fmt"
import "core:math"
import "core:os"
import "shared:gl"
import "shared:glfw"

import render "rendering"
import "control"
import "gui"

gui_text_width :: proc(font: rawptr, text: string, size: int) -> f32
{
    return render.get_text_width((^render.Font)(font)^, text, size);
}

init_gui :: proc(win: render.Window) -> gui.Context
{
    using ctx := gui.init();
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
    return ctx;
}

draw_text :: proc(r: ^render.Renderer, s: render.Shader, pos: [2]f32, font: render.Font, text: string, size: f32, layer: int, color_id: gui.Color_ID)
{
    if len(text) == 0 do
        return;

    pos := pos;
    pos.y = 768 - pos.y - size;
    vertices := make([dynamic][2]f32);
    uvs      := make([dynamic][3]f32);
    
    scale := f32(size) / (font.info.ascent - font.info.descent);
    for c in text
    {
        if 32 > c || c > 128 do
            continue;

        metrics := font.info.metrics[c-32];
        if c == 32
        {
            pos.x += metrics.advance * scale;
            continue;
        }

        x0 := pos.x + (metrics.x0 * scale);
        y0 := pos.y + (metrics.y0 * scale);
        x1 := pos.x + (metrics.x1 * scale);
        y1 := pos.y + (metrics.y1 * scale);

        ux0 := metrics.x0 / f32(font.info.size);
        uy0 := metrics.y0 / f32(font.info.size);
        ux1 := metrics.x1 / f32(font.info.size);
        uy1 := metrics.y1 / f32(font.info.size);

        
        append(&vertices, [2]f32{x0, y0});
        append(&vertices, [2]f32{x1, y0});
        append(&vertices, [2]f32{x0, y1});
        append(&vertices, [2]f32{x1, y1});
        append(&vertices, [2]f32{x0, y1});
        append(&vertices, [2]f32{x1, y0});

        append(&uvs, [3]f32{ux0, uy0, f32(c-32)});
        append(&uvs, [3]f32{ux1, uy0, f32(c-32)});
        append(&uvs, [3]f32{ux0, uy1, f32(c-32)});
        append(&uvs, [3]f32{ux1, uy1, f32(c-32)});
        append(&uvs, [3]f32{ux0, uy1, f32(c-32)});
        append(&uvs, [3]f32{ux1, uy0, f32(c-32)});

        pos.x += metrics.advance * scale;
    }

    render.add_batch(r, layer, s, font.texture, true, vertices[:], uvs[:], [][0]f32{});
}

@static gui_palette: render.Texture;
draw_rect :: proc(r: ^render.Renderer, s: render.Shader, rect: gui.Rect, layer: int, color_id: gui.Color_ID)
{
    using rect := rect;
    
    vertices := make([][2]f32, 6);
    uvs      := make([][2]f32, 6);

    y = 768 - y - h;

    vertices[0] = {x,   y};
    vertices[1] = {x+w, y+h};
    vertices[2] = {x,   y+h};

    vertices[3] = {x,   y};
    vertices[4] = {x+w, y};
    vertices[5] = {x+w, y+h};

    c_uv := render.texture_palette_index(gui_palette, int(color_id));
    uv_size := 1/f32(gui_palette.info.width);
    uvs[0] = c_uv;
    uvs[1] = {c_uv.x + uv_size, c_uv.y + uv_size};
    uvs[2] = {c_uv.x,           c_uv.y + uv_size};

    uvs[3] = c_uv;
    uvs[4] = {c_uv.x + uv_size, c_uv.y};
    uvs[5] = {c_uv.x + uv_size, c_uv.y + uv_size};

    render.add_batch(r, layer, s, gui_palette, true, vertices, uvs, [][0]f32{});
}

@static gui_win: gui.Window;
@static value: f32 = 50;
@static text_buf := gui.Text_Buffer{};
do_gui :: proc(ctx: ^gui.Context, win: render.Window, dt: f64)
{
    ctx.ctrl.mouse = {control.mouse_down(0), control.mouse_down(1), control.mouse_down(2)};
    ctx.ctrl.cursor = control.get_mouse_pos();
    for k, i in control.KEYBOARD.keys do
        ctx.ctrl.keys_down[i+32] = k == .Pressed || k == .Down || k == .Repeat;
    gui.buffer_append(&ctx.ctrl.input_buf, string(control.KEYBOARD.text_buffer[:]));
    resize(control.KEYBOARD.text_buffer, 0);

    ctx.delta_time = dt;
    gui.begin(ctx);
    
    if .Active in gui.window(ctx, &gui_win, {})
    {
        gui.row(ctx, 3, {70, -70, 0}, 0);
        
        gui.label(ctx, "Row 1:", {});
        if .Submit in gui.button(ctx, "Reset", 0, {}) do
            value = 50;
        if .Submit in gui.button(ctx, "+5", 0, {}) do
            value += 5;
        
        gui.label(ctx, "Row 2:", {});
        gui.slider(ctx, "Slider 1", &value, "%.1f", 0, 100, 0, {});
        if .Submit in gui.button(ctx, "-5", 0, {}) do
            value -= 5;

        gui.row(ctx, 2, {-100, 0}, 0);
        gui.text_input(ctx, "Text input", &text_buf, {.Left});
        /* gui.number_input(ctx, "Number input", &value, "%.1f", 0, 100, 0, {}); */
        gui.window_end(ctx);
    }

    gui.end(ctx);
}

draw_gui :: proc(renderer: ^render.Renderer, ctx: ^gui.Context, sgen, stext: render.Shader, font: render.Font)
{
    draw: gui.Draw;
    for gui.next_draw(ctx, &draw)
    {
        #partial switch d in draw.variant
        {
        case gui.Draw_Rect:
            draw_rect(renderer, sgen, d.rect, draw.layer, d.color_id);
            
        case gui.Draw_Text:
            draw_text(renderer, stext, d.pos, font, d.text, d.size, draw.layer, d.color_id);
        }
    }
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

    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    // glfw.set_input_mode(window.handle, glfw.CURSOR, int(glfw.CURSOR_DISABLED));
    
    vao: u32;
    gl.GenVertexArrays(1, &vao);
    gl.BindVertexArray(vao);

    s := render.init_shader("./shader/vert2d.vs", "./shader/frag2d.fs");
    text_shader := render.init_shader("./shader/text.vs", "./shader/text.fs");
    shader_3d := render.init_shader("./shader/vertex.vs", "./shader/fragment.fs");
    
    gl.ClearColor(0.0, 0.3, 0.4, 0.0);
    // gl.ClearColor(0.55, 0.2, 0.3, 0.0);

    sprite := render.load_sprite("./res/adventurer.sprite");
    render.sprite_set_anim(&sprite, "running");
    adventurer := render.make_entity_2d(&sprite, [2]f32{512-160, 384-160}, [2]f32{10,10});

    font := render.load_font("./res/font/OpenSans-Regular");
    test_str := "Hello, World!";
    
    last_time := glfw.get_time();
    current_time: f64;
    dt: f32;

    time_step := f32(1.0/144.0);
    
    nb_frames  := 0;
    accum_time := 0.0;
    fps_buf: [8]byte;
    fps_str: string;
    
    text_buf.backing = make([]byte, 128);
    gui_ctx := init_gui(window);
    gui_win = gui.init_window(&gui_ctx, "A Window", {256, 100, 412, 110});
    gui_palette = render.texture_palette(gui_ctx.style.colors[:], false);
    gui_ctx.style.font = cast(rawptr)&font;

    renderer := render.init_renderer();
    // renderer.shader_data.resolution = {i32(window.width), i32(window.height)};
    
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

            do_gui(&gui_ctx, window, f64(time_step));
            render.update_entity_2d(&adventurer, time_step);

            /*
            size := adventurer.sprite.dim * adventurer.scale;
            h := f32(window.height)-size.y;
            w := f32(window.width)-size.x;
            adventurer.pos.y =  math.sin(f32(current_time)*4)*(h/8)+h/2;
            adventurer.pos.x =  math.cos(f32(current_time)*4)*-1*(w/8)+w/2;
            */

            dt -= time_step;
        }

        // Only draw if content has been updated
        if updated
        {
            gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

            render.draw_entity_2d(s, &adventurer);
           
            fps_w := render.get_text_width(font, string(fps_str[:]), 24);
            render.draw_text(text_shader, font, string(fps_str[:]),
                             {f32(window.width)-fps_w, f32(window.height-24)},
                             24);

            render.begin_render(&renderer);
            draw_gui(&renderer, &gui_ctx, s, text_shader, font);
            
            gl.Disable(gl.DEPTH_TEST);
            gl.DepthMask(gl.FALSE);
            render.draw_all(&renderer);
            gl.Enable(gl.DEPTH_TEST);
            gl.DepthMask(gl.TRUE);
            
            glfw.swap_buffers(window.handle);
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
