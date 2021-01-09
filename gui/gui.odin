package gui

import "core:fmt"
import "core:hash"
import "core:mem"
import "core:sort"
import "core:strings"
import "core:intrinsics"
import "core:math"
import "core:os"

import "../util"

// @todo(Tyler): Clipping

Cursor :: enum u8
{
    Arrow,
    Bar,
    HResize,
    VResize,
    Hand,
}

Res :: enum
{
    Submit,
    Update,
    Active,
}
Results :: bit_set[Res];

Opt :: enum
{
    Right,
    Left,
    Border,
    Hold_Focus,
    Bottom,
    Top,
}
Options :: bit_set[Opt];

Color_ID :: enum u8
{
    Base,
    Base_Hover,
    Base_Focus,
    Button,
    Button_Hover,
    Button_Focus,
    Border,
    Text,
    Mark,
    Title,
    Title_Text,
    Window,
    Close,
}

Style :: struct
{
    font        : rawptr,
    text_height : int,
    size        : [2]f32,
    border_size : int,
    padding     : int,
    spacing     : int,
    thumb_size  : int,
    title_size  : int,
    colors      : [len(Color_ID)][4]f32,
}

@static DEFAULT_STYLE := Style{
    font        = nil,
    text_height = 16,
    size        = {70, 25},
    border_size = 1,
    padding     = 5,
    spacing     = 2,
    thumb_size  = 15,
    title_size  = 25,
    colors      = {
        {30,  30,  30,  255}, // Base
        {35,  35,  35,  255}, // Base_Hover
        {40,  40,  40,  255}, // Base_Focus
        {75,  75,  75,  255}, // Button
        {95,  95,  95,  255}, // Button_Hover
        {115, 115, 115, 255}, // Button_Focus
        {25,  25,  25,  255}, // Border
        {230, 230, 230, 255}, // Text
        {90,  100, 225, 70 }, // Mark
        {25,  25,  25,  255}, // Title
        {240, 240, 240, 255}, // Title_Text
        {50,  50,  50,  255}, // Window
        {224, 40,  40,  255}, // Close
    },
};

Rect :: struct
{
    x, y: f32,
    w, h: f32,
}

Draw_Kind :: enum u8
{
    Rect = 1,
    Text,
    Icon,
    Clip,
}

Draw_Rect :: struct
{
    rect     : Rect,
    color    : [4]f32,
    color_id : Color_ID,
}

Draw_Text :: struct
{
    pos      : [2]f32,
    size     : f32,
    color    : [4][4]f32,
    color_id : Color_ID,
    text     : string,
}

Draw_Icon :: struct
{
    rect     : Rect,
    id       : int,
    color    : [4]f32,
    color_id : Color_ID,
}

Draw_Clip :: struct
{
    rect: Rect,
}

Draw :: struct
{
    layer : int,
    variant : union
    {
        Draw_Rect,
        Draw_Text,
        Draw_Icon,
        Draw_Clip,
    }
}

MAX_ROW_ITEMS :: 16;
Layout :: struct
{
    pos       : [2]f32,
    size      : [2]f32,
    items     : int,
    widths    : [MAX_ROW_ITEMS]f32,
    curr_item : int,
}

Text_State :: struct
{
    cursor              : int,
    mark                : int,
    cursor_last_updated : f64,
    offset              : int,
}

Window :: struct
{
    title     : string,
    rect      : Rect,
    container : Rect,
    open      : bool,
    layer     : int,
    draws     : struct
    {
        start, end: int
    },
}

Display :: struct
{
    width  : f32,
    height : f32,
}

Key_Code :: enum u16
{
    None          = 0,
    Space         = 32,
    Apostrophe    = 39,
    Comma         = 44,
    Minus         = 45,
    Period        = 46,
    Slash         = 47,
    Num_0         = 48,
    Num_1         = 49,
    Num_2         = 50,
    Num_3         = 51,
    Num_4         = 52,
    Num_5         = 53,
    Num_6         = 54,
    Num_7         = 55,
    Num_8         = 56,
    Num_9         = 57,
    Semicolon     = 59,
    Equal         = 61,
    A             = 65,
    B             = 66,
    C             = 67,
    D             = 68,
    E             = 69,
    F             = 70,
    G             = 71,
    H             = 72,
    I             = 73,
    J             = 74,
    K             = 75,
    L             = 76,
    M             = 77,
    N             = 78,
    O             = 79,
    P             = 80,
    Q             = 81,
    R             = 82,
    S             = 83,
    T             = 84,
    U             = 85,
    V             = 86,
    W             = 87,
    X             = 88,
    Y             = 89,
    Z             = 90,
    Left_Bracket  = 91,
    Backslash     = 92,
    Right_Bracket = 93,
    Grave_Accent  = 96,
    World_1       = 161,
    World_2       = 162,
    Escape        = 256,
    Enter         = 257,
    Tab           = 258,
    Backspace     = 259,
    Insert        = 260,
    Delete        = 261,
    Right         = 262,
    Left          = 263,
    Down          = 264,
    Up            = 265,
    Page_Up       = 266,
    Page_Down     = 267,
    Home          = 268,
    End           = 269,
    Caps_Lock     = 280,
    Scroll_Lock   = 281,
    Num_Lock      = 282,
    Print_Screen  = 283,
    Pause         = 284,
    F1            = 290,
    F2            = 291,
    F3            = 292,
    F4            = 293,
    F5            = 294,
    F6            = 295,
    F7            = 296,
    F8            = 297,
    F9            = 298,
    F10           = 299,
    F11           = 300,
    F12           = 301,
    F13           = 302,
    F14           = 303,
    F15           = 304,
    F16           = 305,
    F17           = 306,
    F18           = 307,
    F19           = 308,
    F20           = 309,
    F21           = 310,
    F22           = 311,
    F23           = 312,
    F24           = 313,
    F25           = 314,
    Kp_0          = 320,
    Kp_1          = 321,
    Kp_2          = 322,
    Kp_3          = 323,
    Kp_4          = 324,
    Kp_5          = 325,
    Kp_6          = 326,
    Kp_7          = 327,
    Kp_8          = 328,
    Kp_9          = 329,
    Kp_Dot        = 330,
    Kp_Divide     = 331,
    Kp_Multiply   = 332,
    Kp_Subtract   = 333,
    Kp_Add        = 334,
    Kp_Enter      = 335,
    Kp_Equal      = 336,
    LShift        = 340,
    LCtrl         = 341,
    LAlt          = 342,
    LSuper        = 343,
    RShift        = 344,
    RCtrl         = 345,
    RAlt          = 346,
    RSuper        = 347,
    Menu          = 348,
    Last          = 348,
}

MAX_KEY_COUNT :: 512;
Control :: struct
{
    repeat_delay : f32,
    repeat_int   : f32,
    key_map      : #partial [Key_Code]int,
    
    cursor       : [2]f32,
    scroll       : [2]f32,
    mouse        : [3]bool,
    
    keys_down    : []bool,
    key_times    : []f32,
    kb_input_buf : Text_Buffer,
    
    capture_mouse: bool,
}

Context :: struct
{
    hover          : u64,
    focus          : u64,
    last_focus     : u64,
    last_hover     : u64,
    
    layer          : int,
    
    hashes         : [dynamic]u64,
    
    containers     : [dynamic]Rect,
    layout         : Layout,
    style          : Style,
    
    sections       : map[u64]b32,
    
    draws          : [dynamic]Draw,
    draw_idx       : int,
    draw_win       : int,
    cursor_icon    : Cursor,
    
    display        : Display,
    
    // Inputs
    using ctrl     : Control,
    last_cursor    : [2]f32,
    last_mouse     : [3]bool,
    last_keys_down : []bool,
    last_key_times : []f32,
    
    delta_time     : f64,
    time           : f64,
    
    // Window State
    window_hover   : ^Window,
    window_focus   : ^Window,
    win_top_layer  : int,
    windows        : [dynamic]^Window,
    
    text_box       : Text_State,
    
    get_text_width : proc(font: rawptr, text: string, size: int) -> f32,
    num_input_buf  : Text_Buffer,
    text_input_buf : Text_Buffer,
    text_input_id  : u64,
}

@private
hash_mix :: proc(a, b: u64) -> u64
{
    data := transmute([16]u8)[2]u64{a, b};
    return hash.crc64(data[:]);
}

@private
hash_id :: proc(data: rawptr, size: int) -> u64
{
    slice := mem.slice_ptr((^byte)(data), size);
    return hash.crc64(slice);
}

@private
get_id :: proc(using ctx: ^Context, lbl: string, icon: int) -> u64
{
    lbl  := transmute([]byte)lbl;
    icon := icon;
    id := len(lbl) > 0
        ? hash_id(&lbl[0], len(lbl))
        : hash_id(&icon, size_of(icon));
    if parent_hash, ok := curr_hash(ctx); ok
    {
        return hash_mix(parent_hash, id);
    }
    return id;
}

mouse_down     :: proc(using ctx: ^Context, b: int) -> bool {return  mouse[b];                  }
mouse_pressed  :: proc(using ctx: ^Context, b: int) -> bool {return  mouse[b] && !last_mouse[b];}
mouse_up       :: proc(using ctx: ^Context, b: int) -> bool {return !mouse[b];                  }
mouse_released :: proc(using ctx: ^Context, b: int) -> bool {return !mouse[b] &&  last_mouse[b];}

key_down     :: proc(using ctx: ^Context, k: Key_Code) -> bool {return  keys_down[key_map[k]];}
key_pressed  :: proc(using ctx: ^Context, k: Key_Code) -> bool {return  keys_down[key_map[k]] && !last_keys_down[key_map[k]];}
key_up       :: proc(using ctx: ^Context, k: Key_Code) -> bool {return !keys_down[key_map[k]];}
key_released :: proc(using ctx: ^Context, k: Key_Code) -> bool {return !keys_down[key_map[k]] &&  last_keys_down[key_map[k]];}

key_repeat :: proc(using ctx: ^Context, k: Key_Code) -> bool
{
    if key_pressed(ctx, k) do return true;
    if key_down(ctx, k)
    {
        prev_repeat := math.floor((last_key_times[key_map[k]] - repeat_delay) / repeat_int);
        new_repeat  := math.floor((key_times[key_map[k]]      - repeat_delay) / repeat_int);
        return new_repeat > prev_repeat && new_repeat > 0;
    }
    return false;
}

push_container :: proc(using ctx: ^Context, container: Rect)
{
    append(&containers, container);
}

curr_container :: proc(using ctx: ^Context) -> Rect
{
    return containers[len(containers)-1];
}

pop_container :: proc(using ctx: ^Context)
{
    resize(&containers, len(containers)-1);
}

@(deferred_out=pop_hash)
SCOPE_ID :: proc(using ctx: ^Context, lbl: string) -> ^Context
{
    push_hash(ctx, lbl);
    return ctx;
}

push_hash :: proc(using ctx: ^Context, lbl: string)
{
    append(&hashes, get_id(ctx, lbl, 0));
}

curr_hash :: proc(using ctx: ^Context) -> (u64, bool)
{
    if len(hashes) == 0 do return 0, false;
    return hashes[len(hashes)-1], true;
}

pop_hash :: proc(using ctx: ^Context)
{
    resize(&hashes, len(hashes)-1);
}

init :: proc(allocator := context.allocator) -> (ctx: Context)
{
    using ctx;
    
    style = DEFAULT_STYLE;
    draws      = make([dynamic]Draw, allocator);
    windows    = make([dynamic]^Window, allocator);
    containers = make([dynamic]Rect, allocator);
    hashes     = make([dynamic]u64, allocator);
    
    kb_input_buf.backing = make([]byte, 512, allocator);
    num_input_buf.backing = make([]byte, 512, allocator);
    text_input_buf.backing = make([]byte, 512, allocator);
    
    key_times = make([]f32, MAX_KEY_COUNT, allocator);
    keys_down = make([]bool, MAX_KEY_COUNT, allocator);
    last_keys_down = make([]bool, MAX_KEY_COUNT, allocator);
    last_key_times = make([]f32, MAX_KEY_COUNT, allocator);
    
    repeat_delay = 0.65;
    repeat_int   = 0.03;
    
    for _, i in key_times
    {
        key_times[i] = -1;
        last_key_times[i] = -1;
    }
    
    return ctx;
}

begin :: proc(using ctx: ^Context)
{
    resize(&draws,      0);
    resize(&windows,    0);
    resize(&containers, 0);
    
    draw_idx = 0;
    draw_win = 0;
    
    time += delta_time;
    
    push_container(ctx, {0, 0, display.height, display.width});
    
    layout.pos = {0, 0};
    layout.items = 1;
    mem.zero_slice(layout.widths[:]);
    layout.curr_item = 0;
    
    layer = 0;
    cursor_icon = .Arrow;
    
    for _, i in keys_down 
    {
        key_times[i] = keys_down[i] ? (key_times[i] == -1.0 ? 0.0 : key_times[i] + f32(delta_time)) : -1.0;
    }
    
    any_mouse_down := false;
    for b in mouse do any_mouse_down |= b;
    capture_mouse = window_hover != nil;
}

@private
win_zcmp :: proc(a, b: ^Window) -> int { return a.layer - b.layer; }

end :: proc(using ctx: ^Context)
{
    // Reset input state
    kb_input_buf.used = 0;
    
    copy(last_cursor[:], cursor[:]);
    copy(last_mouse[:], mouse[:]);
    copy(last_keys_down[:], keys_down[:]);
    copy(last_key_times[:], key_times[:]);
    
    mem.zero_slice(cursor[:]);
    mem.zero_slice(mouse[:]);
    mem.zero_slice(keys_down[:]);
    mem.zero_slice(scroll[:]);
    
    last_focus = focus;
    last_hover = hover;
    
    // Sort windows by layer
    sort.quick_sort_proc(windows[:], win_zcmp);
    
    // Stack windows
    prev_max := 0;
    new_max := 0;
    for _, i in windows
    {
        win := windows[i];
        win.layer = i;
        
        for d in (win.draws.start)..(win.draws.end)
        {
            draws[d].layer += prev_max + 1;
            new_max = max(new_max, draws[d].layer);
        }
        
        prev_max = new_max;
    }
    
    win_top_layer = len(windows);
    layer = 0;
}

row :: proc(using ctx: ^Context, items: int, widths: []f32, height: int)
{
    layout.size.y = height != 0 ? f32(height) : style.size.y;
    layout.items = items;
    copy(layout.widths[:], widths);
    layout.curr_item = 0;
}

layout_peek_rect :: proc(using ctx: ^Context) -> Rect
{
    rect := Rect{};
    container := curr_container(ctx);
    
    rect.x = container.x + layout.pos.x;
    rect.y = container.y + layout.pos.y;
    
    rect.w = layout.widths[layout.curr_item];
    if rect.w > 0 && rect.w < 1 do rect.w = container.w * rect.w;
    rect.h = layout.size.y;
    
    // Position relative to right for negative values
    if rect.w <= 0 
    {
        rect.w += container.x + container.w - rect.x;
    }
    
    // Adjust for spacing
    rect.x += f32(style.spacing);
    rect.y += f32(style.spacing);
    rect.w -= f32(style.spacing) * 2;
    rect.h -= f32(style.spacing) * 2;
    
    return rect;
}

layout_rect :: proc(using ctx: ^Context) -> Rect
{
    rect := layout_peek_rect(ctx);
    
    // Advance layout position
    layout.pos.x += rect.w + f32(style.padding)*2;
    
    layout.curr_item += 1;
    if layout.curr_item == layout.items
    {
        layout.pos.x = 0;
        layout.pos.y += layout.size.y;
        layout.curr_item = 0;
    }
    
    return rect;
}

text_rect :: proc(using ctx: ^Context, str: string) -> Rect
{
    rect := Rect{};
    
    rect.h = f32(style.text_height);
    rect.w = get_text_width(style.font, str, int(rect.h));
    
    return rect;
}

align_rect :: proc(using ctx: ^Context, bound, rect: Rect, opt := Options{}) -> Rect
{
    ret := Rect{};
    ret.w = rect.w;
    ret.h = rect.h;
    
    bound := bound;
    bound.x += f32(style.padding);
    bound.y += f32(style.padding);
    bound.w -= f32(style.padding)*2;
    bound.h -= f32(style.padding)*2;
    
    if .Right in opt 
    {
        ret.x = bound.x+bound.w - rect.w;
    }
    else if .Left in opt 
    {
        ret.x = bound.x;
    }
    else // Center
    {
        ret.x = bound.x + (bound.w - rect.w)/2;
    }
    
    if .Bottom in opt 
    {
        ret.y = bound.y+bound.h - rect.h;
    }
    else if .Top in opt 
    {
        ret.y = bound.y;
    }
    else // Center
    {
        ret.y = bound.y + (bound.h - rect.h)/2;
    }
    
    return ret;
}

is_hover :: proc(using ctx: ^Context, lbl: string, icon: int) -> bool
{
    return get_id(ctx, lbl, icon) == hover;
}

is_focus :: proc(using ctx: ^Context, lbl: string, icon: int) -> bool
{
    return get_id(ctx, lbl, icon) == focus;
}

is_mouse_over :: proc(using ctx: ^Context, rect: Rect) -> bool
{
    m := cursor;
    
    return (rect.x <= m.x && m.x <= rect.x+rect.w &&
            rect.y <= m.y && m.y <= rect.y+rect.h);
}

update_focus :: proc(using ctx: ^Context, rect: Rect, id: u64, opt := Options{})
{
    mouse_over := is_mouse_over(ctx, rect);
    
    if mouse_over && !mouse_down(ctx, 0) 
    {
        hover = id;
    }
    
    if focus == id &&
        ((mouse_pressed(ctx, 0) && !mouse_over) ||
         (!mouse_down(ctx, 0) && .Hold_Focus not_in opt)) 
    {
        focus = 0;
    }
    
    if hover == id
    {
        if      !mouse_over           do hover = 0;
        else if mouse_pressed(ctx, 0) do focus = id;
    }
}

add_draw :: proc(using ctx: ^Context) -> ^Draw
{
    draw := Draw{};
    append(&draws, draw);
    return &draws[len(draws)-1];
}

draw_border :: proc(using ctx: ^Context, rect: Rect, id: u64)
{
    bs := f32(style.border_size);
    c  := Color_ID.Border;
    
    draw_rect(ctx, {rect.x,           rect.y,           bs,            rect.h}, id, c, {}); // Left
    draw_rect(ctx, {rect.x+rect.w-bs, rect.y,           bs,            rect.h}, id, c, {}); // Right
    draw_rect(ctx, {rect.x+bs,        rect.y,           rect.w-(2*bs), bs},     id, c, {}); // Top
    draw_rect(ctx, {rect.x+bs,        rect.y+rect.h-bs, rect.w-(2*bs), bs},     id, c, {}); // Bottom
}

draw_text :: proc(using ctx: ^Context, str: string, rect: Rect, color_id: Color_ID, opt := Options{})
{
    pos := [2]f32{};
    
    pos.x = rect.x;
    pos.y = rect.y;
    
    draw := add_draw(ctx);
    draw.layer = layer;
    draw.variant  =
        Draw_Text{
        pos = pos,
        size = rect.h,
        color_id = color_id,
        color = style.colors[color_id],
        text = strings.clone(str),
    };
}

draw_rect :: proc(using ctx: ^Context, rect: Rect, id: u64, color_id: Color_ID, opt := Options{})
{
    color_id := color_id;
    if color_id == .Button || color_id == .Base
    {
        if      id == focus do color_id += Color_ID(2);
        else if id == hover do color_id += Color_ID(1);
    }
    color := style.colors[color_id];
    
    draw := add_draw(ctx);
    draw.layer = layer;
    draw.variant  =
        Draw_Rect{
        rect = rect,
        color = color,
        color_id = color_id,
    };
    
    if .Border in opt 
    {
        draw_border(ctx, rect, id);
    }
}

next_draw :: proc(using ctx: ^Context, ret: ^Draw) -> bool
{
    if len(draws) == 0 do return false;
    if draw_idx > windows[draw_win].draws.end
    {
        if draw_win == len(windows)-1 do return false;
        draw_win += 1;
        draw_idx = windows[draw_win].draws.start;
    }
    
    ret^ = draws[draw_idx];
    draw_idx += 1;
    return true;
}

label :: proc(using ctx: ^Context, str: string, opt := Options{})
{
    bounds := layout_rect(ctx);
    lbl_rect := text_rect(ctx, str);
    draw_text(ctx, str, align_rect(ctx, bounds, lbl_rect, opt), .Text, opt);
}

button :: proc(using ctx: ^Context, lbl: string, icon: int, opt := Options{}) -> (res: Results)
{
    id := get_id(ctx, lbl, icon);
    
    rect := layout_rect(ctx);
    
    base_layer := layer;
    // was_focus  := id == focus;
    update_focus(ctx, rect, id, {});
    
    if last_focus == id && mouse_released(ctx, 0) && id == hover
    {
        res |= {.Submit};
    }
    
    draw_rect(ctx, rect, id, .Button, {.Border});
    
    layer = base_layer+1;
    {
        lbl_text := text_rect(ctx, lbl);
        aligned  := align_rect(ctx, rect, lbl_text, opt);
        draw_text(ctx, lbl, aligned, .Text, opt);
    }
    layer = base_layer;
    
    return res;
}

slider :: proc(using ctx: ^Context, label: string, value: ^$T, fmt_str: string, lower, upper, step: T, opt := Options{}) -> (res: Results) where intrinsics.type_is_numeric(T)
{
    id := get_id(ctx, label, 0);
    
    prev := value^;
    rect := layout_rect(ctx);
    update_focus(ctx, rect, id, opt);
    
    tw := T(style.thumb_size);
    if id == focus && mouse_down(ctx, 0)
    {
        value^ = lower + ((cursor.x-rect.x-(tw/2)) / (rect.w-tw) * (upper-lower));
        if step > 0 
        {
            value^ = math.trunc((value^ + step/2) / step) * step;
        }
    }
    else if id == hover && scroll.y > 0
    {
        add := scroll.y * (step > 0 ? step : T(1));
        value^ += add;
    }
    value^ = clamp(value^, lower, upper);
    
    if value^ != prev 
    {
        res |= {.Update};
    }
    
    base_layer := layer;
    
    // Draw Slider
    draw_rect(ctx, rect, id, .Base, opt ~ {.Border});
    
    // Draw Thumb
    layer = base_layer+1;
    {
        percentage := (value^-lower)/(upper - lower);
        thumb := Rect{rect.x + percentage * (rect.w-tw), rect.y, tw, rect.h};
        draw_rect(ctx, thumb, id, .Button, opt);
    }
    
    // Draw value
    layer = base_layer+2;
    {
        val_buf: [128]byte;
        fmt.bprintf(val_buf[:], fmt_str, value^);
        val_rect := text_rect(ctx, string(val_buf[:]));
        aligned  := align_rect(ctx, rect, val_rect, opt);
        draw_text(ctx, string(val_buf[:]), aligned, .Text, opt);
    }
    layer = base_layer;
    
    return res;
}

Text_Buffer :: struct
{
    backing: []byte,
    used: int,
}

buffer_string :: proc(buf: Text_Buffer) -> string
{
    return string(buf.backing[:buf.used]);
}

buffer_append :: proc(buf: ^Text_Buffer, str: string)
{
    _insert_string_at(buf, buf.used, str);
}
@private
_insert_string_at :: proc(buf: ^Text_Buffer, idx: int, str: string) -> int
{
    slen := min(len(str), len(buf.backing)-buf.used);
    
    copy(buf.backing[idx+slen:], buf.backing[idx:buf.used]);
    copy(buf.backing[idx:], str[:]);
    
    buf.used += slen;
    
    return slen;
}

@private
_remove_string_between :: proc(buf: ^Text_Buffer, start, end: int) -> int
{
    start, end := start, end;
    
    if start == end 
    {
        return 0;
    }
    
    ret := end - start;
    if start > end
    {
        start, end = end, start;
        ret = 0;
    }
    
    copy(buf.backing[start:], buf.backing[end:buf.used]);
    buf.used -= end - start;
    
    return ret;
}

@private
_remove_char_at :: proc(buf: ^Text_Buffer, idx: int)
{
    copy(buf.backing[idx-1:buf.used], buf.backing[idx:]);
    buf.used -= 1;
}

@private
_update_cursor :: proc(using ctx: ^Context, buf: ^Text_Buffer, change: int)
{
    if key_down(ctx, .LShift) && text_box.mark == -1
    {
        text_box.mark = text_box.cursor;
    }
    else if !key_down(ctx, .LShift) && text_box.mark != -1
    {
        mark := text_box.mark;
        text_box.mark = -1;
        
        if change == -1
        {
            text_box.cursor = min(text_box.cursor, mark);
            return;
        }
        else if change == 1
        {
            text_box.cursor = max(text_box.cursor, mark);
            return;
        }
    }
    
    text_box.cursor += change;
    text_box.cursor = clamp(text_box.cursor, 0, buf.used);
    
    if text_box.cursor == text_box.mark 
    {
        text_box.mark = -1;
    }
}

@private
char_is_alphanum :: proc(c: byte) -> bool
{
    return ('a' <= c && c <= 'z') ||
        ('A' <= c && c <= 'Z') ||
        ('0' <= c && c <= '9');
}

@private
_word_beg :: proc(buf: ^Text_Buffer, idx: int) -> int
{
    idx := idx;
    for idx-1 > 0 && !char_is_alphanum(buf.backing[idx-1]) 
    {
        idx -= 1;
    }
    for idx-1 > 0 && char_is_alphanum(buf.backing[idx-1]) 
    {
        idx -= 1;
    }
    if idx == 1 && char_is_alphanum(buf.backing[idx]) 
    {
        idx -= 1;
    }
    
    return max(idx, 0);
}

@private
_word_end :: proc(buf: ^Text_Buffer, idx: int) -> int
{
    idx := idx;
    for idx < buf.used && !char_is_alphanum(buf.backing[idx]) 
    {
        idx += 1;
    }
    for idx < buf.used && char_is_alphanum(buf.backing[idx]) 
    {
        idx += 1;
    }
    
    return min(idx, buf.used);
}

text_input :: proc(using ctx: ^Context, label: string, backing: []byte, opt := Options{}) -> (res: Results)
{
    id := get_id(ctx, label, 0);
    
    rect := layout_rect(ctx);
    
    update_focus(ctx, rect, id, opt | {.Hold_Focus});
    
    if id == hover 
    {
        cursor_icon = .Bar;
    }
    
    cursor_start := text_box.cursor;
    content_rect: Rect;
    
    buf := &text_input_buf;
    init_state := false;
    /***** EDIT TEXT *****/
    if id == focus && (text_input_id == 0 || text_input_id == id)
    {
        if text_input_id == 0 
        {
            buf.backing = make([]byte, len(backing));
            copy(buf.backing, backing);
            for c, i in backing 
            {
                if c != '\x00' do buf.used += 1;
            }
            text_input_id = id;
            init_state = true;
        }
        
        if last_focus != id || init_state
        {
            text_box.mark = buf.used > 0 ? 0 : -1;
            text_box.cursor = buf.used;
        }
        
        if kb_input_buf.used > 0
        {
            if text_box.mark != -1
            {
                text_box.cursor -= _remove_string_between(buf, text_box.mark, text_box.cursor);
                text_box.mark = -1;
            }
            text_box.cursor += _insert_string_at(buf, text_box.cursor, buffer_string(kb_input_buf));
        }
        
        // Backspace
        if key_repeat(ctx, .Backspace)
        {
            if text_box.mark != -1 // Delete Marked Region
            {
                text_box.cursor -= _remove_string_between(buf, text_box.mark, text_box.cursor);
            }
            else if key_down(ctx, .LCtrl)
            {
                word_index := _word_beg(buf, text_box.cursor);
                text_box.cursor -= _remove_string_between(buf, word_index, text_box.cursor);
            }
            else if text_box.cursor > 0
            {
                _remove_char_at(buf, text_box.cursor);
                text_box.cursor -= 1;
            }
            text_box.mark = -1;
        }
        else if key_repeat(ctx, .Delete)
        {
            if text_box.mark != -1 // Delete Marked Region
            {
                text_box.cursor -= _remove_string_between(buf, text_box.mark, text_box.cursor);
            }
            else if key_down(ctx, .LCtrl)
            {
                word_index := _word_end(buf, text_box.cursor);
                _remove_string_between(buf, text_box.cursor, word_index);
            }
            else if text_box.cursor < buf.used
            {
                _remove_char_at(buf, text_box.cursor+1);
            }
            text_box.mark = -1;
        }
        
        // Enter
        if key_pressed(ctx, .Enter)
        {
            focus = 0;
            text_input_id = 0;
            mem.zero_slice(backing);
            copy(backing, buffer_string(buf^));
            delete(buf.backing);
            buf^ = {};
            res |= {.Submit};
        }
        
        // Cursor Movement
        if key_down(ctx, .LCtrl) && key_pressed(ctx, .A)
        {
            text_box.mark = 0;
            text_box.cursor = buf.used;
        }
        
        if key_repeat(ctx, .Left)
        {
            change := -1;
            if key_down(ctx, .LCtrl) 
            {
                change = _word_beg(buf, text_box.cursor) - text_box.cursor;
            }
            _update_cursor(ctx, buf, change);
        }
        else if key_repeat(ctx, .Right)
        {
            change := 1;
            if key_down(ctx, .LCtrl) 
            {
                change = _word_end(buf, text_box.cursor) - text_box.cursor;
            }
            _update_cursor(ctx, buf, change);
        }
        else if key_pressed(ctx, .Home) || key_pressed(ctx, .Up)
        {
            _update_cursor(ctx, buf, -buf.used);
        }
        else if key_pressed(ctx, .End) || key_pressed(ctx, .Down)
        {
            _update_cursor(ctx, buf, +buf.used);
        }
    }
    
    if id != focus && text_input_id == id
    {
        text_input_id = 0;
        copy(backing, buffer_string(buf^));
        delete(buf.backing);
        buf^ = {};
        res |= {.Submit};
    }
    
    /***** EDIT TEXT END *****/
    
    // @Todo(Tyler): Track length of buf
    display_text := id == text_input_id ? buffer_string(buf^) : string(backing);
    content_rect = text_rect(ctx, display_text);
    content_rect = align_rect(ctx, rect, content_rect, opt);
    
    /***** TEXT SELECTION *****/
    if id == focus && mouse_down(ctx, 0) && buf.used > 0
    {
        pos := content_rect.x;
        cw := f32(0);
        index := 0;
        for index < buf.used && pos < cursor.x
        {
            cw = get_text_width(style.font, buffer_string(buf^)[index:][:1], style.text_height);
            index += 1;
            pos += cw;
        }
        index = max(index-1, 0);
        if cw > 0 && pos - cursor.x < (cursor.x - (pos-cw)) && index < buf.used 
        {
            index += 1;
        }
        
        if mouse_pressed(ctx, 0)
        {
            text_box.cursor = index;
            text_box.mark = -1;
        }
        else
        {
            if text_box.mark == -1 && text_box.cursor != index 
            {
                text_box.mark = text_box.cursor;
            }
            text_box.cursor = index;
        }
        
    }
    /***** TEXT SELECTION END *****/
    
    /***** TEXT SCROLL *****/
    cursor_pos := f32(0);
    offset_x   := f32(0);
    if id == focus
    {
        offset_x = get_text_width(style.font, buffer_string(buf^)[:text_box.offset], style.text_height);
        content_rect.x -= offset_x;
        
        cursor_pos = get_text_width(style.font, buffer_string(buf^)[:text_box.cursor], style.text_height);
        
        box_min := content_rect.x + offset_x;
        box_max := box_min + (rect.w - f32(style.padding*2));
        cursor_rel := content_rect.x + cursor_pos;
        if cursor_rel > box_max // Scroll forward
        {
            diff := cursor_rel - box_max;
            sum := f32(0);
            i := text_box.cursor - 1;
            for sum < diff
            {
                sum += get_text_width(style.font, buffer_string(buf^)[i:][:1], style.text_height);
                i -= 1;
                text_box.offset += 1;
            }
            content_rect.x -= sum;
        }
        else if cursor_rel < box_min // Scroll Backwards
        {
            diff := box_min - cursor_rel;
            sum := f32(0);
            i := text_box.cursor;
            for sum < diff
            {
                sum += get_text_width(style.font, buffer_string(buf^)[i:][:1], style.text_height);
                i += 1;
                text_box.offset -= 1;
            }
            content_rect.x += sum;
        }
        else if (text_box.offset > 0) // Scroll backwards if text can fit
        {
            // @Note(Tyler): Get width of one extra character to make sure the entire character will fit
            offset_to_end := get_text_width(style.font, buffer_string(buf^)[text_box.offset-1:], style.text_height);
            if box_min + offset_to_end < box_max
            {
                diff := box_max + (box_min + offset_to_end);
                sum : = f32(0);
                i := text_box.offset-1;
                for sum < diff
                {
                    sum += get_text_width(style.font, buffer_string(buf^)[i:][:1], style.text_height);
                    i -= 1;
                    text_box.offset -= 1;
                }
                content_rect.x -= sum;
            }
        }
    }
    /***** TEXT SCROLL END *****/
    
    if cursor_start != text_box.cursor || (focus == id && last_focus != id) || init_state 
    {
        text_box.cursor_last_updated = time;
    }
    
    /***** DRAW *****/
    base_layer := layer;
    
    // Draw box
    draw_rect(ctx, rect, id, .Base, opt ~ {.Border});
    
    // Draw text
    layer = base_layer+1;
    {
        draw_text(ctx, display_text, content_rect, .Text, opt);
    }
    
    if id == focus
    {
        text_width := content_rect.w;
        
        // Draw Mark
        if text_box.mark != -1
        {
            // @Todo(Tyler): Fix visual artefacts due to mark width
            layer += 1;
            mark_pos   := get_text_width(style.font, display_text[:text_box.mark], style.text_height);
            mark_x     := min(mark_pos, cursor_pos);
            mark_width := abs(mark_pos - cursor_pos);
            mark_diff  := text_width - mark_x;
            mark       := Rect
            {
                x = content_rect.x + content_rect.w - mark_diff,
                y = content_rect.y,
                w = mark_width,
                h = content_rect.h
            };
            draw_rect(ctx, mark, id, .Mark, {});
        }
        
        // Draw cursor
        if math.sin(time*5) > 0 || // Blink
            time - text_box.cursor_last_updated < 0.4 // Display if recently updated
        {
            layer += 1;
            diff := text_width - cursor_pos;
            cursor := Rect
            {
                x = content_rect.x + content_rect.w - diff,
                y = content_rect.y,
                w = 2,
                h = content_rect.h
            };
            
            draw_rect(ctx, cursor, id, .Text, {});
        }
    }
    layer = base_layer;
    /***** DRAW END *****/
    
    return res;
}

number_input :: proc(using ctx: ^Context, lbl: string, value: ^$T, 
                     fmt_str := "%v", lower, upper, step: T, opt := Options{}) -> (res: Results) where intrinsics.type_is_numeric(T)
{
    id := get_id(ctx, lbl, 0);
    rect := layout_peek_rect(ctx);
    // was_focus := focus == id;
    update_focus(ctx, rect, id, opt | {.Hold_Focus});
    
    
    // vbuf: ^Text_Buffer;
    vbuf: [256]byte;
    str_len := len(fmt.bprintf(vbuf[:], fmt_str, value^));
    if focus == id
    {
        // vbuf = &num_input_buf;
        if last_focus != id
        {
            text_box.mark = 0;
            //vbuf.used = 0;
            //text_box.cursor = _insert_string_at(vbuf, 0, fmt.tprintf(fmt_str, value^));
            text_box.cursor = str_len;
        }
    }
    else
    {
        if hover == id && scroll.y != 0
        {
            add := scroll.y * (step!=0 ? step : T(1));
            if lower != upper 
            {
                value^ = clamp(value^ + add, lower, upper);
            }
        }
        // Show value if not active
    }
    
    
    res = text_input(ctx, lbl, vbuf[:], opt);
    
    if .Submit in res
    {
        slice := vbuf[:];
        util.read_types(cast(^string)&slice, value);
    }
    
    return res;
}

section :: proc(using ctx: ^Context, lbl: string, opt := Options{}) -> (res: Results)
{
    id := get_id(ctx, lbl, 0);
    
    old_layout := layout;
    
    row(ctx, 1, {-1}, 0);
    rect := layout_rect(ctx);
    update_focus(ctx, rect, id, {});
    
    active, ok := sections[id];
    if !ok
    {
        active = false;
        sections[id] = active;
    }
    
    if last_focus == id && mouse_released(ctx, 0) && id == hover
    {
        active = !active;
        sections[id] = active;
    }
    
    base_layer := layer;
    draw_rect(ctx, rect, id, .Button, {.Border});
    indicator := "-" if active else "+";
    
    layer = base_layer + 1;
    {
        indicator_text := text_rect(ctx, indicator);
        aligned := align_rect(ctx, rect, indicator_text, {.Left});
        draw_text(ctx, indicator, aligned, .Text, opt);
        lbl_text := text_rect(ctx, lbl);
        aligned = align_rect(ctx, rect, lbl_text);
        draw_text(ctx, lbl, aligned, .Text, opt);
    }
    layer = base_layer;
    
    if active do res |= {.Active};
    return;
}

window_container :: proc(using ctx: ^Context, win: ^Window) -> Rect
{
    win.container = win.rect;
    
    win.container.y += f32(style.title_size   + style.padding);
    win.container.h -= f32(style.title_size*2 + style.padding*2);
    win.container.x += f32(style.padding);
    win.container.w -= f32(style.padding * 2);
    
    return win.container;
}

init_window :: proc(using ctx: ^Context, title: string, rect: Rect) -> (win: Window)
{
    win.title = title;
    win.rect  = rect;
    win.open  = true;
    
    return win;
}

bring_to_front :: proc(using ctx: ^Context, win: ^Window)
{
    win_top_layer += 1;
    win.layer = win_top_layer;
}

update_window_focus :: proc(using ctx: ^Context, win: ^Window, id: u64, opt := Options{})
{
    mouse_over := is_mouse_over(ctx, win.rect);
    
    if mouse_over && !mouse_down(ctx, 0) &&
        (window_hover == nil || window_hover.layer < win.layer) 
    {
        window_hover = win;
    }
    
    if window_focus == win &&
        mouse_pressed(ctx, 0) && !mouse_over 
    {
        ctx.window_focus = nil;
    }
    
    if ctx.window_hover == win
    {
        if !mouse_over do ctx.window_hover = nil;
        else if mouse_pressed(ctx, 0) do window_focus = win;
    }
}

window :: proc(using ctx: ^Context, win: ^Window, opt := Options{}) -> (res: Results)
{
    id := get_id(ctx, win.title, 0);
    
    if !win.open do return;
    
    push_container(ctx, window_container(ctx, win));
    
    win.draws.start = len(draws);
    append(&windows, win);
    
    title := win.rect;
    title.h = f32(style.title_size);
    
    close := title;
    close.w = close.h;
    close.x += title.w - close.w;
    
    SCOPE_ID(ctx, win.title);
    // Handle hover/focus
    was_focus := window_focus == win;
    close_hover := false;
    update_window_focus(ctx, win, id, opt);
    if window_hover == win || window_focus == win
    {
        if window_focus == win && !was_focus 
        {
            bring_to_front(ctx, win);
        }
        
        // Temp labels for window elements
        temp_label: string;
        
        // Handle title drag
        title_id := get_id(ctx, "__TITLE__", 0);
        update_focus(ctx, title, title_id, opt);
        if focus == title_id
        {
            win.rect.x += cursor.x - last_cursor.x;
            win.rect.y += cursor.y - last_cursor.y;
            title.x += cursor.x - last_cursor.x;
            title.y += cursor.y - last_cursor.y;
            close.x += cursor.x - last_cursor.x;
            close.y += cursor.y - last_cursor.y;
        }
        
        // Handle close button
        close_id := get_id(ctx, "__CLOSE__", 0);
        update_focus(ctx, close, close_id, {});
        close_hover = hover == close_id;
        
        if last_focus == close_id && mouse_released(ctx, 0) && close_hover
        {
            window_focus = nil;
            window_hover = nil;
            win.open = false;
        }
    }
    
    base_layer := layer;
    
    // Draw background
    draw_rect(ctx, win.rect, id, .Window, opt);
    
    // Draw title
    {
        layer += 1;
        draw_rect(ctx, title, id, .Title, opt);
        
        layer += 1;
        title_text := text_rect(ctx, win.title);
        title_text = align_rect(ctx, title, title_text, opt);
        draw_text(ctx, win.title, title_text, .Title_Text, opt);
        
        // Draw close buttons
        // @Todo(Tyler): Icons
        layer += 1;
        close_color := Color_ID.Title;
        if close_hover 
        {
            close_color = .Close;
        }
        draw_rect(ctx, close, id, close_color, opt);
    }
    
    layer = base_layer;
    res |= {.Active};
    return res;
}

window_end :: proc(using ctx: ^Context)
{
    win := windows[len(windows)-1];
    win.draws.end = len(draws)-1;
    
    // Reset Layout
    layout.pos = {0, 0};
    layout.items = 1;
    mem.zero_slice(layout.widths[:]);
    layout.curr_item = 0;
    
    pop_container(ctx);
}
