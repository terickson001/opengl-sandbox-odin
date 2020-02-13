package control

import "core:fmt"
import "shared:glfw"

Mouse :: struct
{
    buttons : [8]Button_State,
    pos     : [2]f32,
    scroll  : [2]f32,
}
@static MOUSE: Mouse;

update_mousepos :: proc "c" (window: glfw.Window_Handle, x, y: f64)
{
    MOUSE.pos = {f32(x), f32(y)};
}

update_mousescroll :: proc "c" (window: glfw.Window_Handle, xoff, yoff: f64)
{
    MOUSE.scroll = {f32(xoff), f32(yoff)};
}

update_mousebuttons :: proc "c" (window: glfw.Window_Handle, button, action, mods: i32)
{
    if button > 7
    {
        fmt.eprintf("Mouse button '%d' out of range\n", button);
        return;
    }

    #partial switch glfw.Key_State(action)
    {
        case .PRESS:   MOUSE.buttons[button] = .Pressed;
        case .RELEASE: MOUSE.buttons[button] = .Released;
    }
}

get_mouse_button :: proc(m: int) -> Button_State
{
    if m > 7
    {
        fmt.eprintf("Mouse button '%d' out of range\n", m);
        return .None;
    }

    ret := MOUSE.buttons[m];
    #partial switch ret
    {
        case .Pressed:  MOUSE.buttons[m] = .Down;
        case .Released: MOUSE.buttons[m] = .Up;
    }

    return ret;
}

mouse_down :: proc(m: int) -> bool
{
    state := get_mouse_button(m);
    if state == .Pressed || state == .Down do
        return true;

    MOUSE.buttons[m] = state;
    return false;
}

mouse_pressed :: proc(m: int) -> bool
{
    state := get_mouse_button(m);
    if state == .Pressed do
        return true;

    MOUSE.buttons[m] = state;
    return false;
}

mouse_released :: proc(m: int) -> bool
{
    state := get_mouse_button(m);
    if state == .Released do
        return true;

    MOUSE.buttons[m] = state;
    return false;
}

get_mouse_pos :: proc() -> [2]f32
{
    return MOUSE.pos;
}

set_mouse_pos :: proc(pos: [2]f32)
{
    MOUSE.pos = pos;
}

get_mouse_scroll :: proc() -> [2]f32
{
    ret := MOUSE.scroll;
    MOUSE.scroll = {0, 0};
    return ret;
}
