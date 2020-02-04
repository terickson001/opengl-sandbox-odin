package gui

import "core:fmt"
import "core:hash"
import "core:mem"
import "core:sort"
import "core:strings"

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

MAX_KEY_COUNT :: 512;
Control :: struct
{
    cursor     : [2]f32,
    scroll     : [2]f32,
    mouse      : [3]bool,
    keys_down  : [MAX_KEY_COUNT]bool,
    key_times  : [MAX_KEY_COUNT]f32,
    text_input : [128]byte,
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

key_down       :: proc(using ctx: ^Context, k: int) -> bool { return  keys_down[k];                       }
key_pressed    :: proc(using ctx: ^Context, k: int) -> bool { return  keys_down[k] && !last_keys_down[k]; }
key_up         :: proc(using ctx: ^Context, k: int) -> bool { return !keys_down[k];                       }
key_released   :: proc(using ctx: ^Context, k: int) -> bool { return !keys_down[k] &&  last_keys_down[k]; }

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

add_draw :: proc(using ctx: ^Context, kind: Draw_Kind) -> ^Draw
{
    draw := Draw{};
    draw.kind = kind;
    append(&draws, draw);
    return draws[len(draws)-1];
}

draw_border :: proc(using ctx: ^Context, rect: Rect, id: u64)
{
    bs := style.border_size;
    c  := Color_ID.Border;
    
    draw_rect(ctx, {rect.x,           rect.y,           bs,            rect.h}, id, c, 0); // Left
    draw_rect(ctx, {rect.x+rect.w-bs, rect.y,           bs,            rect.h}, id, c, 0); // Right
    draw_rect(ctx, {rect.x+bs,        rect.y,           rect.w-(2*bs), bs},     id, c, 0); // Top
    draw_rect(ctx, {rect.x+bs,        rect.y+rect.h-bs, rect.w-(2*bs), bs},     id, c, 0); // Bottom
}

draw_text :: proc(using ctx: ^Context, str: string, rect: Rect, color_id: Color_ID, opt: Options)
{
    pos := [2]f32{};

    pos.x = rect.x;
    pos.y = rect.y;

    draw := add_draw(ctx, .Text);
    draw.layer = layer;
    draw.text  =
        {
            pos = pos,
            size = rect.h,
            color_id = color_id,
            color = style.colors[color_id],
            text = strings.clone(str),
        };
}

draw_rect :: proc(using ctx: ^Context, rect: Rect, id: u64, color_id: Color_ID, opt: Options)
{
    if color_id == .Button || color_id == .Base
    {
        if      id == focus do color_id += 2;
        else if id == hover do color_id += 1;
    }
    color := style.colors[color_id];

    draw := add_draw(ctx, .Rect);
    draw.layer = layer;
    draw.rect  =
        {
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
    text_rect = text_rect(ctx, str);
    draw_text(ctx, str, align_rect(ctx, bounds, text_rect, opt), .Text, opt);
}

button :: proc(using ctx: ^Context, lbl: string, icon: int, opt: Options) -> (res: Results)
{
}