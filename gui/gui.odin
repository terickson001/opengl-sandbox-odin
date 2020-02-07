package gui

import "core:fmt"
import "core:hash"
import "core:hash"
import "core:mem"
import "core:sort"
import "core:strings"
import "core:intrinsics"

MAX_ROW_ITEMS :: 16;

Cursor :: enum u8
{
    Arrow,
    Bar,
    HResize,
    VResize,
    Hand,
}

Res :: enum u8
{
    Submit = 0x1,
    Update = 0x2,
    Active = 0x4,
}
Results :: bit_set[Res];

Opt :: enum u8
{
    Right      = 0x01,
    Left       = 0x02,
    Border     = 0x04,
    Hold_Focus = 0x08,
    Bottom     = 0x10,
    Top        = 0x20,
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
    text_height = 13,
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

Draw :: struct
{
    layer   : int
    variant : union
    {
        Draw_Rect,
        Draw_Text,
        Draw_Icon,
    }
}

Layout :: struct
{
    pos       : [2]f32,
    size      : [2]f32,
    items     : int,
    widths    : [MAX_ROW_ITEMS]int,
    curr_item : int,
}

Text_State :: struct
{
    cursor              : i32,
    mark                : i32,
    cursor_last_updated : f64,
    // @Note(Tyler): Character offset for one-line text box
    //               Line offset for multi-line text box (Eventually)
    offset              : i32,
}

Window :: struct
{
    title     : string,
    rect      : Rect,
    container : Rect,
    open      : bool,
    layer     : int,
    draws     : []Draw,
}

Display :: struct
{
    width  : f32,
    height : f32,
}


Key_Code :: enum u16
{
    Unknown       = -1,
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
    Kp_Decimal    = 330,
    Kp_Divide     = 331,
    Kp_Multiply   = 332,
    Kp_Subtract   = 333,
    Kp_Add        = 334,
    Kp_Enter      = 335,
    Kp_Equal      = 336,
    Left_Shift    = 340,
    Left_Control  = 341,
    Left_Alt      = 342,
    Left_Super    = 343,
    Right_Shift   = 344,
    Right_Control = 345,
    Right_Alt     = 346,
    Right_Super   = 347,
    Menu          = 348,
    Last          = Key_Code.Menu,
}

MAX_KEY_COUNT :: 512;
Control :: struct
{
    cursor     : [2]f32,
    scroll     : [2]f32,
    mouse      : [3]bool,
    keys_down  : [MAX_KEY_COUNT]bool,
    key_times  : [MAX_KEY_COUNT]f32,
    text_input : [128]byte,
    char_count : int
}

Context :: struct
{
    hover          : u64,
    focus          : u64,
    layer          : int,
    
    containers     : [dynamic]Rect,
    layout         : Layout,
    style          : Style,

    draws          : [dynamic]Draw,
    draw_idx       : int,
    cursor_icon    : Cursor,

    display        : Display,
    
    // Inputs
    using ctrl     : Control,
    last_cursor    : [2]f32,
    last_mouse     : [3]bool,
    last_keys_down : [MAX_KEY_COUNT]bool,
    last_key_times : [MAX_KEY_COUNT]f32,
    
    time           : f64,

    // Window State
    window_hover   : ^Window,
    window_focus   : ^Window,
    win_top_layer  : int,
    windows        : [dynamic]^Window,

    text_box       : Text_State,

    get_text_width : proc(font: rawptr, text: string, size: int) -> f32,
    num_input_buf  : [64]byte,
}

hash_id :: proc(data: rawptr, size: int) -> u64
{
    slice := mem.slice_ptr((^byte)(data), size);
    return hash.crc64(slice);
}

get_id :: proc(lbl: string, icon: int) -> u64
{
    lbl  := transmute([]byte)lbl;
    icon := icon;
    return len(lbl) > 0
        ? hash_id(&lbl[0], len(lbl))
        : hash_id(&icon, size_of(icon));
}

mouse_down     :: proc(using ctx: ^Context, b: int) -> bool { return  mouse[b];                   }
mouse_pressed  :: proc(using ctx: ^Context, b: int) -> bool { return  mouse[b] && !last_mouse[b]; }
mouse_up       :: proc(using ctx: ^Context, b: int) -> bool { return !mouse[b];                   }
mouse_released :: proc(using ctx: ^Context, b: int) -> bool { return !mouse[b] &&  last_mouse[b]; }

key_down     :: proc(using ctx: ^Context, k: Key_Code) -> bool { return  keys_down[k];                       }
key_pressed  :: proc(using ctx: ^Context, k: Key_Code) -> bool { return  keys_down[k] && !last_keys_down[k]; }
key_up       :: proc(using ctx: ^Context, k: Key_Code) -> bool { return !keys_down[k];                       }
key_released :: proc(using ctx: ^Context, k: Key_Code) -> bool { return !keys_down[k] &&  last_keys_down[k]; }

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

init :: proc() -> (ctx: Context)
{
    using ctx;
    
    style = DEFAULT_STYLE;
    draws      = make([dynamic]Draw);
    windows    = make([dynamic]^Window);
    containers = make([dynamic]Rect);
    
    return ctx;
}

begin :: proc(using ctx: ^Context)
{
    resize(&draws,      0);
    resize(&windows,    0);
    resize(&containers, 0);

    draw_idx = 0;

    push_container(ctx, {0, 0, display.height, display.width});
    
    layout.pos = {0, 0};
    layout.items = 1;
    mem.zero_slice(layout.widths[:]);
    layout.curr_item = 0;
    
    layer = 0;
    cursor_icon = .Arrow;
}

@private
win_zcmp :: proc(a, b: ^Window) -> int { return a.layer - b.layer; }

end :: proc(using ctx: ^Context)
{
    // Reset input state
    mem.zero_slice(text_input[:]);
    scroll = {0, 0};
    cursor = last_cursor;
    cursor = {0, 0};

    // Sort windows by layer
    sort.merge_sort_proc(windows[:], win_zcmp);

    // Stack windows
    prev_max := 0;
    new_max := 0;
    for _, i in windows
    {
        win := windows[i];
        win.layer = i;

        for _, d in win.draws
        {
            win.draws[d].layer += prev_max + 1;
            new_max = max(new_max, win.draws[d].layer);
        }

        prev_max = new_max;
    }

    win_top_layer = len(windows);
    layer = 0;
}

start_row :: proc(using ctx: ^Context, items: int, widths: []int, height: int)
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

    rect.w = f32(layout.widths[layout.curr_item]);
    rect.h = layout.size.y;

    // Position relative to right for negative values
    if rect.w <= 0 do
        rect.w += container.x + container.w - rect.x;

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

align_rect :: proc(using ctx: ^Context, bound, rect: Rect, opt: Options) -> Rect
{
    ret := Rect{};
    ret.w = rect.w;
    ret.h = rect.h;

    bound := bound;
    bound.x += f32(style.padding);
    bound.y += f32(style.padding);
    bound.w -= f32(style.padding)*2;
    bound.h -= f32(style.padding)*2;

    if .Right in opt do
        ret.x = bound.x+bound.w - rect.w;
    else if .Left in opt do
        ret.x = bound.x;
    else do // Center
        ret.x = bound.x + (bound.w - rect.w)/2;

    if .Bottom in opt do
        ret.y = bound.y+bound.h - rect.h;
    else if .Top in opt do
        ret.y = bound.y;
    else do // Center
        ret.y = bound.y + (bound.h - rect.h)/2;

    return ret;
}

is_hover :: proc(using ctx: ^Context, lbl: string, icon: int) -> bool
{
    return get_id(lbl, icon) == hover;
}

is_focus :: proc(using ctx: ^Context, lbl: string, icon: int) -> bool
{
    return get_id(lbl, icon) == focus;
}

is_mouse_over :: proc(using ctx: ^Context, rect: Rect) -> bool
{
    m := cursor;

    return (rect.x <= m.x && m.x <= rect.x+rect.w &&
            rect.y <= m.y && m.y <= rect.y+rect.h);
}

update_focus :: proc(using ctx: ^Context, rect: Rect, id: u64, opt: Options)
{
    mouse_over := is_mouse_over(ctx, rect);

    if mouse_over && !mouse_down(ctx, 0) do
        hover = id;

    if focus == id &&
        (mouse_pressed(ctx, 0) && !mouse_over) ||
        (!mouse_down(ctx, 0) && .Hold_Focus notin opt) do
            focus = 0;

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

draw_text :: proc(using ctx: ^Context, str: string, rect: Rect, color_id: Color_ID, opt: Options)
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

draw_rect :: proc(using ctx: ^Context, rect: Rect, id: u64, color_id: Color_ID, opt: Options)
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

    if .Border in opt do
        draw_border(ctx, rect, id);
}

next_draw :: proc(using ctx: ^Context, ret: ^Draw) -> bool
{
    if draw_idx >= len(draws) do
        return false;

    ret^ = draws[draw_idx];
    draw_idx += 1;
    
    return true;
}

label :: proc(using ctx: ^Context, str: string, opt: Options)
{
    bounds := layout_rect(ctx);
    lbl_rect := text_rect(ctx, str);
    draw_text(ctx, str, align_rect(ctx, bounds, lbl_rect, opt), .Text, opt);
}

button :: proc(using ctx: ^Context, lbl: string, icon: int, opt: Options) -> (res: Results)
{
    id := get_id(lbl, icon);

    rect := layout_rect(ctx);

    base_layer := layer;
    was_focus  := id == focus;
    update_focus(ctx, rect, id, {});

    if was_focus && mouse_released(ctx, 0) && id == hover do
        res |= {.Submit};

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

slider :: proc(using ctx: ^Context, label: string, value: ^$T, fmt: string, upper, lower, step: T, opt: Options) -> (res: Results) where intrinsics.type_is_numeric(T)
{
    id = get_id(label, 0);

    prev := value^;
    rect := layout_rect(ctx);
    update_focus(ctx, rect, id, opt);

    tw := T(style.thumb_size);
    if id == focus && mouse_down(ctx, 0)
    {
        value^ = lower + ((cursor.x-rect.x-(tw/2)) / (rect.w-tw) * (upper-lower));
        if step > 0 do
            value^ = math.trunc((value + step/2) / step) * step; 
    }
    else if id == hover && scroll.y > 0
    {
        add = scroll.y * (step > 0 ? step : T(1));
        value^ += add;
    }

    value^ = clamp(value^, lower, upper);

    if value^ != prev do
        res |= {.Update};
    
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
        fmt.bprintf(val_buf, fmt, value^);
        val_rect := text_rect(ctx, val_buf);
        aligned  := align_rect(ctx, rect, val_rect, opt);
        draw_text(ctx, val_buf, aligned, .Text, opt);
    }
    layer = base_layer;

    return res;
}

Text_Buffer :: struct
{
    backing: []byte,
    used: int,
}

@private
_insert_string_at :: proc(buf: ^Text_Buffer, idx: int, str: string) -> int
{
    slen := min(len(str), len(buf.backing)-buf.used);

    copy(buf[idx+slen:], buf[idx:buf.used]);
    copy(buf[idx:], str[:]);

    buf.used += slen;
    
    return slen;
}

@private
_remove_string_between :: proc(buf: ^Text_Buffer, start, end: int) -> int
{
    start, end := start, end;
    
    if start == end do
        return 0;

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
    else if !key_down(ctx, .LShift) && text_box.mark == -1
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

    if text_box.cursor == text_box.mark do
        text_box.mark = -1;
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
    for idx-1 > 0 && !char_is_alphanum(buf.backing[idx-1]) do
        idx -= 1;
    for idx-1 > 0 && char_is_alphanum(buf.backing[idx-1]) do
        idx -= 1;
    if idx == 1 && char_is_alphanum(buf.backing[idx]) do
        idx -= 1;

    return max(idx, 0);
}

@private
_word_end :: proc(buf: ^Text_Buffer, idx: int) -> int
{
    for idx < buf.used && !char_is_alphanum(buf.backing[idx]) do
        idx += 1;
    for idx < buf.used && char_is_alphanum(buf.backing[idx]) do
        idx += 1;

    return min(idx, buf.used);
}

text_input :: proc(using ctx: ^Context, label: string, buf: ^Text_Buffer, opt: Options) -> (res: Results)
{
    id := get_id(label, 0);

    rect := layout_rect(ctx);
    was_focus := id == focus;

    update_focus(ctx, rect, id, opt | {.Hold_Focus});

    if id == hover do
        cursor_icon = .Bar;

    cursor_start = text_box.cursor;
    content_rect: Rect;
    
    if id == focus
    {
        if !was_focus
        {
            text_box.mark = buf.used > 0 ? 0 : -1;
            text_box.cursor = buf.used;
        }

        if text_input[0] != 0
        {
            if text_box.mark != -1
            {
                text_box.cursor -= _remove_string_between(buf, text_box.mark, text_box.cursor);
                text_box.mark = -1;
            }
            text_box.cursor += _insert_string_at(buf, text_box.cursor, text_input);
        }

        // Backspace
        if key_repeat(ctx, .Backspace)
        {
            if text_box.mark != -1 // Delete Marked Region
            {
                text_box.cursor -= _remove_string_between(buf, text_input, text_box.cursor);
            }
            else if key_down(ctx, .LCtrl)
            {
                word_index := _word_beg(buf, text_box.cursor, buf.used);
                cursor -= _remove_string_between(buf, word_index, text_box.cursor);
            }
            else if text_box.cursor > 0
            {
                _remove_char_at(buf, text_box.cursor);
                text_box.cursor -= 1;
            }
            text_box.mark = -1;
        }
        else if key_repeat(.Delete)
        {
            if text_box.mark != -1 // Delete Marked Region
            {
                text_box.cursor -= _remove_string_between(buf, text_box.mark, text_box.cursor);
            }
            else if key_down(.LCtrl)
            {
                word_index := _word_end(buf, text_box.cursor);
                _remove_string_between(buf, text_box_cursor, word_index);
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
            if key_down(ctx, .LCtrl) do
                change = _word_beg(buf, text_box.cursor, buf.used) - text_box.cursor;
            _update_cursor(ctx, change, buf.used);
        }
        else if key_repeat(ctx, .Right)
        {
            change := -1;
            if key_down(ctx, .LCtrl) do
                change = _word_end(buf, text_box.cursor, buf.used) - text_box.cursor;
            _update_cursor(ctx, change, buf.used);
        }
        else if key_pressed(ctx, .Home) || key_pressed(ctx, .Up)
        {
            _update_cursor(ctx, -buf.used, buf.used);
        }
        else if key_pressed(ctx, .End) || key_pressed(ctx, .Down)
        {
            _update_cursor(ctx, +buf.used, buf.used);
        }
    }

    // @Todo(Tyler): Track length of buf
    content_rect = text_rect(ctx, buf);
    content_rect = align_rect(ctx, rect, content_rect, opt);

    // Text-Selection with mouse
    if id == focus && mouse_down(ctx, 0) && buf.used > 0
    {
        pos := content_rect.x;
        cw := f32(0);
        index := 0;
        for index < buf.used+1 && pos < cursor.x
        {
            cw = get_text_width(style.font, buf.backing[index:][:1], style.text_height);
            index += 1;
            pos += cw;
        }
        index = max(index-1, 0);
        if cw > 0 && pos - cursor.x < (cursor.x - (pos-cw)) && index < buf.used do
            index += 1;

        if mouse_pressed(ctx, 0)
        {
            text_box.cursor = index;
            text_box.mark = -1;
        }
        else
        {
            if text_box.mark == -1 && text_box.cursor != index do
                text_box.mark = text_box.cursor;
            text_box.cursor = index;
        }

    }

    // Scrolling Text
    cursor_pos := f32(0);
    offset_x   := f32(0);
    if id == focus
    {
        offset_x        = get_text_width(style.font, buf.backing[:text_box.offset], style.text_height);
        content_rect.x -= offset_x;

        cursor_pos = get_text_width(ctx, buf.backing[:text_box.cursor], style.text_height);

        box_min := content_rect.x + offset_x;
        box_max := box_min + (rect.w - style.padding*2);
        cursor_rel := content_rect.x + cursor_pos;
        if cursor_rel > box_max // Scroll forward
        {
            diff := cursor_rel - box_max;
            sum := f32(0);
            i := text_box.curosr - 1;
            for sum < diff
            {
                sum += get_text_width(style.font, buf.backing[i:][:1], style.text_height);
                i -= 1;
                text_box.offset += 1;
            }
            content_rect.x -= sum;
        }
        else if cursor_rel < box_min // Scroll Backwards
        {
            diff := box_min - cursor_rel;
            sum := 0;
            i := text_box.cursor;
            for sum < diff
            {
                sum += get_text_width(style.font, buf.backing[i:][:1], style.text_height);
                i += 1;
                text_box.offset -= 1;
            }
            content_rect.x += sum;
        }
        else if (text_box.offset > 0) // Scroll backwards if text can fit
        {
            // @Note(Tyler): Get width of one extra character to make sure the entire character will fit
            offset_to_end = get_text_width(ctx, buf.backing[text_box.offset-1:], style.text_height);
            if box_min + offset_to_end < box_max
            {
                diff := box_max + (box_min + offset_to_end);
                sum : = f32(0);
                i := text_box.offset-1;
                for sum < diff
                {
                    sum += get_text_width(style.font, buf.backing[i:][:1], style.text_height);
                    i -= 1;
                    text_box.offset -= 1;
                }
                content_rect.x -= sum;
            }
        }
    }

    if cursor_start != text_box.cursor do
        text_box.cursor_lsat_updated = time;

    base_layer := layer;

    // Draw box
    draw_rect(ctx, rect, id, .Base, opt ~ {.Border});

    // Draw text
    layer = base_layer+1;
    {
        draw_text(ctx, buf, text_rect, .Text, opt);
    }
}
