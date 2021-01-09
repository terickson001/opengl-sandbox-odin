package main

import gfnt "shared:gl_font"
import "shared:glfw"
import "shared:gl"

import "core:fmt"

import render "rendering"
import "gui"
import "control"

Gui_State :: struct
{
    window: gui.Window,
    palette: render.Texture,
    
    slider_value: f32,
    other_value: f32,
    text_buffer: gui.Text_Buffer,
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
        other_value = 128;
        text_buffer.backing = make([]byte, 128);
    }
    return ctx, state;
}

update_gui_inputs :: proc(ctx: ^gui.Context, dt: f64)
{
    for _, i in ctx.ctrl.mouse 
    {
        ctx.ctrl.mouse[i] = control.MOUSE.buttons[i] == .Down || control.MOUSE.buttons[i] == .Pressed;
    }
    ctx.ctrl.cursor = control.get_mouse_pos();
    for k, i in control.KEYBOARD.keys 
    {
        ctx.ctrl.keys_down[i+32] = k == .Pressed || k == .Down || k == .Repeat;
    }
    gui.buffer_append(&ctx.ctrl.kb_input_buf, string(control.KEYBOARD.text_buffer[:]));
    resize(control.KEYBOARD.text_buffer, 0);
    ctx.delta_time = dt;
}

do_gui :: proc(state: ^Gui_State, ctx: ^gui.Context, win: render.Window)
{
    if .Active in gui.window(ctx, &state.window, {})
    {
        gui.row(ctx, 3, {70, -70, 0}, 0);
        
        gui.label(ctx, "Row 1:", {});
        if .Submit in gui.button(ctx, "Reset", 0, {}) 
        {
            state.slider_value = 50;
        }
        if .Submit in gui.button(ctx, "+5", 0, {}) 
        {
            state.slider_value += 5;
        }
        
        gui.label(ctx, "Row 2:", {});
        gui.slider(ctx, "Slider 1", &state.slider_value, "%.1f", 0, 100, 0, {});
        if .Submit in gui.button(ctx, "-5", 0, {}) 
        {
            state.slider_value -= 5;
        }
        
        gui.row(ctx, 2, {-100, 0}, 0);
        gui.text_input(ctx, "Text input", state.text_buffer.backing, {.Left});
        @static other_buf: [256]byte;
        // gui.text_input(ctx, "Text input right", other_buf[:], {});
        // gui.number_input(ctx, "Number input Left", &state.other_value, "%.1f", 0, 100, 0, {});
        gui.number_input(ctx, "Number input Right", &state.slider_value, "%.1f", 0, 100, 0, {});
        gui.window_end(ctx);
    }
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
    gl.BindTexture(gl.TEXTURE_2D, palette.id);
    
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
    assert(font != nil);
    out := int((size+2)/4)*4;
    
    largest := cast(int)font.size_metrics[0].size;
    smallest := cast(int)font.size_metrics[len(font.size_metrics)-1].size;
    out = min(max(out, smallest), largest);
    return out;
}